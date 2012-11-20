class Service < ActiveRecord::Base

  # Associations
  has_one :note, :as => :note, :dependent => :destroy
  belongs_to :clause

  accepts_nested_attributes_for :note
  def self.store_service_items(*args)
    args = args.extract_options!
    self.create(:category => args[:category], :item_name => args[:item_name], :l_para => args[:l_para], :clause_id => args[:clause_id])
  end
end
