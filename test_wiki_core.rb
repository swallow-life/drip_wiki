#ENV['RACK_ENV'] = 'test'

require './wiki_core'
require 'test/unit'
require 'rack/test'

class WikiCoreTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_it_says_wiki_top
    get '/wiki'
    assert last_response.ok?
    assert_equal 'wiki top', last_response.body
  end

=begin
  def test_regexp
    result = "/wiki/test".sub(%r</[^/]+?\z>, "")
    assert_equal '/wiki', result
  end
=end

  def test_rwiki_list
    get '/wiki/list'
    assert last_response.ok?
  end
end