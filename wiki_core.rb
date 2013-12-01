require 'sinatra'
require 'sinatra/reloader' if development?

require 'drip'
require 'drb'

require "rdiscount"

HOST_NAME = "localhost"
PORT_NUMBER = "54321"

configure do
	set :drip, DRbObject.new_with_uri("druby://#{HOST_NAME}:#{PORT_NUMBER}")
end

WIKI_NAMES_TAG = "__wiki_nemes__"
WIKI_NAME_PRE_SUF_FIX = "\\+{2}"

helpers do
	include Rack::Utils
	alias_method :h, :escape_html

	def unescape_slash(str)
		slash = Rack::Utils::ESCAPE_HTML["/"]
		str.gsub(/#{slash}/, "/")
	end
	alias_method :us, :unescape_slash

	def make_link(str, wiki_names)
		str.gsub(/#{WIKI_NAME_PRE_SUF_FIX}(.+?)#{WIKI_NAME_PRE_SUF_FIX}/) {"[#{$1}](/wiki/#{$1})"}
	end
end



get '/wiki' do
	#
	"wiki top"
end

get '/wiki/list' do
	drip = settings.drip
	_, wiki_names, = drip.head(1, WIKI_NAMES_TAG)[0]
	#wikiページの一覧を表示する
	@wiki_names = []
	wiki_names.each do |wiki_name, value|
		_, _, tag = drip.head(1, wiki_name.to_s)[0]
		@wiki_names << tag unless tag == WIKI_NAMES_TAG
	end
	erb :wiki_list
end

get '/wiki/history' do
	#wikiページの更新履歴を表示する
	@list = settings.drip.head(10)
	@list.reject! do |elem|
		elem[2] == WIKI_NAMES_TAG
	end
	@list.reverse! do |first, second|
		first[0] <=> second[0]
	end
	erb :wiki_history
end

get '/wiki/:name' do |name|
	@name = name
	edit = params[:edit]
	#該当のwikiページを表示する
	drip = settings.drip
	_, @value = drip.head(1, name)[0]
	_, wiki_names, = drip.head(1, WIKI_NAMES_TAG)[0]
	html_escaped = us h @value
	@contents = markdown(make_link(html_escaped, wiki_names))
	if @value and not edit
		erb :wiki_page
	else
		#まだ存在しない場合はwikiページ作成用のページを表示する
		@button_name = !edit ? "ページを作成" : "ページを編集"
		@previous_page = request.referer if edit
		@edit = edit
		erb :wiki_edit
	end
end


post '/wiki/:name' do |name|
	drip = settings.drip
	#wikiページの作成処理
	contents = params[:contents]
	drip.write(contents, name)
	if drip.head(1, WIKI_NAMES_TAG).empty?
		wiki_names = Hash.new
	else
		_, wiki_names = drip.head(1, WIKI_NAMES_TAG)[0]
	end
	wiki_names.store(name, true)
	drip.write(wiki_names, WIKI_NAMES_TAG)

	redirect "wiki/#{name}"
end