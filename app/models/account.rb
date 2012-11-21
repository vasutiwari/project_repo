class Account < ActiveRecord::Base
		scope :chart_account_id, (lambda do |statement_type,chart_account_id|
    {:conditions => ['statement_type = ? AND chart_account_id = ?',statement_type,chart_account_id]}
  end)
	#Hash formed for mapping to database
	#~ def self.financial_statement
	FINANCIAL_STATEMENT = {"Income statement" => "Inc Stmt","Balance sheet" => "Bl Sheet" ,"Cash Flow" => "CF Stmt"}
	#~ end
	has_many :line_items,:dependent=>:destroy
	#~ accepts_nested_attributes_for :line_items,:allow_destroy=>true
end
