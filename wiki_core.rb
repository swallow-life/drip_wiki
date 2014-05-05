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
WIKI_CONTENTS_TAG = "__wiki_contents__"
WIKI_NAME_PRE_SUF_FIX = "\\+{2}"
WIKI_NAME = /\+{2}(.+?)\+{2}/
WIKI_LINK_PRE_FIX = "\\[{2}"
WIKI_LINK_SUF_FIX = "\\]{2}"
WIKI_LINK = /\[{2}(.+?)\]{2}/

helpers do
	include Rack::Utils
	alias_method :h, :escape_html

	def unescape_slash(str)
		slash = Rack::Utils::ESCAPE_HTML["/"]
		str.gsub(/#{slash}/, "/")
	end
	alias_method :us, :unescape_slash

	def make_link(contents, parent_page)
		#page配下へのリンクを作る。
		contents.gsub!(WIKI_NAME) do
			"[#{$1}](#{parent_page}/#{$1})"
		end
		#リンクを作る。
		contents.gsub!(WIKI_LINK) do
			"[#{$1}](/wiki/#{$1})"
		end
		contents
	end
end

get '/wiki/?' do
	drip = settings.drip
	_, wiki_names, = drip.head(1, WIKI_NAMES_TAG)[0]
	#wikiページの一覧を表示する
	@wiki_names = []
	wiki_names.each do |wiki_name, value|
		_, _, tag = drip.head(1, wiki_name.to_s)[0]
		@wiki_names << tag unless tag == WIKI_NAMES_TAG
	end
	@wiki_names.sort!
	erb :wiki_list
end

get %r{/wiki/history/(\d+)} do |drip_key|
	@value, @name = settings.drip[drip_key.to_i]
	escaped_html = us h @value
	@contents = markdown(make_link(escaped_html, "/wiki/#{@name}"))
	@edit = false
	@freeze = true
	erb :wiki_page
end

get '/wiki/history/?*' do |wiki_name|
	#wikiページの更新履歴を表示する
	#wiki名の指定なしの場合は全履歴、指定ありの場合はそのページの履歴
	tag = wiki_name.empty? ? WIKI_CONTENTS_TAG : wiki_name
	@list = settings.drip.head(100, tag)
	#新しい更新履歴が最初にくるようにソート
	@list.reverse! do |first, second|
		first[0] <=> second[0]
	end
	erb :wiki_history
end

get '/wiki/*' do |name|
	@name = name
	edit = params[:edit]
	#該当のwikiページを表示する
	drip = settings.drip
	_, @value = drip.head(1, name)[0]
#	_, wiki_names, = drip.head(1, WIKI_NAMES_TAG)[0]
	escaped_html = us h @value
	@contents = markdown(make_link(escaped_html, request.path_info))
	if @value and not edit
		erb :wiki_page
	else
		#まだ存在しない場合はwikiページ作成用のページを表示する
		if edit
			@button_name = "ページを編集"
		else
			@button_name = "ページを作成"
			@previous_page = request.path_info.sub(%r{/[^/]+?\z}, "")
		end
		@edit = edit
		erb :wiki_edit
	end
end


post '/wiki/*' do |name|
	drip = settings.drip
	#wikiページの作成処理
	contents = params[:contents]
	# 要検証
	drip.write(contents, name, WIKI_CONTENTS_TAG)
	if drip.head(1, WIKI_NAMES_TAG).empty?
		wiki_names = Hash.new
	else
		_, wiki_names = drip.head(1, WIKI_NAMES_TAG)[0]
	end

	unless wiki_names.key? name
		wiki_names.store(name, true)
		drip.write(wiki_names, WIKI_NAMES_TAG)
	end

	redirect "wiki/#{name}"
end