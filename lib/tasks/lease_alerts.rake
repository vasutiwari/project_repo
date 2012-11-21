require "#{Rails.root}/app/helpers/properties_helper"
include PropertiesHelper

require "#{Rails.root}/app/helpers/application_helper"
include ApplicationHelper

namespace :lease_alerts do
  desc "Inserting the data into lease rent roll table"
  task :send_weekly_alerts => :environment do
    send_weekly_alerts
  end
end