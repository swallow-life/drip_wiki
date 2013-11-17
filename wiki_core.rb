require 'sinatra'
require 'sinatra/reloader' if development?

require 'drip'
require 'drb'

require "rdiscount"

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
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
	wiki_names = list.map do |elem|
		elem[2] 
	end
	wiki_names.uniq!

	partial_html = ""
	wiki_names.each do |name|
  		partial_html << "<a href='/wiki/#{name}'>#{name}</a><br />"	
	end

RHTML = <<EOS
	<html>
		<head>
			<title>wiki</title>
		  	<meta name="viewport" content="width=320" />
		</head>
	  	<body>
	  		#{partial_html}
	  	</body>
	</html>
EOS
end

get '/wiki/history' do
	#wikiページの更新履歴を表示する
	list = settings.drip.head(10)
	partial_html = ""
	list.each do |elem|
		key,_,name = elem
		edit_time = Time.at(key / 1000000)
	  	partial_html << "<a href='/wiki/#{name}'>#{name}</a> [#{edit_time.strftime("%Y/%m/%d %X")}]<br />"
	end
	
RHTML = <<EOS
	<html>
		<head>
			<title>wiki</title>
		  	<meta name="viewport" content="width=320" />
		</head>
	  	<body>
	  		#{partial_html}
	  	</body>
	</html>
EOS
end

get '/wiki/:name' do |name|

	edit = params[:edit]
	#該当のwikiページを表示する
	drip = settings.drip
	_, v = drip.head(1, name)[0]
	if v and not edit
		contents = markdown(h v)

RHTML = <<EOS
	<html>
		<head>
			<title>wiki</title>
		  	<meta name="viewport" content="width=320" />
		</head>
	  	<body>
	  		<div>#{contents}</div>
	  		<a href="/wiki/#{name}?edit=true">編集</a>
		</body>
	</html>
EOS
		return RHTML

	end
	#まだ存在しない場合はwikiページ作成用のページを表示する
	button_name = !edit ? "ページを作成" : "ページを編集"
RHTML = <<EOS
	<html>
		<head>
			<title>wiki</title>
		  	<meta name="viewport" content="width=320" />
		</head>
	  	<body>
	    	<form method='post' action="/wiki/#{name}">
			   	<textarea name="contents" rows="8" cols="80">#{v}</textarea><br />
			   	<input type='submit' value='#{button_name}' />
	    	</form>
		</body>
	</html>
EOS
end


post '/wiki/:name' do |name|
	#wikiページの作成処理
	contents = params[:contents]
	settings.drip.write(contents, name)
	redirect "wiki/#{name}"
end