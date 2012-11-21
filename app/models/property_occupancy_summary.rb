class PropertyOccupancySummary < ActiveRecord::Base
	belongs_to :real_estate_property
  def self.procedure_call(*args)
    args = args.extract_options!
    args.each{ |key, val| args[key] = 'NULL' if val.nil? }
    ret =ActiveRecord::Base.connection.execute("call propOccupancySummaryFindOrCreate(#{args[:total_building_rentable_s]},#{args[:current_year_sf_occupied_actual]},#{args[:current_year_sf_vacant_actual]},#{args[:current_year_units_total_actual]},#{args[:vacant_leased_number]},#{args[:vacant_leased_percentage]},#{args[:currently_vacant_leases_number]}, #{args[:currently_vacant_leases_percentage]}, #{args[:occupied_preleased_number]}, #{args[:occupied_preleased_percentage]}, #{args[:occupied_on_notice_number]},#{args[:occupied_on_notice_percentage]},#{args[:net_exposure_to_vacancy_number]},#{args[:net_exposure_to_vacancy_percentage]},#{args[:current_year_units_occupied_actual]},#{args[:current_year_units_vacant_actual]},#{args[:real_estate_property_id]},#{args[:m_year]},#{args[:m_month]})")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!;ret
  end
end