class InsCategory < ActiveRecord::Base
  belongs_to :insurance
  belongs_to :category

  has_one  :note, :as => :note,    :dependent => :destroy
  def self.insurance_categories(insurance_catag_hash,insid)

    insurance_catag_hash.each do |ins_catag_key,ins_catag_val|
      self.create(:insurance_id => insid,:category_id => ins_catag_val[2], :is_required => ins_catag_val[0],:is_received =>   ins_catag_val[1]) if ins_catag_val[0].present? ||  ins_catag_val[1].present?
    end
  end

end
