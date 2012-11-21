require 'rubygems'
require 'nokogiri'
require 'mysql'

tbl_name = ARGV[0] ||= ''
return 8 if tbl_name.empty?
amp_db = Mysql.new('localhost', 'root', 'root', 'theamp2_rails3')
puts "Retriving table details of Property ..."
#p "jruby #{Rails.root.to_s}/lib/InvokeGriffin.rb \"select * from information_schema.columns where table_name = 'Property' order by ordinal_position FOR XML RAW\" "
#pipe = IO.popen "jruby #{Rails.root.to_s}/lib/InvokeGriffin.rb \"select * from information_schema.columns where table_name = 'Property' order by ordinal_position FOR XML RAW\""
#p pipe.read
qry = "CREATE TABLE IF NOT EXISTS Griffin_#{tbl_name} ("
row_expr = ["id INTEGER PRIMARY KEY AUTO_INCREMENT"]
mp =  {"numeric"=> "DOUBLE","char"=>"VARCHAR(255)","varchar"=>"VARCHAR(255)","datetime"=>"DATETIME","int"=>"INTEGER"}
reader = Nokogiri::XML::Reader(IO.read('/home/sasindran/projects/theamp2new/GriffinResponse.xml'))
reader.each do |node|
  if node.name == 'row' and node.node_type==1
    row_expr << "#{node.attribute('COLUMN_NAME')} #{["HPPTY", "HACCT","HMY"].include?(node.attribute('COLUMN_NAME')) ? 'INTEGER' : mp[node.attribute('DATA_TYPE')]} #{node.attribute('IS_NULLABLE') == 'YES' ? 'DEFAULT NULL' : 'NOT NULL' }"
  end
end
#puts qry + row_expr.join(',')+ ') ENGINE=MyISAM DEFAULT CHARSET=latin1;'
amp_db.query(qry + row_expr.join(',')+ ') ENGINE=MyISAM DEFAULT CHARSET=latin1;') unless row_expr.empty?
puts "#{tbl_name} table has been created."