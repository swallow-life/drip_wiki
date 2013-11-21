require 'sinatra'
require 'sinatra/reloader' if development?

require 'drip'
require 'drb'

require "rdiscount"

helpers do
	include Rack::Utils
	alias_method :h, :escape_html

	def unescape_slash(str) 
		str.gsub(/&#x2F;/, "/")
	end
	alias_method :us, :unescape_slash

end


configure do
	set :drip, DRbObject.new_with_uri('druby://localhost:54321')
end

get '/wiki' do
	#
	"wiki top"
end

get '/wiki/list' do
	#wikiページの一覧を表示する
	list = settings.drip.head(10)
	@wiki_names = list.map do |elem|
		elem[2] 
	end
	@wiki_names.uniq!
	erb :wiki_list
end

get '/wiki/history' do
	#wikiページの更新履歴を表示する
	@list = settings.drip.head(10)
	erb :wiki_history
end

get '/wiki/:name' do |name|
	@name = name
	edit = params[:edit]
	#該当のwikiページを表示する
	drip = settings.drip
	_, @value = drip.head(1, name)[0]
	if @value and not edit
		@contents = markdown(us h @value)
		return erb :wiki_page
	end
	#まだ存在しない場合はwikiページ作成用のページを表示する
	@button_name = !edit ? "ページを作成" : "ページを編集"
	erb :wiki_edit
end


post '/wiki/:name' do |name|
	#wikiページの作成処理
	contents = params[:contents]
	settings.drip.write(contents, name)
	redirect "wiki/#{name}"
end