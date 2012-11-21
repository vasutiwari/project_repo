class Hour < ActiveRecord::Base

  # Associations
  belongs_to :clause
  has_one :note, :as => :note,    :dependent => :destroy

  accepts_nested_attributes_for :note, :reject_if => lambda { |a|   a['content'].blank? } #, :allow_destroy => true
  def self.store_hour_items(*args)
    args = args.extract_options!
    hour = self.create(:building_hours => args[:building_hours], :business_hours => args[:business_hours], :clause_id => args[:clause_id])
    if !args[:content].empty?
      hour.build_note(:content => args[:content])
    hour.save
    end
  end
end
