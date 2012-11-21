class PropertyCapitalImprovement < ActiveRecord::Base
  attr_accessor :tool_tip
  belongs_to :property_suite
  belongs_to :real_estate_property
  belongs_to :portfolio
  has_many :property_financial_periods , :as => :source, :dependent => :destroy
  has_many :capital_expenditure_explanations
  def self.procedure_for_cap_exp(*args)
    args = args.extract_options!
    ret = ActiveRecord::Base.connection.execute("call propCapImpFindOrCreate(\"#{args[:nameIn]}\",#{args[:monthIn]},#{args[:yearIn]},#{args[:realIn]},\"#{args[:categoryIn]}\",\"#{args[:statusIn]}\",#{args[:annualIn]},#{args[:suiteIn] ? args[:suiteIn] : 'NULL'}, \"#{args[:typeIn]}\")")
    ret = Document.record_to_hash(ret).first
    ActiveRecord::Base.connection.reconnect!;ret
  end

  def self.procedure_for_cap_exp_new(*args)
    args = args.extract_options!
    ret = ActiveRecord::Base.connection.execute("call propCapImpFindOrCreate(\"#{args[:nameIn]}\",'NULL',#{args[:yearIn]},#{args[:realIn]},\"#{args[:categoryIn]}\",'NULL','NULL',#{args[:suiteIn] ? args[:suiteIn] : 'NULL'}, \"#{args[:typeIn]}\")")
    ret = Document.record_to_hash(ret).first
    ActiveRecord::Base.connection.reconnect!;ret
  end

end
