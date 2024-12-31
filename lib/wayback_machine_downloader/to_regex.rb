# frozen_string_literal: true

module ToRegex
  module StringMixin
    INLINE_OPTIONS = /[imxnesu]*/i.freeze
    REGEXP_DELIMITERS = {
      '%r{' => '}'.freeze,
      '/' => '/'.freeze
    }.freeze

    REGEX_FLAGS = {
      ignore_case: Regexp::IGNORECASE,
      multiline: Regexp::MULTILINE,
      extended: Regexp::EXTENDED
    }.freeze

    class << self
      def literal?(str)
        REGEXP_DELIMITERS.none? { |start, ending| str.start_with?(start) && str.match?(/#{ending}#{INLINE_OPTIONS}\z/) }
      end
    end

    # Get a regex back
    #
    # Without :literal or :detect, `"foo".to_regex` will return nil.
    #
    # @param [optional, Hash] options
    # @option options [true,false] :literal Treat meta characters and other regexp codes as just text; always return a regexp
    # @option options [true,false] :detect If string starts and ends with valid regexp delimiters, treat it as a regexp; otherwise, interpret it literally
    # @option options [true,false] :ignore_case /foo/i
    # @option options [true,false] :multiline /foo/m
    # @option options [true,false] :extended /foo/x
    # @option options [true,false] :lang /foo/[nesu]
    def to_regex(options = {})
      args = as_regexp(options)
      args ? Regexp.new(*args) : nil
    end
    # Return arguments that can be passed to `Regexp.new`
    # @see to_regexp
    def as_regexp(options = {})
      raise ArgumentError, '[to_regexp] Options must be a Hash' unless options.is_a?(Hash)
      
      str = self
      return if options[:detect] && str.empty?

      if should_treat_as_literal?(str, options)
        content = Regexp.escape(str)
      elsif (delim_set = extract_delimiters(str))
        content, options = parse_regexp_string(str, delim_set, options)
        return unless content
      else
        return
      end

      build_regexp_args(content, options)
    end

    private

    def should_treat_as_literal?(str, options)
      options[:literal] || (options[:detect] && ToRegex::StringMixin.literal?(str))
    end

    def extract_delimiters(str)
      REGEXP_DELIMITERS.find { |start, _| str.start_with?(start) }
    end

    def parse_regexp_string(str, delim_set, options)
      start_delim, end_delim = delim_set
      match = /\A#{start_delim}(.*)#{end_delim}(#{INLINE_OPTIONS})\z/u.match(str)
      return unless match

      content = match[1].gsub('\\/', '/')
      parse_inline_options(match[2], options)
      [content, options]
    end

    def parse_inline_options(inline_options, options)
      return unless inline_options
      options[:ignore_case] = true if inline_options.include?('i')
      options[:multiline] = true if inline_options.include?('m')
      options[:extended] = true if inline_options.include?('x')
      # 'n', 'N' = none, 'e', 'E' = EUC, 's', 'S' = SJIS, 'u', 'U' = UTF-8
      options[:lang] = inline_options.scan(/[nesu]/i).join.downcase
    end

    def build_regexp_args(content, options)
      flags = calculate_flags(options)
      lang = normalize_lang_option(options[:lang])
      
      lang.empty? ? [content, flags] : [content, flags, lang]
    end

    def calculate_flags(options)
      REGEX_FLAGS.sum { |key, value| options[key] ? value : 0 }
    end

    def normalize_lang_option(lang)
      return '' unless lang
      RUBY_VERSION >= '1.9' ? lang.delete('u') : lang
    end
  end
end

class String
  include ToRegex::StringMixin
end