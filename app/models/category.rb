class Category < ActiveRecord::Base

  has_one     :requirement_note, :class_name => "Note"
  has_one   :tracking_note, :class_name => "Note"
  has_many :ins_categories
  has_many :insurances, :through => :ins_categories
  belongs_to :group
  def requirement_note
    Note.where(:note_type => "RequirementCategory", :note_id => self.id).try(:first) if self.id
  end

  def   tracking_note
    Note.where(:note_type => "TrackingCategory", :note_id => self.id).try(:first) if self.id
  end

end
