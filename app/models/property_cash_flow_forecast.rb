class PropertyCashFlowForecast < ActiveRecord::Base
  belongs_to :user
	has_many :property_financial_periods, :as=>:source, :dependent=>:destroy
  has_one :income_cash_flow_explanation
end
