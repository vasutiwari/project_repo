class Insurance < ActiveRecord::Base
  has_many   :ins_categories,  :dependent => :destroy
  has_many   :documents ,      :dependent => :destroy
  has_many   :categories,      :through => :ins_categories
  belongs_to :lease

  accepts_nested_attributes_for :categories,:ins_categories
  #~ accepts_nested_attributes_for :documents,:allow_destroy => true,:reject_if => lambda { |a|   a['uploaded_data'].blank? && a['_destroy'] != "1"}
  accepts_nested_attributes_for :documents,:allow_destroy => true,:reject_if => lambda { |a|  validation(a)  }


def self.validation(a)
  a['uploaded_data'].blank? && a['_destroy'] != "1" && !(a['filename'].present? && a['expiration'] != "mm/dd/yyyy")
end

end
