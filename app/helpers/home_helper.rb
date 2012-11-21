require 'rss/2.0'
require 'open-uri'
module HomeHelper
def blog_feed
source = "http://www.multihousingnews.com/feed/" # url or local file
content = "" # raw content of rss feed will be loaded here
open(source) do |s| content = s.read end
rss = RSS::Parser.parse(content, false)
html = "<table style='border: 1px solid #007934;'>"
rss.items.first(5).each do |i|
html << "<tr><td><a href='#{i.link}'>#{i.title}</a><br/><br/>"
html << "#{i.description}<br/><br/></td></tr>"
end
html << "</table>"
end
end