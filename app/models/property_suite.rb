class PropertySuite < ActiveRecord::Base
  has_many :property_leases
  has_one :property_capital_improvement, :dependent=>:destroy
  has_one :property_aged_receivable
  belongs_to :real_estate_property

  def self.procedure_call(*args)
    args = args.extract_options!
    current_client_id = args[:currentClientId] if args.present?
    ret = ActiveRecord::Base.connection.execute("call propSuiteFindOrCreate(\"#{args[:suiteIn]}\", #{args[:realIn]}, #{args[:areaIn]}, \"#{args[:spaceTypeIn]}\",\"#{args[:scodeIn]}\", \"#{current_client_id}\" )")
    ret = Document.record_to_hash(ret).first
    ActiveRecord::Base.connection.reconnect!;ret
  end

  #To set client_id in property suite table
  def set_client_id_in_property_suite
    self.client_id = self.user.try(:client_id)
  end
end