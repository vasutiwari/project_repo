class VarianceThreshold < ActiveRecord::Base
  belongs_to :real_estate_property
  belongs_to :user

  def self.find_thresholds_value(id)
    VarianceThreshold.find_or_initialize_by_real_estate_property_id(id)
  end
end