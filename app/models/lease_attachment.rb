class LeaseAttachment < ActiveRecord::Base
  has_attachment :storage => :file_system, :size => 1.kilobytes..60.megabytes, :content_type => ['application/vnd.ms-excel'], :path_prefix => 'public/leasedocuments'
  belongs_to :attachable, :polymorphic => true
  #~ has_ipaper_and_uses 'AttachmentFu'
  belongs_to :insurance
  belongs_to :user
  def self.attach_files_for_insurance(data,insurid,current_user_id)
    data.each do |key,insurancefile|
      if insurancefile.present?
        insurance_doc = LeaseAttachment.new
        insurance_doc.uploaded_data = insurancefile
        insurance_doc.attachable_id = insurid
        insurance_doc.attachable_type = "Insurance"
      insurance_doc.user_id = current_user_id
      insurance_doc.save
      end
    end
  end

end
