class LeasesExplanation < ActiveRecord::Base
	  def self.lease_explanation(id,occupancy_type,property_id)
    return LeasesExplanation.find(:first, :conditions => ["lease_id = ? and 	occupancy_type = ? and real_estate_property_id = ? ",id,occupancy_type,property_id])
  end
end
