class Clause < ActiveRecord::Base

  # Associations
  has_one    :hour,            :dependent => :destroy
  has_many   :services,        :dependent => :destroy
  has_one    :legal_provision, :dependent => :destroy
  has_many   :items,           :dependent => :destroy
  belongs_to :lease

  accepts_nested_attributes_for :hour, :legal_provision

  accepts_nested_attributes_for :items , :reject_if => lambda { |a|   a['name'].blank? }, :allow_destroy => true
  #~ accepts_nested_attributes_for :services , :reject_if => lambda { |a| (a['item_name'].blank? && a['l_para'].blank?)}, :allow_destroy => true
  #~ accepts_nested_attributes_for :items , :allow_destroy => true
  accepts_nested_attributes_for :services , :allow_destroy => true
end
