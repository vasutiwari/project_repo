class FoldersController < ApplicationController
  before_filter :user_required, :except => ['download_folder_for_share_link']
  layout 'user',:except=>['view_folder']
  before_filter :find_portfolio_and_folder, :only => ['view_folder','new_folder']
  before_filter :find_folder, :only => ['change_folder_name','folder_download','download_folder_for_share_link']
  #To view the file for creating a new folder
  def view_folder
    #~ find_portfolio_and_folder
  end

  #To create a new folder
  def new_folder
    #~ find_portfolio_and_folder
    folder_name = find_folder_name(@folder.id,params[:folder_name])
    folder_property = Folder.find_by_real_estate_property_id_and_parent_id(@folder.real_estate_property_id,0) if @folder
    portfolio_id = (folder_property && folder_property.portfolio_id) ?  folder_property.portfolio_id : @portfolio.id
    folder=Folder.create(:name=>folder_name,:parent_id=>@folder.id,:portfolio_id=>portfolio_id,:user_id=>current_user.id,:real_estate_property_id=>@folder.real_estate_property_id)
    #to restrict the auto sharing inside the property folder
    unless params[:collaborators_list].blank?
      @member_emails =[]
      owner=Folder.find(params[:folder_id]).user.email
      email_ids = params[:collaborators_list].split(',')
      email_ids.each do |m|
        @member_emails << m.strip  if m.strip != owner
      end
      email_ids = email_ids.reject{|email_id| current_user.email == email_id}
      share_folder(email_ids,folder)
    end
    if @folder.parent_id != 0
      shared_folders_1= SharedFolder.find(:all,:conditions=>['folder_id = ?',@folder.id])
      create_share_folders(shared_folders_1,folder)
    end
    Event.create_new_event("create",current_user.id,nil,[folder],current_user.user_role(current_user.id),folder.name,nil)
    assign_params("asset_data_and_documents","show_asset_files")
    assign_options
    add_visual_effect_folder_file_name("Folder","created")
  end

  #to share_folder
  def share_folder(email_ids,folder)
    folder_id = folder.id
    @user = User.current
    email_ids.each do |e|
      su,su_already = User.create_new_user(e,params,@user.id)
      parent = SharedFolder.find_by_folder_id_and_user_id_and_client_id(folder.parent_id,su.id,su.client_id) if !(folder.parent_id == 0)
      current_folder = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_is_property_folder(folder_id,su.id,User.current,@folder.real_estate_property_id,params[:is_property_folder])
      current_folder.update_attributes(:sharer_id=>current_user.id,:comments=>params[:textarea])
      params[:deal_room] == 'true' ? UserMailer.delay.share_notification_for_deal(su,current_folder,'folder',current_user,su_already) : UserMailer.delay.share_notification(su,current_folder,'folder',current_user,su_already)
      params[:deal_room] == 'true' ? Event.create_new_event("shared",@user.id,su.id,[current_folder.folder],@user.user_role(@user.id),current_folder.folder.name,nil) : Event.create_new_event("shared",@user.id,su.id,[current_folder.folder],@user.user_role(@user.id),@folder.name,nil)
    end
  end

  #To Temporarily delete or Undelete a folder
  def del_or_revert_folder
    @sub_shared_folders,@sub_shared_folders_collection,@sub_shared_docs,@sub_shared_docs_collection,sub_shared_docs  = [],[],[],[],[]
    fn = (params[:fn] == 'false') ? false : true
    find_portfolio_and_folder
    files_and_docs_of_folder(@folder.id,true,fn)
    find_sub_shared_docs
    @folder.update_attributes(:is_deleted=>fn)
    @folder.documents.update_all(:is_deleted=>fn)
    action_type = (params[:fn] == 'false') ? "restored" : "deleted"
    send_mail_while_deleting_folder(action_type)
    send_mail_while_deleting_document(action_type)
    (params[:fn] == 'false') ? Event.create_new_event("restored",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,nil) : Event.create_new_event("delete",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,nil)
    assign_params("asset_data_and_documents", "show_asset_files")
    @msg = fn == false ? "#{@folder.name} has been reverted" : "#{@folder.name} successfully deleted"
    @folder = Folder.find(@folder.parent_id) if @folder.parent_id!=0 && params[:show_past_shared] == 'true'
    find_folder_to_update_page('folder',@folder) if @folder.user_id != current_user.id
    update_page_after_deletion
  end

  #To permanently delete a folder
  def delete_folder
    @sub_shared_folders,@sub_shared_folders_collection,@sub_shared_docs,@sub_shared_docs_collection,sub_shared_docs  = [],[],[],[],[]
    action_type = "deleted"
    find_portfolio_and_folder
    cur_folder_parent_id = @folder.parent_id
    files_and_docs_of_folder(@folder.id,true,false)
    find_sub_shared_docs
    send_mail_while_deleting_document(action_type)
    send_mail_while_deleting_folder(action_type)
    delete_files_and_docs_of_folder(@folder.id,true)
    Event.create_new_event("permanent_delete",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,nil)
    @folder.real_estate_property.destroy if @folder.real_estate_property_id !=nil && @folder.parent_id ==0
    @folder.destroy
    assign_params("asset_data_and_documents","show_asset_files" )
    @msg = "#{@folder.name} successfully deleted"
    update_page_after_deletion
    @folder = Folder.find(@folder.parent_id) if @folder.parent_id !=0 && @folder.parent_id != -2
  end

  #renames folder
  def change_folder_name
    #~ folder =Folder.find_folder(params[:id])
    folder_collaborators = @folder.user.id == current_user.id ? [] : [@folder.user]
    old_name = @folder.name
    if !(params[:value].blank? || params[:value] == @folder.name)
      @folder.update_attributes(:name=>params[:value])
      d = @folder.updated_at.strftime("%b %d")
      past_shared_folders = SharedFolder.find(:all,:conditions=>["sharer_id = ? and folder_id = ? and user_id != sharer_id",User.current,@folder.id]).collect{|sf| sf.folder}.uniq
      if @folder.user_id == current_user.id && (past_shared_folders && past_shared_folders.index(@folder))
        im = "owner.png"
      elsif  @folder.user_id != current_user.id
        im = "co_owner.png"
      end
      Event.create_new_event("rename",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,old_name)
      #rename notification
      shared_folders = SharedFolder.find_all_by_folder_id(@folder.id)
      unless shared_folders.blank?
        shared_folder_users = shared_folders.collect { |shared_folder| shared_folder.user }
      folder_collaborators += shared_folder_users
      end
      unless folder_collaborators.blank?
        folder_collaborators.each do |collaborator|
          UserMailer.delay.rename_notification(current_user,collaborator,old_name,params[:value],@folder,"Folder") if current_user.id != collaborator.id
        end
      end
      render :update do |page|
        page.replace "folder#{params[:id]}", :partial=>"properties/folders_row", :locals=>{:a=>@folder,:folder_index=>params[:zindex], :x=>params[:zindex]}
        page.call("flash_writter","Folder renamed to #{@folder.name}")
      end
    else
      render :update do |page|
        d = @folder.updated_at.strftime("%b %d")
        page.call("do_folder_update","#{params[:id]}","#{lengthy_word_simplification(@folder.name)}",d,im,folder.name)
      end
    end
  end

  def folder_download
    #~ folder =Folder.find_folder(params[:id])
    delete_zip(@folder)
    Zip::ZipFile.open("#{Rails.root.to_s}/public/#{@folder.name}.zip", Zip::ZipFile::CREATE) { |zipfile|
      dwn_fld(@folder.id,zipfile)
    }
    Event.create_new_event("download",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,nil)
    send_file "#{Rails.root.to_s}/public/#{@folder.name}.zip"
    delete_zip(@folder)
  end

  def download_folder_for_share_link
    #~ folder =Folder.find_folder(params[:id])
    delete_zip(@folder)
    Zip::ZipFile.open("#{Rails.root.to_s}/public/#{@folder.name}.zip", Zip::ZipFile::CREATE) { |zipfile|
      dwn_fld(@folder.id,zipfile)
    }
    send_file "#{Rails.root.to_s}/public/#{@folder.name}.zip"
    delete_zip(@folder)
  end

  #Find folder for
  def find_folder
    @folder =Folder.find_folder(params[:id])
  end

  def zip_content

  end

end
