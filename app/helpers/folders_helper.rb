module FoldersHelper

  #Method for finding portfolio and folder using params[:pid] & params[:folder_id]
  def find_portfolio_and_folder
    @portfolio = Portfolio.find(params[:pid])
    @folder = Folder.find(:first,:conditions=> ["id = ?",params[:folder_id]])
  end


  #To find the subfolders and documents inside a folder and to update the is_deleted field based on Delete/Undelete
  def files_and_docs_of_folder(folder_id, loop_starts,fn)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted = ?",folder_id,!fn])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    folders.each do |f|
      @sub_shared_folders << SharedFolder.find(:all,:conditions=>['folder_id = ?',f.id]).flatten
      @sub_shared_docs << SharedDocument.find_all_by_folder_id(f.id).flatten
      @sub_shared_docs.flatten.each do |sub_shared_doc|
        is_folder_shared = SharedFolder.find_by_folder_id(sub_shared_doc.folder_id,:conditions=>["user_id = ?",sub_shared_doc.user_id])
        @sub_shared_docs_collection << sub_shared_doc if is_folder_shared.nil?
      end
      @sub_shared_folders.flatten.each do |sub_shared_folder|
        is_parent_folder_shared = SharedFolder.find_by_folder_id(sub_shared_folder.folder.parent_id,:conditions=>["user_id = ?",sub_shared_folder.user_id])
        @sub_shared_folders_collection << sub_shared_folder if is_parent_folder_shared.nil?
      end
      files_and_docs_of_folder(f.id, false,fn)
      @folder_s << f
      f.update_attributes(:is_deleted=>fn)
      f.documents.update_all(:is_deleted=>fn)
    end
  end

  def  find_sub_shared_docs
    sub_shared_docs = []
    sub_shared_docs << SharedDocument.find_all_by_folder_id(@folder.id).flatten
    sub_shared_docs.flatten.each do |sub_shared_doc|
      is_folder_shared = SharedFolder.find_by_folder_id(sub_shared_doc.folder_id,:conditions=>["user_id = ?",sub_shared_doc.user_id])
      @sub_shared_docs_collection << sub_shared_doc if is_folder_shared.nil? && sub_shared_doc.user_id != @folder.user.id
    end
  end


  #.....................To send mail while deleting folder....................
  def send_mail_while_deleting_folder(action_type)
    sh_flder_emails = []
    @repeat_email = false
    shared_folders_1= SharedFolder.find(:all,:conditions=>['folder_id = ?',@folder.id])
    fol_type = ((@folder.parent_id==0 && @folder.is_master.eql?(false)) ? 'property' : 'folder')
    unless shared_folders_1.empty?
      shared_folders_1.each do |subshared_folders_1|
        sh_flder_emails << subshared_folders_1.user.email
        @repeat_email = (subshared_folders_1.user.email == @folder.user.email) ? true : false if !@repeat_email
        UserMailer.delay.send_collab_folder_updates("#{action_type}", current_user, subshared_folders_1.user,@folder.name, @folder.name,fol_type,@folder) if subshared_folders_1.user.email != current_user.email
      end
    end
    @sub_shared_folders_collection  = @sub_shared_folders_collection  - shared_folders_1
    unless  @sub_shared_folders_collection.flatten.uniq.empty?
      @sub_shared_folders_collection.flatten.uniq.each do |sub|
        sh_flder_emails << sub.user.email
        @repeat_email = (sub.user.email == @folder.user.email) ? true : false if !@repeat_email
        UserMailer.delay.send_collab_folder_updates("#{action_type}", current_user, sub.user,sub.folder.name,sub.folder.name,'folder',@folder) if sub.user.email != current_user.email
      end
    end
    if @folder.user.email != current_user.email
      UserMailer.delay.send_collab_folder_updates("#{action_type}", current_user,@folder.user,@folder.name,@folder.name,'folder',@folder)
    end
  end


  def find_folder_to_update_page(obj,folder)
    if folder.parent_id == 0
      shared_property_folder = SharedFolder.find_by_folder_id_and_user_id_and_client_id(folder.id,current_user.id,current_user.client_id,:conditions=>["is_property_folder is not null and is_property_folder = true"]) if folder && folder.parent_id != -1
      @folder =  find_by_user_id_and_name(current_user.id,'my_files')  if shared_property_folder.nil? && request.env["HTTP_REFERER"] && (request.env["HTTP_REFERER"].include?("collaboration_hub") || request.env["HTTP_REFERER"].include?("shared_users") )
    else
      id = obj == 'folder' ? folder.parent_id : folder.id
      share_folder = SharedFolder.find_by_folder_id_and_user_id_and_client_id(id,current_user.id,current_user.client_id)
      @folder =  find_by_user_id_and_name(current_user.id,'my_files')  if share_folder.nil?  && (request.env["HTTP_REFERER"] && (request.env["HTTP_REFERER"].include?("collaboration_hub") || request.env["HTTP_REFERER"].include?("shared_users") ))
    end
  end

  #to find past shared folders
  def find_past_shared_folders(find_deleted_folders)
    params[:asset_id] =@folder.id
    conditions = find_deleted_folders == 'true' ?   "" : "and is_deleted = false"
    find_manage_real_estate_shared_folders('false')  if ( @folder.name == 'my_files' || @folder.name == 'my_deal_room') && @folder.parent_id == 0
    #to find folders,tasks,files shared to user ,then user shares that to some others
    folder_ids = (@shared_folders_real_estate && !@shared_folders_real_estate.empty?) ? @shared_folders_real_estate.collect{|f| f.id} :  []
    doc_ids = (@shared_docs_real_estate && !@shared_docs_real_estate.empty?) ? @shared_docs_real_estate.collect{|f| f.id} :  []
    #To find shared folders
    fids_in_cur_folder = Folder.find(:all,:conditions=>["(parent_id = ? or id in (?)) #{conditions}",params[:asset_id],folder_ids]).collect{|f| f.id}
    @folders = SharedFolder.find(:all,:conditions=>["sharer_id = ? and folder_id in (?) and user_id != sharer_id",current_user.id,fids_in_cur_folder]).collect{|sf| sf.folder}.uniq
    #To find shared documents
    docids_in_cur_folder = Document.find(:all,:conditions=>["(folder_id = ? or id in (?)) #{conditions}",params[:asset_id],doc_ids]).collect{|d| d.id}
    @documents  = SharedDocument.find(:all,:conditions=>["sharer_id = ? and document_id in (?) and user_id != sharer_id",current_user.id,docids_in_cur_folder]).collect{|sd| sd.document}.uniq
    return @folders,@documents
  end


  #updates the page after folder deletion
  def update_page_after_deletion
    if(params[:show_past_shared] == "true")
      find_past_shared_folders('false')
    else
      params[:del_type]  ? assign_options(@folder.id) : (@folder.parent_id == 0 ? assign_initial_options : assign_options(@folder.parent_id))
      @folder = Folder.find(@folder.parent_id) if @folder.parent_id !=0 && @delete_file != "true"
    end
    add_visual_effect_delete_file(@msg)
  end

  def check_folder_exists(folder_name_old,folder_id)
    folder = Folder.find_by_name(folder_name_old.strip,:conditions=>["parent_id = ? and real_estate_property_id is not NULL",folder_id])
    if folder.nil?
      return false
    else
      return true
    end
  end

  #To find the subfolders and documents inside a folder and to permanently delete the same
  def delete_files_and_docs_of_folder(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ?",folder_id])
    parent_folder = Folder.find_by_id(folder_id)
    if parent_folder !=nil && parent_folder.property != nil
      if parent_folder.parent_id == 0 && !parent_folder.is_master
        parent_folder.property.destroy
      end
    end
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    folders.each do |f|
      delete_files_and_docs_of_folder(f.id, false)
      @folder_s << f
      f.destroy
      f.documents.destroy_all
    end
  end


def title_display(id)
  return "Create Deal Room" if Folder.find(id).parent_id == 0 && params[:deal_room] == 'true'
  return "Create New Folder"
end

#To delete the zip file from public
def delete_zip(folder)
 if File.exists? "#{Rails.root.to_s}/public/#{folder.name}.zip"
   File.delete("#{Rails.root.to_s}/public/#{folder.name}.zip")
 end
end

end
