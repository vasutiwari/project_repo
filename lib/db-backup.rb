require "rubygems"
require 'date'
require 'yaml'

databaseInfo = YAML::load(File.open("../config/database.yml").read)
settingsInfo = YAML::load(File.open("../config/settings.yml").read)

`mysqldump -u #{databaseInfo["production"]["username"]} -p#{databaseInfo["production"]["password"]}  #{databaseInfo["production"]["database"]}  >#{settingsInfo["production"]["backup_folder"]}/#{Date.today.to_s}.sql`

`rm -rf #{settingsInfo["production"]["backup_folder"]}/#{(Date.today-7).to_s}.sql `

