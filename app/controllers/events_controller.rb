include ActionView::Helpers::DateHelper
class EventsController < ApplicationController
  before_filter :user_required
  before_filter :action_type, :only => [:filter_events,:view_events_folder_for_all_users,:view_events_folder_for_filter_events,:view_events_folder]
  @@option_page = 30  # ADD the limit of the events to be displayed.

  def folder_display
    if params[:id]
      @folder = Folder.find(params[:id])
      if @folder
        params[:exec_tab] = ""
        params[:data_hub_tab] = "data_hub"
        redirect_to show_folder_files_asset_path(:pid => @folder.portfolio_id,:folder_id => @folder.id) if !@folder.real_estate_property_id?
        redirect_to show_folder_files_property_path(:pid => @folder.portfolio_id,:folder_id => @folder.id, :exec_tab=>params[:exec_tab], :partial_disp=>params[:data_hub_tab]) if @folder.real_estate_property_id?
      end
    end
  end

  def filter_events
    if params[:shared_user_id]=='All Users'
      view_events_folder_for_all_users
    else
      view_events_folder_for_filter_events
    end
  end

  def view_events_folder_for_all_users
    view_events_folder_foe_all_and_filter_events(params,'all')
  end

  def view_events_folder_for_filter_events
    view_events_folder_foe_all_and_filter_events(params,'filter')
  end

  def view_events_folder
    shared_folder_collab_hub,shared_doc_collab_hub,events_conditions,@event_ids,@all_folders_ids,@all_documents_ids,@all_document_names_ids = [],[],[],[],[],[],[]
    @folder = Folder.find(params[:folder_id])
    @portfolio = @folder.portfolio
    find_all_folders_n_subfolders(params[:folder_id])
    shared_folder_collab_hub  = params[:shared_folders].split(",") if !(params[:shared_folders].nil? || params[:shared_folders].blank?)
    shared_doc_collab_hub  = params[:shared_docs].split(",") if !(params[:shared_docs].nil? || params[:shared_docs].blank?)
    owned_and_shared_properties  = params[:owned_and_shared_properties].split(",") if !(params[:owned_and_shared_properties].nil? || params[:owned_and_shared_properties].blank?)
    owned_and_shared_properties_collection = Folder.find(:all, :conditions => ["real_estate_property_id in (?) and parent_id = 0 and is_master = 0",owned_and_shared_properties], :select => "id")
    shared_folder_collab_hub.each do |i|
      find_all_folders_n_subfolders(i)
    end
    owned_and_shared_properties_collection.each do |j|
      find_all_folders_n_subfolders(j)
    end
    events_conditions = "(resource_id IN (#{@all_folders_ids.collect{|x| x.id}.join(',')}) and resource_type = 'Folder')" if !(@all_folders_ids.nil? || @all_folders_ids.blank?)
    events_conditions << " #{check_events_condition(events_conditions)} (resource_id IN (#{shared_folder_collab_hub.join(',')}) and resource_type = 'Folder')" if !(shared_folder_collab_hub.nil? || shared_folder_collab_hub.blank?)
    events_conditions << " #{check_events_condition(events_conditions)} (resource_id IN (#{@all_documents_ids.collect{|x| x.id}.join(',')}) and resource_type = 'Document')" if !(@all_documents_ids.nil? || @all_documents_ids.blank?)
    events_conditions << " #{check_events_condition(events_conditions)} (resource_id IN (#{shared_doc_collab_hub.join(',')}) and resource_type = 'Document')" if !(shared_doc_collab_hub.nil? || shared_doc_collab_hub.blank?)
    events_conditions = ("resource_id in (null)") if events_conditions.blank?

    val = EventResource.find(:all, :conditions => ["#{events_conditions}"], :select=>"event_id")
    #~ if request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?("transaction?deal_room=true")
      #~ val = EventResource.find(:all, :conditions => ["#{events_conditions}"], :select=>"event_id,resource_id,resource_type").select{|x| x.try(:resource).try(:real_estate_property).try(:property_name)=="property_created_by_system_for_deal_room"}
    #~ else
      #~ val = EventResource.find(:all, :conditions => ["#{events_conditions}"], :select=>"event_id,resource_id,resource_type").select{|x| x.try(:resource).try(:real_estate_property).try(:property_name)!="property_created_by_system_for_deal_room"}
    #~ end

    @event_ids = val.collect{|x| x.event_id}
    @events = Event.find(:all, :conditions=>["id IN (?) and action_type in (?)",@event_ids,action_type], :order=>'created_at desc')
    find_events_and_shared_users
  end

  def check_events_condition(str)
    or_flag = !str.empty? ? " or " : " "
  end

  def find_all_folders_n_subfolders(f)
    all_folders_ids,all_documents_ids,all_document_names_ids = find_all_events_of_folder(f,true)
    @all_folders_ids += all_folders_ids
    @all_documents_ids += all_documents_ids
    @all_document_names_ids += all_document_names_ids
  end

  def action_type
  #action_type = ["create","upload","new_version","delete","download","rename","shared","moved","copied","commented","restored","unshared","del_comment","rep_comment","up_comment","create_task","update_task","mapped_secondary_file","create_secondary_file","collaborators","task_commented","task_del_commented","task_up_commented","task_rep_commented","de_collaborators","sharelink"]
  action_type = ["create","upload","new_version","delete","download","rename","shared","moved","copied","commented","restored","unshared","del_comment","rep_comment","up_comment","collaborators","de_collaborators","sharelink"]
  end

  def find_events_and_shared_users
    shared_users = @events.collect{|x| [x.shared_user_id,x.user_id]}.uniq.flatten
    @events = @events.paginate :per_page => @@option_page ,:page=> params[:page]
    @shared_users = User.find(:all, :conditions => ["id in (?)",shared_users], :select=> "email,id")
  end

  def view_events_folder_foe_all_and_filter_events(params,type)
    a = []
    a = params[:folder_id].split(",")
    @events = (type == 'all') ? Event.find(:all, :conditions=>["id IN (?) and action_type in (?)",a,action_type], :order=>'created_at desc') : Event.find(:all, :conditions=>["id IN (?) and (user_id = ? or shared_user_id = ?)  and action_type in (?)",a,params[:shared_user_id],params[:shared_user_id],action_type], :order=>'created_at desc')
    find_events_and_shared_users
  end
end
