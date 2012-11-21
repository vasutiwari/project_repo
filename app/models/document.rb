class Document < ActiveRecord::Base
  has_attachment :storage => :file_system, :size => 1.kilobytes..60.megabytes, :content_type => ['application/vnd.ms-excel'], :path_prefix => 'public/documents'
  belongs_to :folder
  belongs_to :suite
  belongs_to :insurance
  belongs_to :lease
  belongs_to :user
  has_one  :note, :as => :note,    :dependent => :destroy
  has_one :document_name
  has_many :shared_documents, :dependent=>:destroy
  has_many :event_resources, :as=>:resource,:dependent=>:destroy
  belongs_to :real_estate_property
  belongs_to :property
  has_one :variance_threshold
  before_save :check_file_name_already_exists
  after_save :update_date_for_parents
  before_destroy :update_date_for_parents
  has_many :income_cash_flow_explanations
  has_many :capital_expenditure_explanations
  has_ipaper_and_uses 'AttachmentFu'
  acts_as_commentable
  scope :current_user_files, lambda { |folder_ids| { :conditions=>["folder_id in (#{folder_ids.join(',')})"]}}
  accepts_nested_attributes_for :note,:allow_destroy => true
  def self.attach_files_for_docs(data,propid,current_user_id,folderid,leaseid)
    docfile = Document.new
    docfile.uploaded_data = data
    docfile.folder_id = folderid
    docfile.real_estate_property_id = propid
    docfile.user_id = current_user_id
    docfile.lease_id = leaseid
    docfile.save
    return docfile
  end

  def self.attach_files_for_suites(data,propid,current_user_id,folderid,suiteid)
    docfile = Document.new
    docfile.uploaded_data = data
    docfile.suite_id = suiteid
    docfile.folder_id = folderid
    docfile.real_estate_property_id = propid
    docfile.user_id = current_user_id
    docfile.save
    return docfile
  end

  def update_attach_files_for_suites(data,propid,current_user_id,folderid,suiteid)
    self.update_attributes(:uploaded_data => data,:suite_id => suiteid,:folder_id  =>folderid,:real_estate_property_id => propid, :user_id => current_user_id)
  end

  def check_file_name_already_exists
    if self.id.nil?
      document = Document.find_by_folder_id(self.folder_id,:conditions=>["filename = ? and real_estate_property_id is not NULL",self.filename.strip])
    else
      document = Document.find_by_folder_id(self.folder_id,:conditions=>["filename = ? and real_estate_property_id is not NULL and id!=?",self.filename.strip,self.id])
    end
    i = 1
    while document !=nil
      extension = self.filename.split(".").pop
      first_set =  self.filename.split(".")
      first_set.pop
      first_set= first_set.join('.')
      document_name = "#{first_set}_#{i}.#{extension}"
      if self.id.nil?
        document = Document.find_by_folder_id(self.folder_id,:conditions=>["filename = ? and real_estate_property_id is not NULL",document_name.strip])
      else
        document = Document.find_by_folder_id(self.folder_id,:conditions=>["filename = ? and real_estate_property_id is not NULL and id!=?",document_name.strip,self.id])
      end
      i += 1
    end
    document_name =  document_name.nil? ? self.filename : document_name
    self.filename = document_name
  end

  def self.find_document_by_id(id)
    Document.find_by_id(id)
  end

  def self.find_document(id)
    Document.find_by_id(id)
  end

  def unshare_document(delete_user,params,current_user)
    params[:mem_id] = delete_user.id
    revoke_doc = SharedDocument.find_by_document_id(self.id,:conditions=>["user_id = ?",delete_user.id])
    r_user = User.find_by_id(delete_user.id)
    UserMailer.delay.folder_file_user_revoke_notification(self,current_user,r_user) if r_user
    Event.create_new_event("unshared",current_user.id,delete_user.id,[revoke_doc.document],current_user.user_role(current_user.id),self.filename,nil)
    revoke_doc.destroy unless revoke_doc.nil?
  end

  def change_attributes(current_user,params)
    if_or_else = true
    file_collaborators = self.user.id == current_user.id ? [] : [self.user]
    if !(params[:value].blank? || params[:value] == self.filename)
      old_name = self.filename
      self.update_attributes(:filename=>params[:value])
      d = self.updated_at.strftime("%b %d")
      Event.create_new_event("rename",current_user.id,nil,[self],current_user.user_role(current_user.id),self.filename,old_name)
      #rename notification
      shared_docs = SharedDocument.find_all_by_document_id(self.id)
      unless shared_docs.blank?
        shared_docs_users = shared_docs.collect { |shared_document| shared_document.user }
      file_collaborators += shared_docs_users
      end
      unless file_collaborators.blank?
        file_collaborators.each do |collaborator|
          UserMailer.delay.rename_notification(current_user,collaborator,old_name,params[:value],self,"File") if current_user.id != collaborator.id
        end
      end
    if_or_else = true
    else
      d = self.updated_at.strftime("%b %d") unless self.nil?
    if_or_else = false
    end
    return self.filename,d,if_or_else
  end

  def self.record_to_hash(result)
    rows  = []
    result.each_hash { |row| rows << row }
    rows
  end

  def update_date_for_parents
    self.folder.update_attribute("updated_at",Time.now) if self.folder
  end
end
