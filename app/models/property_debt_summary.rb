class PropertyDebtSummary < ActiveRecord::Base
	belongs_to :real_estate_property
	
	def self.create_debt_summary_details(property_id,key,value)
			debt_summary = PropertyDebtSummary.new
			debt_summary.real_estate_property_id = property_id
			debt_summary.month = Date.today.month
			debt_summary.year = Date.today.year
			debt_summary.category = key
			debt_summary.description =value
			debt_summary.save
	end	
		
def self.delete_debt_summary_details(property_id,loan_number)
    debtsummary = PropertyDebtSummary.find(:all,:conditions =>["real_estate_property_id = ?",property_id])
      summary_array = []
      summary_array = debtsummary.each_slice(13).to_a
      if summary_array != nil
        summary_array[loan_number.to_i].each do |s|
          s.destroy
        end
      end
end
end
