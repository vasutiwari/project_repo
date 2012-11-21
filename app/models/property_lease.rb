class PropertyLease < ActiveRecord::Base
  belongs_to :property_suite
 def self.in_rent_roll_exp(id,month,year)
    return PropertyLease.find(:first, :conditions => ["property_suite_id = ? and month = ? and year= ?",id,month,year])
  end
  def self.in_lease_exp(id,month,year,occupency_type)
    return PropertyLease.find(:first, :conditions => ["id = ? and month = ? and year= ? and	occupancy_type = ? ",id,month,year,occupency_type])
  end

  def self.procedure_call(*args)
    args = args.extract_options!
    args.each{ |key, val| args[key] = 'NULL' if val.nil? }
    ret =ActiveRecord::Base.connection.execute("call propLeaseFindOrCreate(#{args[:propSuiteId]}, \"#{args[:nameIn]}\", \"#{args[:startDate]}\", \"#{args[:endDate]}\", #{args[:baseRent]}, #{args[:effRate]}, #{args[:tenantImp]}, #{args[:leasingComm]}, #{args[:monthIn]}, #{args[:yearIn]}, #{args[:otherDepIn]}, \"#{args[:commentsIn] == 'NULL' ? '' : args[:commentsIn] }\", #{args[:amtPerSQFT]}, \"#{args[:occType]}\",\"#{args[:sStatus]}\")")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!;ret
  end

  def self.procedure_call_amp_all_units(*args) # Under review has to be changed.
    args = args.extract_options!
    args.each{ |key, val| args[key] = 'NULL' if val.nil? }
    ActiveRecord::Base.connection.execute("call propLeaseAmpWresAllUnitsFindOrCreate(#{args[:propSuiteId]}, \"#{args[:nameIn]}\", \"#{args[:startDate]}\", \"#{args[:endDate]}\", #{args[:baseRent]}, #{args[:effRate]}, #{args[:tenantImp]}, #{args[:leasingComm]}, #{args[:monthIn]}, #{args[:yearIn]}, #{args[:otherDepIn]}, \"#{args[:commentsIn] == 'NULL' ? '' : args[:commentsIn] }\", #{args[:amtPerSQFT]}, \"#{args[:occType]}\", \"#{args[:moveIn]}\", #{args[:madeReadyIn]}, #{args[:actAmtPerSQFT]})")
    ActiveRecord::Base.connection.reconnect!
  end

end
