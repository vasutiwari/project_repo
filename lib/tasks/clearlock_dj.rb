require "rubygems"
require "yaml"
require "active_record"


dbconfig = YAML::load(File.open('../../config/database.yml'))
ActiveRecord::Base.establish_connection(dbconfig["development"])
class DelayedJob < ActiveRecord::Base
end

a=DelayedJob.where(["attempts = 0 && locked_at IS NOT NULL && failed_at is NULL  && locked_by IS NOT NULL && last_error IS NULL "]).collect{ |x| x.id}
a.each do |x|
d=DelayedJob.find(x)
d.attempts=1
d.failed_at=Time.now
d.last_error="cron job"
d.save false
end



