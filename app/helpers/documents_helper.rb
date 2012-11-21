module DocumentsHelper
  def find_doc_members
    params[:id] = params[:id] ? params[:id] : params[:document_id]
    @members  = SharedDocument.find(:all,:conditions=>["document_id = ? and user_id!= ?",params[:id],current_user.id]).collect{|sd| sd.user}.compact
   return  @members
 end

   def update_page_after_file_deletion
    find_folders_collection_based_on_params
    add_visual_effect_delete_file(@msg)
  end

   def send_mail_while_deleting_document(action_type)
    sh_flder_emails =[]
    sh_document_emails = []
    @sub_shared_docs_collection.flatten.uniq.each do |shared_document|
      @document = shared_document.document
      shared_folders_1 = SharedFolder.find(:all,:conditions=>['folder_id = ?',@folder.id])
      sh_documents = SharedDocument.find(:all,:conditions=>['document_id = ?',@document.id])
      unless sh_documents.empty?
        sh_documents.each do |subsh_documents|
          sh_document_emails << subsh_documents.user.email
        end
      end
      @repeat_email = false
      unless shared_folders_1.empty?
        shared_folders_1.each do |subshared_folders_1|
          sh_flder_emails << subshared_folders_1.user.email
          @repeat_email = (subshared_folders_1.user.email == @folder.user.email) ? true : false if !@repeat_email
        end
      end
      diff = sh_document_emails - sh_flder_emails
      unless diff.uniq.empty?
        diff.uniq.each do |diff_email|
          shared_user = User.find_by_email(diff_email)
          UserMailer.delay.send_collab_folder_updates("#{action_type}", current_user, shared_user, @document.filename, @folder.name,'document',@document) if diff_email != current_user.email
        end
      end
    end
  end


  def check_doc_exists(doc_name_old,folder_id)
    document = Document.find_by_folder_id(folder_id,:conditions=>["filename = ? and real_estate_property_id is not NULL",doc_name_old])
    if document.nil?
      return false
    else
      return true
    end
  end

  def shared_documents_and_folders_emails(delete_option,sh_documents,shared_folders_1)
    sh_document_emails , sh_flder_emails = [] , []
    sh_documents.each do |subsh_documents|
      sh_document_emails << subsh_documents.user.email
    end
    @repeat_email = false
    shared_folders_1.each do |subshared_folders_1|
      sh_flder_emails << subshared_folders_1.user.email
      @repeat_email = (subshared_folders_1.user.email == @folder.user.email) ? true : false if !@repeat_email
      UserMailer.delay.send_collab_folder_updates(delete_option, current_user, subshared_folders_1.user, @document.filename, @folder.name,'document',@document) if subshared_folders_1.user.email != current_user.email
    end
    diff = sh_document_emails - sh_flder_emails
    mail_sent = false
    diff.each do |diff_email|
      shared_user = User.find_by_email(diff_email)
      UserMailer.delay.send_collab_folder_updates(delete_option, current_user, shared_user, @document.filename, @folder.name,'document',@document) if diff_email != current_user.email
      mail_sent = true
    end
    return mail_sent
  end

    def find_document_collection(documents_collection)
      other_docs =documents_collection
      other_docs = other_docs.compact.sort_by(&:created_at).reverse
      documents_collection = other_docs.flatten.compact
    return documents_collection
  end

def is_parsing_folder(folder_id)
  parent_folder = Folder.find_folder(folder_id)
  @gr_parent_folder = Folder.find_folder(parent_folder.parent_id) if !parent_folder.nil?
  @gr_gr_parent_folder = Folder.find_folder(@gr_parent_folder.parent_id) if !@gr_parent_folder.nil?
  @gr_gr_parent_folder.nil? ? false : true
end
end
