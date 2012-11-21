class ChartOfAccount < ActiveRecord::Base
	belongs_to :accounting_system_type
	scope :by_client_ids, (lambda do |client_id|
    {:include=>[:accounting_system_type],:conditions => ['client_id = ?', client_id]}
  end)
	has_many :line_items,:dependent=>:destroy
	has_many :capital_expenditures,:dependent=>:destroy
	has_many :main_headers,:dependent=>:destroy
	has_many :portfolios

	accepts_nested_attributes_for :line_items,:allow_destroy=>true
	accepts_nested_attributes_for :capital_expenditures,:allow_destroy=>true
	accepts_nested_attributes_for :main_headers,:allow_destroy=>true

	#~ def self.create_records
    #~ 1.upto(200).each do |record_id|
      #~ if record_id%2==0
      #~ normal_balance = "CR"
      #~ else
         #~ normal_balance = "DR"
        #~ end
    #~ Account.create(:name => "name #{record_id}", :total_id => record_id-1, :total_name => "total name #{record_id}", :normal_balance => normal_balance , :account_type => "Type #{record_id}")
 #~ ChartOfAccount.create(:name=>"Testing #{record_id}",:accounting_system_type_id=>2,:client_id=>1)
 #~ end
  #~ end
end

