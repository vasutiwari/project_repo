class Template < ActiveRecord::Base

  belongs_to :property_type
  #belongs_to :super_admin_template
  belongs_to :user
  attr_accessible :parent_id
  #has_permalink [:template_name, :folder_name, :client_id]
  validates_uniqueness_of :folder_name, :scope => [:property_type_name, :client_id]
  #validates_uniqueness_of :template_name, :scope => [ :client_id]
  #has_one :template_name,:property_type_name





  def get_template_id(current_user_client_id)
    puts("************************")
    puts(current_user_client_id)
   # temp=Template.find_by_sql("SELECT max(ci.template_id) as template_id FROM templates ci ")
    temp=Template.find_by_sql("SELECT max(ci.template_id) as template_id FROM templates ci where ci.client_id=#{current_user_client_id} AND ci.is_editable=true")
    temp1=temp.first.template_id
    puts("*****************************")
    puts(temp1)
    if temp1==nil
      return 1
    else
      temp1+=1
      puts("*****************************")
      puts(temp1)
      return temp1
    end
  end

  def template_rename
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

  def find_template_by_id(id)
    Template.find(id)
  end

end
