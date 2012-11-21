class CommercialLeaseOccupancy < ActiveRecord::Base
		belongs_to :real_estate_property
		
	  def self.procedure_call_for_commercial_occupancy(*args)
			args = args.extract_options!
			args.each{ |key, val| args[key] = 'NULL' if val.nil? }
			ret =ActiveRecord::Base.connection.execute("call commOccupancySummaryFindOrCreateCommercial(#{args[:current_yr_sf_occupiedIn]},#{args[:current_year_sf_vacantIn]},#{args[:yearIn]},#{args[:monthIn]},#{args[:new_leasesIn]},#{args[:lease_expiryIn]},#{args[:real_estate_property_id]},#{args[:last_year_sf_occupied_actualIn]})")
			ret = Document.record_to_hash(ret).first rescue nil
			ActiveRecord::Base.connection.reconnect!;ret
   end
end
