module CollaborationHubHelper
  def find_my_folders_files_tasks
    unless params[:user] == 'false'
      if params[:deal_room] == "true"
        @portfolio = Portfolio.find_by_name_and_user_id("portfolio_created_by_system_for_deal_room",current_user.id)
        @folder = Folder.find_by_name_and_parent_id_and_user_id('my_deal_room',0,current_user.id)
      else
        @portfolio = Portfolio.find_by_name_and_user_id("portfolio_created_by_system",current_user.id)
        @folder = Folder.find_by_name_and_parent_id_and_user_id('my_files',0,current_user.id)
      end
    else
      cur_user = Portfolio.find(params[:pid]).user
      if params[:deal_room] == "true"
        @portfolio = Portfolio.find_by_name_and_user_id("portfolio_created_by_system_for_deal_room",cur_user.id)
        @folder = Folder.find_by_name_and_parent_id_and_user_id('my_deal_room',0,cur_user.id)
      else
        @portfolio = Portfolio.find_by_name_and_user_id("portfolio_created_by_system",cur_user.id)
        @folder = Folder.find_by_name_and_parent_id_and_user_id('my_files',0,cur_user.id)
      end
    end
    if params[:del_files] == "true"
      @folders= Folder.find_all_by_parent_id(@folder.id)
      @documents = Document.find_all_by_folder_id(@folder.id)
    else
      @folders= Folder.find_all_by_parent_id_and_is_deleted(@folder.id,false)
      tmp_arr = []
      if @folders.present?
        @folders.each do |folder|
           tmp_arr << folder unless( folder.present? && ( folder.name.eql?('Lease Files') || folder.name.eql?('Floor Plans') ) && folder.try(:real_estate_property).try(:property_name).eql?('property_created_by_system_for_deal_room') )
        end
      end
      @folders = tmp_arr
      @documents = Document.find_all_by_folder_id_and_is_deleted(@folder.id,false)
    end
    if params[:show_past_shared] == "true"
      params[:asset_id] = !params[:folder_id] || params[:document_id] ? @folder.id : @folder.parent_id
      find_past_shared_folders('false')
    end
  end

  def collect_properties(portfolio)
    properties = []
    real_estate_properties =  portfolio.real_estate_properties.find(:all,:order=>"id desc",:limit=>5)
    real_estate_properties.each do |property|
      sf = SharedFolder.find_by_real_estate_property_id_and_is_property_folder_and_user_id_and_client_id(property.id,true,current_user.id,current_user.client_id)
      if !sf.nil? || property.user_id == current_user.id
        property_name = property.property_name
        address = property.address != nil  && property.address.city != "" ? ", #{property.address.city} | " : " | "
        l = property_name + address
        properties << l
      end
    end
    properties = properties.empty? ? properties : properties.to_s.chop
    properties = properties.empty? ? properties :   portfolio.real_estate_properties && portfolio.real_estate_properties.length > 5 ? "#{properties.to_s}...." : properties
    return properties
  end

 def collect_shared_folders_doc_tasks_in_my_files
   @shared_folders_real_estate,@shared_docs_real_estate  = find_manage_real_estate_shared_folders('false')
   @folders = @folders + @shared_folders_real_estate
   @documents = @documents + @shared_docs_real_estate
end

def collect_shared_folders_docs_task_ids
     @sahred_folders_collection,@shared_docs_collection,@shared_properties_collection  = [],[],[]
     @sahred_folders_collection = @shared_folders_real_estate.collect{|x| x.id}.join(",")
     @shared_docs_collection = @shared_docs_real_estate.collect{|x| x.id}.join(",")
     @shared_and_owned_properties_collection = @real_estate_properties.collect{|x| x.id}.join(",")
end

def remove_already_existing_emails(users,number)
  swig_emails = users.count > 2 ? users[0]+','+users[1]+" and #{users.count - 2} more" : users.join(',')
  return FLASH_MESSAGES['collaborators'][number] + swig_emails
end

end
