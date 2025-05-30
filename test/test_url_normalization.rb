require 'minitest/autorun'
require 'wayback_machine_downloader'

class UrlNormalizationTest < Minitest::Test

  def test_normalize_url_without_params
    downloader = WaybackMachineDownloader.new(base_url: 'https://example.com')
    
    # Without ignore_url_params, URLs should remain unchanged
    assert_equal 'page.html?param=value', downloader.normalize_url('page.html?param=value')
    assert_equal 'page.html?a=1&b=2', downloader.normalize_url('page.html?a=1&b=2')
  end

  def test_normalize_url_with_ignore_url_params
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # With ignore_url_params, all query parameters should be stripped
    assert_equal 'page.html', downloader.normalize_url('page.html?param=value')
    assert_equal 'page.html', downloader.normalize_url('page.html?a=1&b=2&c=3')
    assert_equal 'subscribe/new', downloader.normalize_url('subscribe/new?utm_source=newsletter&utm_medium=email')
  end

  def test_normalize_url_with_encoded_params
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # Encoded parameters should also be stripped
    url_with_encoded_hash = 'subscribe/new?utm_campaign=Merch%20EOY%20Sale%20%232%2011.19.2019'
    assert_equal 'subscribe/new', downloader.normalize_url(url_with_encoded_hash)
    
    # Multiple encoded parameters
    url_complex = 'page.html?title=Hello%20World&content=Test%20%26%20More&tag=%23hashtag'
    assert_equal 'page.html', downloader.normalize_url(url_complex)
  end

  def test_normalize_url_trailing_question_mark
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # Trailing question mark should be removed
    assert_equal 'article/why-are-we-still-failing-women-chefs', 
                 downloader.normalize_url('article/why-are-we-still-failing-women-chefs?')
    
    # Even without ignore_url_params
    downloader = WaybackMachineDownloader.new(base_url: 'https://example.com')
    assert_equal 'article/test', downloader.normalize_url('article/test?')
  end

  def test_normalize_url_with_ignore_url_params_except
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params_except: ['id', 'page']
    )
    
    # Only specified parameters should be kept
    assert_equal 'article.html?id=123', 
                 downloader.normalize_url('article.html?id=123&utm_source=email&tracking=abc')
    
    assert_equal 'list.html?page=2', 
                 downloader.normalize_url('list.html?page=2&sort=date&filter=recent')
    
    # Both allowed parameters
    assert_equal 'view.html?id=456&page=3', 
                 downloader.normalize_url('view.html?id=456&page=3&other=value')
    
    # No allowed parameters present
    assert_equal 'page.html', 
                 downloader.normalize_url('page.html?utm_source=fb&tracking=123')
  end

  def test_normalize_url_parameter_order
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params_except: ['b', 'a', 'c']
    )
    
    # Parameters should be sorted for consistent ordering
    url1 = 'page.html?c=3&a=1&b=2'
    url2 = 'page.html?b=2&c=3&a=1'
    url3 = 'page.html?a=1&b=2&c=3'
    
    normalized = 'page.html?a=1&b=2&c=3'
    assert_equal normalized, downloader.normalize_url(url1)
    assert_equal normalized, downloader.normalize_url(url2)
    assert_equal normalized, downloader.normalize_url(url3)
  end

  def test_normalize_url_empty_params
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # Empty parameters
    assert_equal 'page.html', downloader.normalize_url('page.html?')
    assert_equal 'page.html', downloader.normalize_url('page.html?=')
    assert_equal 'page.html', downloader.normalize_url('page.html?&&')
  end

  def test_normalize_url_complex_cases
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # URL with path containing special characters
    assert_equal 'article/on-our-radar—feminist-news-roundup/test',
                 downloader.normalize_url('article/on-our-radar—feminist-news-roundup/test?param=1')
    
    # URL with encoded question mark in path (should remain)
    assert_equal 'article/title-with-%3F-mark',
                 downloader.normalize_url('article/title-with-%3F-mark?param=value')
  end

  def test_normalize_url_without_query_string
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # URLs without query strings should remain unchanged
    assert_equal 'page.html', downloader.normalize_url('page.html')
    assert_equal 'folder/page.html', downloader.normalize_url('folder/page.html')
  end

  def test_file_path_with_normalized_urls
    downloader = WaybackMachineDownloader.new(
      base_url: 'https://example.com',
      ignore_url_params: true
    )
    
    # Test that file paths are created correctly after normalization
    # This simulates what happens in get_file_list_curated
    file_id = 'subscribe/new?utm_campaign=Sale%20%232'
    normalized = downloader.normalize_url(file_id)
    unescaped = CGI::unescape(normalized)
    
    assert_equal 'subscribe/new', normalized
    assert_equal 'subscribe/new', unescaped
    refute_includes unescaped, '#'
    refute_includes unescaped, '?'
  end
end