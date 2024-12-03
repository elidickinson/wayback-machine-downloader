# encoding: UTF-8

require 'thread'
require 'net/http'
require 'open-uri'
require 'fileutils'
require 'cgi'
require 'json'
require 'time'
require 'concurrent'
require 'logger'
require_relative 'wayback_machine_downloader/tidy_bytes'
require_relative 'wayback_machine_downloader/to_regex'
require_relative 'wayback_machine_downloader/archive_api'

class WaybackMachineDownloader

  include ArchiveAPI

  VERSION = "2.3.2"
  DEFAULT_TIMEOUT = 30
  MAX_RETRIES = 3
  RETRY_DELAY = 2
  RATE_LIMIT = 0.25  # Delay between requests in seconds
  CONNECTION_POOL_SIZE = 10
  HTTP_CACHE_SIZE = 1000
  MEMORY_BUFFER_SIZE = 16384  # 16KB chunks

  attr_accessor :base_url, :exact_url, :directory, :all_timestamps,
    :from_timestamp, :to_timestamp, :only_filter, :exclude_filter,
    :all, :maximum_pages, :threads_count, :logger

  def initialize params
    validate_params(params)
    @base_url = params[:base_url]
    @exact_url = params[:exact_url]
    @directory = params[:directory]
    @all_timestamps = params[:all_timestamps]
    @from_timestamp = params[:from_timestamp].to_i
    @to_timestamp = params[:to_timestamp].to_i
    @only_filter = params[:only_filter]
    @exclude_filter = params[:exclude_filter]
    @all = params[:all]
    @maximum_pages = params[:maximum_pages] ? params[:maximum_pages].to_i : 100
    @threads_count = [params[:threads_count].to_i, 1].max # Garante mínimo de 1 thread
    @timeout = params[:timeout] || DEFAULT_TIMEOUT
    @logger = setup_logger
    @http_cache = Concurrent::Map.new
    @failed_downloads = Concurrent::Array.new
  end

  def backup_name
    if @base_url.include? '//'
      @base_url.split('/')[2]
    else
      @base_url
    end
  end

  def backup_path
    if @directory
      if @directory[-1] == '/'
        @directory
      else
        @directory + '/'
      end
    else
      'websites/' + backup_name + '/'
    end
  end

  def match_only_filter file_url
    if @only_filter
      only_filter_regex = @only_filter.to_regex
      if only_filter_regex
        only_filter_regex =~ file_url
      else
        file_url.downcase.include? @only_filter.downcase
      end
    else
      true
    end
  end

  def match_exclude_filter file_url
    if @exclude_filter
      exclude_filter_regex = @exclude_filter.to_regex
      if exclude_filter_regex
        exclude_filter_regex =~ file_url
      else
        file_url.downcase.include? @exclude_filter.downcase
      end
    else
      false
    end
  end

  def get_all_snapshots_to_consider
    http = setup_http_client
    snapshot_list_to_consider = []

    begin
      http.start do |connection|
        puts "Getting snapshot pages"

        # Fetch the initial set of snapshots
        snapshot_list_to_consider += get_raw_list_from_api(@base_url, nil, connection)
        print "."

        # Fetch additional pages if the exact URL flag is not set
        unless @exact_url
          @maximum_pages.times do |page_index|
            snapshot_list = get_raw_list_from_api("#{@base_url}/*", page_index, connection)
            break if snapshot_list.empty?

            snapshot_list_to_consider += snapshot_list
            print "."
          end
        end
      end
    ensure
      http.finish if http.started?
    end

    puts " found #{snapshot_list_to_consider.length} snapshots to consider."
    puts

    snapshot_list_to_consider
  end

  def get_file_list_curated
    file_list_curated = Hash.new
    get_all_snapshots_to_consider.each do |file_timestamp, file_url|
      next unless file_url.include?('/')
      file_id = file_url.split('/')[3..-1].join('/')
      file_id = CGI::unescape file_id
      file_id = file_id.tidy_bytes unless file_id == ""
      if file_id.nil?
        puts "Malformed file url, ignoring: #{file_url}"
      else
        if match_exclude_filter(file_url)
          puts "File url matches exclude filter, ignoring: #{file_url}"
        elsif not match_only_filter(file_url)
          puts "File url doesn't match only filter, ignoring: #{file_url}"
        elsif file_list_curated[file_id]
          unless file_list_curated[file_id][:timestamp] > file_timestamp
            file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
          end
        else
          file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
        end
      end
    end
    file_list_curated
  end

  def get_file_list_all_timestamps
    file_list_curated = Hash.new
    get_all_snapshots_to_consider.each do |file_timestamp, file_url|
      next unless file_url.include?('/')
      file_id = file_url.split('/')[3..-1].join('/')
      file_id_and_timestamp = [file_timestamp, file_id].join('/')
      file_id_and_timestamp = CGI::unescape file_id_and_timestamp
      file_id_and_timestamp = file_id_and_timestamp.tidy_bytes unless file_id_and_timestamp == ""
      if file_id.nil?
        puts "Malformed file url, ignoring: #{file_url}"
      else
        if match_exclude_filter(file_url)
          puts "File url matches exclude filter, ignoring: #{file_url}"
        elsif not match_only_filter(file_url)
          puts "File url doesn't match only filter, ignoring: #{file_url}"
        elsif file_list_curated[file_id_and_timestamp]
          puts "Duplicate file and timestamp combo, ignoring: #{file_id}" if @verbose
        else
          file_list_curated[file_id_and_timestamp] = {file_url: file_url, timestamp: file_timestamp}
        end
      end
    end
    puts "file_list_curated: " + file_list_curated.count.to_s
    file_list_curated
  end


  def get_file_list_by_timestamp
    if @all_timestamps
      file_list_curated = get_file_list_all_timestamps
      file_list_curated.map do |file_remote_info|
        file_remote_info[1][:file_id] = file_remote_info[0]
        file_remote_info[1]
      end
    else
      file_list_curated = get_file_list_curated
      file_list_curated = file_list_curated.sort_by { |k,v| v[:timestamp] }.reverse
      file_list_curated.map do |file_remote_info|
        file_remote_info[1][:file_id] = file_remote_info[0]
        file_remote_info[1]
      end
    end
  end

  def list_files
    # retrieval produces its own output
    @orig_stdout = $stdout
    $stdout = $stderr
    files = get_file_list_by_timestamp
    $stdout = @orig_stdout
    puts "["
    files[0...-1].each do |file|
      puts file.to_json + ","
    end
    puts files[-1].to_json
    puts "]"
  end

  def download_files
    start_time = Time.now
    puts "Downloading #{@base_url} to #{backup_path} from Wayback Machine archives."
    
    if file_list_by_timestamp.empty?
      puts "No files to download."
      return
    end

    total_files = file_list_by_timestamp.count
    puts "#{total_files} files to download:"
    
    @processed_file_count = 0
    @download_mutex = Mutex.new
    
    thread_count = [@threads_count, CONNECTION_POOL_SIZE].min
    pool = Concurrent::FixedThreadPool.new(thread_count)
    semaphore = Concurrent::Semaphore.new(CONNECTION_POOL_SIZE)
    
    file_list_by_timestamp.each do |file_remote_info|
      pool.post do
        semaphore.acquire
        http = nil
        begin
          http = setup_http_client
          http.start do |connection|
            result = download_file(file_remote_info, connection)
            @download_mutex.synchronize do
              @processed_file_count += 1
              puts result if result
            end
          end
        ensure
          semaphore.release
          http&.finish if http&.started?
          sleep(RATE_LIMIT)
        end
      end
    end

    pool.shutdown
    pool.wait_for_termination

    end_time = Time.now
    puts "\nDownload completed in #{(end_time - start_time).round(2)}s, saved in #{backup_path}"
    cleanup
  end

  def structure_dir_path dir_path
    begin
      FileUtils::mkdir_p dir_path unless File.exist? dir_path
    rescue Errno::EEXIST => e
      error_to_string = e.to_s
      puts "# #{error_to_string}"
      if error_to_string.include? "File exists @ dir_s_mkdir - "
        file_already_existing = error_to_string.split("File exists @ dir_s_mkdir - ")[-1]
      elsif error_to_string.include? "File exists - "
        file_already_existing = error_to_string.split("File exists - ")[-1]
      else
        raise "Unhandled directory restructure error # #{error_to_string}"
      end
      file_already_existing_temporary = file_already_existing + '.temp'
      file_already_existing_permanent = file_already_existing + '/index.html'
      FileUtils::mv file_already_existing, file_already_existing_temporary
      FileUtils::mkdir_p file_already_existing
      FileUtils::mv file_already_existing_temporary, file_already_existing_permanent
      puts "#{file_already_existing} -> #{file_already_existing_permanent}"
      structure_dir_path dir_path
    end
  end

  def download_file (file_remote_info, http)
    current_encoding = "".encoding
    file_url = file_remote_info[:file_url].encode(current_encoding)
    file_id = file_remote_info[:file_id]
    file_timestamp = file_remote_info[:timestamp]
    file_path_elements = file_id.split('/')

    if file_id == ""
      dir_path = backup_path
      file_path = backup_path + 'index.html'
    elsif file_url[-1] == '/' or not file_path_elements[-1].include? '.'
      dir_path = backup_path + file_path_elements[0..-1].join('/')
      file_path = backup_path + file_path_elements[0..-1].join('/') + '/index.html'
    else
      dir_path = backup_path + file_path_elements[0..-2].join('/')
      file_path = backup_path + file_path_elements[0..-1].join('/')
    end
    if Gem.win_platform?
      dir_path = dir_path.gsub(/[:*?&=<>\\|]/) {|s| '%' + s.ord.to_s(16) }
      file_path = file_path.gsub(/[:*?&=<>\\|]/) {|s| '%' + s.ord.to_s(16) }
    end
    unless File.exist? file_path
      begin
        structure_dir_path dir_path
        download_with_retry(file_path, file_url, file_timestamp, http)
        "#{file_url} -> #{file_path} (#{@processed_file_count + 1}/#{file_list_by_timestamp.size})"
      rescue StandardError => e
        msg = "#{file_url} # #{e}"
        if not @all and File.exist?(file_path) and File.size(file_path) == 0
          File.delete(file_path)
          msg += "\n#{file_path} was empty and was removed."
        end
        msg
      end
    else
      "#{file_url} # #{file_path} already exists. (#{@processed_file_count + 1}/#{file_list_by_timestamp.size})"
    end
  end

  def file_queue
    @file_queue ||= file_list_by_timestamp.each_with_object(Queue.new) { |file_info, q| q << file_info }
  end

  def file_list_by_timestamp
    @file_list_by_timestamp ||= get_file_list_by_timestamp
  end

  def semaphore
    @semaphore ||= Mutex.new
  end

  private

  def validate_params(params)
    raise ArgumentError, "Base URL is required" unless params[:base_url]
    raise ArgumentError, "Maximum pages must be positive" if params[:maximum_pages] && params[:maximum_pages].to_i <= 0
    # Removida validação de threads_count pois agora é forçado a ser positivo
  end

  def setup_logger
    logger = Logger.new(STDOUT)
    logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
    end
    logger
  end

  def setup_http_client
    cached_client = @http_cache[Thread.current.object_id]
    return cached_client if cached_client&.active?

    http = Net::HTTP.new("web.archive.org", 443)
    http.use_ssl = true
    http.read_timeout = @timeout
    http.open_timeout = @timeout
    http.keep_alive_timeout = 30
    http.max_retries = MAX_RETRIES
    
    @http_cache[Thread.current.object_id] = http
    http
  end

  def download_with_retry(file_path, file_url, file_timestamp, connection)
    retries = 0
    begin
      request = Net::HTTP::Get.new(URI("https://web.archive.org/web/#{file_timestamp}id_/#{file_url}"))
      request["Connection"] = "keep-alive"
      request["User-Agent"] = "WaybackMachineDownloader/#{VERSION}"
      
      response = connection.request(request)
      
      case response
      when Net::HTTPSuccess
        File.open(file_path, "wb") do |file|
          if block_given?
            yield(response, file)
          else
            file.write(response.body)
          end
        end
      when Net::HTTPTooManyRequests
        sleep(RATE_LIMIT * 2)
        raise "Rate limited, retrying..."
      else
        raise "HTTP Error: #{response.code} #{response.message}"
      end
      
    rescue StandardError => e
      if retries < MAX_RETRIES
        retries += 1
        @logger.warn("Retry #{retries}/#{MAX_RETRIES} for #{file_url}: #{e.message}")
        sleep(RETRY_DELAY * retries)
        retry
      else
        @failed_downloads << {url: file_url, error: e.message}
        raise e
      end
    end
  end

  def cleanup
    @http_cache.each_value do |client|
      client.finish if client&.started?
    end
    @http_cache.clear
    
    if @failed_downloads.any?
      @logger.error("Failed downloads summary:")
      @failed_downloads.each do |failure|
        @logger.error("  #{failure[:url]} - #{failure[:error]}")
      end
    end
  end
end
