class CollaboratorsController < ApplicationController
  before_filter :user_required
  layout 'user',:except=>['view_share','unshare','view_file','add_collaborators','share_link_file','share_link_folder','view_contacts']
  before_filter :find_folder_id, :only=> ['view_share','share_folder','share_file','share_link_file','share_link_folder']
  before_filter :change_session_value, :only=>[:share_folder,:send_exp_mail_to_collaborators]
  #view for folder share
  def view_share
    #~ @folder = Folder.find_folder(params[:folder_id])
    params[:is_lease_agent] == 'true' ?  display_lease_agents :  display_collaborators
  end

  #view for file share
  def view_file
    @document = Document.find(params[:id])
    @folder = @document.folder
    display_collaborators
  end
  #share link file
  def share_link_file
    @document = Document.find(params[:id])
    @folder = @document.folder
    Event.create_new_event("sharelink",current_user.id,nil,[@document],current_user.user_role(current_user.id),@document.filename,nil)
  end

  #share link folder
  def share_link_folder
    @folder = Folder.find(params[:id])
    Event.create_new_event("sharelink",current_user.id,nil,[@folder],current_user.user_role(current_user.id),@folder.name,nil)
    #    display_collaborators
  end


  def share_folder1()
    #~ @folder = Folder.find_folder(params[:folder_id])
    @portfolio = @folder.portfolio
    @property = @folder.real_estate_property #RealEstateProperty.find_by_id(params[:property_id])
    suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
    find_folder_members
    success_flag = false
    unshare   if params[:deleted_users] && params[:deleted_users] != ''
    find_newly_added_collaborators
    @member_emails =@member_emails.reject{|member_email| member_email == ""}
    if @member_emails.empty? && params[:collaborator_list].blank? && params[:deleted_users].blank? && params[:users_form_submit] != 'true'
      if params[:users_form_submit] != 'true'
        close_control_model
      end
    elsif @member_emails.empty? && !params[:collaborator_list].blank? && params[:collaborator_list] != "Enter email addresses here"
      display_add_collaborator_err_msg
    else
      if !@member_emails.empty?
        folder = Folder.find_folder(params[:folder_id])
        email_ids =@member_emails
        email_ids = email_ids.reject{|email_id| current_user.email == email_id}
        share_sub_folders_docs_tasks(email_ids,folder)
        alert_users_for_property(email_ids,@property)
      end
      send_file_folder_update_mail_to_already_added_users(@folder)
      @partial = "/properties/assets_list"
      if(params[:show_past_shared] == "true")
        @folder = Folder.find_folder(@folder.parent_id) if @folder.parent_id !=0 &&  @folder.parent_id != -1
        find_past_shared_folders('false')
        @folder = Folder.find_folder(params[:folder_id])
      else
        if params[:users_form_submit] == 'true'
          (params[:call_from_prop_files] == "true" || params[:is_property_folder] == "true") ? assign_initial_options : assign_options(@folder.id)
        else
          assign_options(@folder.parent_id)
        end
      end
      @innerfolder = Folder.find_folder(@folder.id)
      @folder = Folder.find_folder(@folder.parent_id) if @folder.parent_id != 0 &&  @folder.parent_id != -1
      @folder = Folder.find_by_portfolio_id_and_parent_id(@portfolio.id,-1) if @portfolio && params[:is_property_folder] =="true"
      str_val = params[:is_lease_agent] == 'true' ? 'Leasing Agent(s)' : (check_is_property_user ? 'Property User(s)' : 'Collaborator(s)')
      if params[:is_lease_agent] == 'true'
        #Added condition to remove the Leasing Agent role when the user does not have any shared property#
        if params[:deleted_users].present?
          user_mail = params[:deleted_users].split(",")
          user_mail.each do |user|
            @find_user = User.find_by_email(user)
            find_property = SharedFolder.find(:all,:conditions=>["user_id = #{@find_user.id} and is_property_folder = true"])
            if !find_property.present?
              user_roles = @find_user.role_ids
              user_roles.delete_if {|i| i.eql?(6)}
              @find_user.role_ids = user_roles
              @find_user.save(false)
            end
          end
        end
        #ends here#
        @msg = !params[:deleted_users].blank? ?  "#{str_val} are revoked from #{@innerfolder.name.capitalize} successfully" :  ((params[:collaborator_list] == "Enter email addresses here" && params[:deleted_users].blank?) ? nil : "#{str_val} are successfully added")
      else
        @msg = !params[:deleted_users].blank? ?  "#{str_val} are revoked from #{@innerfolder.name.capitalize} successfully" :  ((params[:collaborator_list] == "Enter email addresses here" && params[:deleted_users].blank?) ? nil : "#{@innerfolder.name.capitalize} collaborated successfully")
      end
      find_folder_to_update_page('folder',@innerfolder) if @folder.user_id != current_user.id
      update_page
    end
  end




















  #share folder
  def share_folder
    #~ @folder = Folder.find_folder(params[:folder_id])
    @portfolio = @folder.portfolio
    @property = @folder.real_estate_property #RealEstateProperty.find_by_id(params[:property_id])
    suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
    find_folder_members
    success_flag = false
    unshare   if params[:deleted_users] && params[:deleted_users] != ''
    find_newly_added_collaborators
    @member_emails =@member_emails.reject{|member_email| member_email == ""}
    if @member_emails.empty? && params[:collaborator_list].blank? && params[:deleted_users].blank? && params[:users_form_submit] != 'true'
      if params[:users_form_submit] != 'true'
        close_control_model
      end
    elsif @member_emails.empty? && !params[:collaborator_list].blank? && params[:collaborator_list] != "Enter email addresses here"
      display_add_collaborator_err_msg
    else
      if !@member_emails.empty?
        folder = Folder.find_folder(params[:folder_id])
        email_ids =@member_emails
        email_ids = email_ids.reject{|email_id| current_user.email == email_id}
        share_sub_folders_docs_tasks(email_ids,folder)
        alert_users_for_property(email_ids,@property)
      end
      send_file_folder_update_mail_to_already_added_users(@folder)
      @partial = "/properties/assets_list"
      if(params[:show_past_shared] == "true")
        @folder = Folder.find_folder(@folder.parent_id) if @folder.parent_id !=0 &&  @folder.parent_id != -1
        find_past_shared_folders('false')
        @folder = Folder.find_folder(params[:folder_id])
      else
        if params[:users_form_submit] == 'true'
          (params[:call_from_prop_files] == "true" || params[:is_property_folder] == "true") ? assign_initial_options : assign_options(@folder.id)
        else
          assign_options(@folder.parent_id)
        end
      end
      @innerfolder = Folder.find_folder(@folder.id)
      @folder = Folder.find_folder(@folder.parent_id) if @folder.parent_id != 0 &&  @folder.parent_id != -1
      @folder = Folder.find_by_portfolio_id_and_parent_id(@portfolio.id,-1) if @portfolio && params[:is_property_folder] =="true"
      str_val = params[:is_lease_agent] == 'true' ? 'Leasing Agent(s)' : (check_is_property_user ? 'Property User(s)' : 'Collaborator(s)')
      if params[:is_lease_agent] == 'true'
        #Added condition to remove the Leasing Agent role when the user does not have any shared property#
        if params[:deleted_users].present?
         user_mail = params[:deleted_users].split(",")
         user_mail.each do |user|
           @find_user = User.find_by_email(user)
           find_property = SharedFolder.find(:all,:conditions=>["user_id = #{@find_user.id} and is_property_folder = true"])
           if !find_property.present?
             user_roles = @find_user.role_ids
             user_roles.delete_if {|i| i.eql?(6)}
             @find_user.role_ids = user_roles
             @find_user.save(false)
           end
          end
        end
        #ends here#
       @msg = !params[:deleted_users].blank? ?  "#{str_val} are revoked from #{@innerfolder.name.capitalize} successfully" :  ((params[:collaborator_list] == "Enter email addresses here" && params[:deleted_users].blank?) ? nil : "#{str_val} are successfully added")
      else
      @msg = !params[:deleted_users].blank? ?  "#{str_val} are revoked from #{@innerfolder.name.capitalize} successfully" :  ((params[:collaborator_list] == "Enter email addresses here" && params[:deleted_users].blank?) ? nil : "#{@innerfolder.name.capitalize} collaborated successfully")
      end
      find_folder_to_update_page('folder',@innerfolder) if @folder.user_id != current_user.id
      update_page
    end
  end













  #share file
  def share_file
    #~ @folder = Folder.find_folder(params[:folder_id])
    @portfolio = Portfolio.find_portfolio(params[:portfolio_id])
    document = Document.find_document(params[:document_id])
    m = find_doc_members
    unshare     if params[:deleted_users] && params[:deleted_users] != ''
    emails = @members.collect{|member| member.email}
    @member_emails =[]
    params[:already_added_users] = params[:already_added_users].split(",").compact.collect{|v| v.strip}.delete_if{|v| v.eql?("")}.uniq - params[:deleted_users].split(",").compact.collect{|v| v.strip}.delete_if{|v| v.eql?("")}.uniq
    owner = find_doc_owner(params[:id])
    params[:already_added_users].each do |m|
      @member_emails << m.strip  if !emails.include?(m.strip) && m.strip != owner && !m.strip.blank?
    end
    @member_emails = @member_emails.reject { |email| email== "" }
    if !params[:collaborator_list].blank?
      display_add_collaborator_err_msg
    elsif !@member_emails.empty?
      email_ids = @member_emails
      email_ids = email_ids.reject{|email_id| current_user.email == email_id}
      share_document(email_ids,document)
      @partial = "/properties/assets_list"
      find_folders_collection_based_on_params
      @msg = document.filename + " " + FLASH_MESSAGES['collaborators']['6001']
      find_folder_to_update_page('document',@folder) if @folder.user_id != current_user.id
      update_page
      send_file_folder_update_mail_to_already_added_users(document)
    else
      send_file_folder_update_mail_to_already_added_users(document)
      if !params[:deleted_users].blank?
        document = Document.find_document(params[:document_id])
        @msg = document.filename + " " + FLASH_MESSAGES['collaborators']['6002']
        find_folders_collection_based_on_params
        find_folder_to_update_page('document',@folder) if @folder.user_id != current_user.id
        update_page
      else
        close_control_model
      end
    end
  end

  #revoke folder,document
  def unshare
    params[:folder_revoke] ? find_folder_members : (params[:revoke_fn] ?  find_file_name_members : find_doc_members)
    @folder = Folder.find_folder(params[:folder_id])
    @portfolio = @folder.portfolio
    deleted_users = params[:deleted_users].split(',')
    deleted_users.each do |u|
      delete_user = User.find_by_email(u.strip)
      if  delete_user
        unshare_document(delete_user) if(delete_user && !params[:folder_revoke] && !params[:revoke_fn])
        unshare_folder(delete_user) if (delete_user && params[:folder_revoke])
      end
    end
  end

  #revoke document
  def unshare_document(delete_user)
    document = Document.find_document(params[:id])
    document.unshare_document(delete_user,params,current_user)
  end

  #revoke folder
  def unshare_folder(delete_user)
    revoke_folder =   SharedFolder.find_by_folder_id(params[:folder_id],:conditions=>["user_id = ? and client_id =?" ,delete_user.id,delete_user.client_id])
    if revoke_folder
    params[:mem_id] = delete_user.id
    @sub_sharers=[]
    @sub1 = []
    @sub =[]
    r_user = User.find_by_id(delete_user.id)
    UserMailer.delay.folder_file_user_revoke_notification(@folder,current_user,r_user)  if r_user
    recursive_delete_function(revoke_folder.folder.id)
    @sub_sharers.each do |sub_sharer|
      s2=   SharedFolder.find_by_folder_id(sub_sharer.folder_id,:conditions=>["sharer_id = ?" ,sub_sharer.sharer_id]) if sub_sharer.folder.user_id ==  sub_sharer.user_id
      sub_sharer.destroy
      s2.destroy if s2 != nil
      recursive_delete_function(@folder.id)
    end
    folder = Folder.find_folder(params[:folder_id])
    Event.create_new_event("unshared",current_user.id,delete_user.id,[revoke_folder.folder],current_user.user_role(current_user.id),folder.name,nil)
    revoke_folder.destroy
   end
  end



  #additional add method #vasu

  def add_collaborators_with_profile1(mail_id)

    puts("**************************")
    puts("**************************")
    puts("add_collaborators_with_profile1")
    puts(mail_id)
    puts("**************************")
    puts("**************************")

    @member_emails = users = mail_id.split( /, */ ).each{|x| x.strip! }
    @tmp_mem_list = ''
    @m = []
    arr=[]
    f= "false"
    for user in users.uniq
      user_details = find_user_details(user.strip)
      u_email , u_id , u_name = user_details.email , user_details.id , user_details.name
      if u_email != current_user.email
       # @tmp_mem_list = @tmp_mem_list + "<div class=\"add_users_collaboratercol\"  id=\"#{user.to_s}\"><div class=\"add_users_imgcol\"><img width=\"30\" height=\"36\" src=\"#{display_image_for_user_add_collab(u_id)}\"/></div><div class=\"collaboraterow\"><a title=\"Unshare this file\" href=\"#\" onclick=\"if (confirm(\\'Are you sure you want to remove this user ?\\')){delete_collaborator_users(\\'#{u_email}\\',\\'#{u_id}\\');} return false\"><img border=0 width=7 height=7 src=\"/images/del_icon.png\"  title=\"#{remove_collaborator_tooltip}\" /></a><div class=\"collaboratername\">#{(!u_name.nil? and !u_name.blank?) ?  "#{lengthy_word_simplification(u_name,7,5)}" : user.split('@')[0]}  </div><div class=\"collaborateremail\">#{user}</div> </div></div>"
        f = "true"
      end
    end
   # render :action => 'add_collaborators_with_profile.rjs'

  end






























  #display collaborators list in lightbox - while clicking add
  def add_collaborators_with_profile

    @member_emails = users = params[:collaborator_list].split( /, */ ).each{|x| x.strip! }
    @tmp_mem_list = ''
    @m = []
    arr=[]
    f= "false"
    for user in users.uniq
      user_details = find_user_details(user.strip)
      u_email , u_id , u_name = user_details.email , user_details.id , user_details.name
      if u_email != current_user.email
        @tmp_mem_list = @tmp_mem_list + "<div class=\"add_users_collaboratercol\"  id=\"#{user.to_s}\"><div class=\"add_users_imgcol\"><img width=\"30\" height=\"36\" src=\"#{display_image_for_user_add_collab(u_id)}\"/></div><div class=\"collaboraterow\"><a title=\"Unshare this file\" href=\"#\" onclick=\"if (confirm(\\'Are you sure you want to remove this user ?\\')){delete_collaborator_users(\\'#{u_email}\\',\\'#{u_id}\\');} return false\"><img border=0 width=7 height=7 src=\"/images/del_icon.png\"  title=\"#{remove_collaborator_tooltip}\" /></a><div class=\"collaboratername\">#{(!u_name.nil? and !u_name.blank?) ?  "#{lengthy_word_simplification(u_name,7,5)}" : user.split('@')[0]}  </div><div class=\"collaborateremail\">#{user}</div> </div></div>"
        f = "true"
      end
    end
    render :action => 'add_collaborators_with_profile.rjs'

  end

  #updates partials
  def update_page
    if(params[:add_contacts] == "true") || (params[:from_dash_board] == 'true') || (params[:is_lease_agent] == 'true')
      @folder,@lease_agents = RealEstateProperty.find_lease_agents(@property.id,current_user.id) if params[:is_lease_agent] == 'true'
      responds_to_parent do
        render :update do |page|
          page.call 'close_control_model'
          page.replace_html "lease_agents",:partial=>"/lease/lease_agents_display" if params[:is_lease_agent] == 'true'
          page.replace_html "add_new_contact",:partial=>"/users/add_new_contact" if params[:from_dash_board] == 'true'
          page.call "flash_writter", "#{@msg}"
        end
      end
    else
      if request.xhr?
        render :update do |page|
          if(params[:action] == "share_folder"  || params[:action] == "unshare" || params[:action] =="share_file" || params[:action] == "share_filename" || (params[:list] == "shared_list" && params[:is_missing_file]=="true"))
            page.hide 'modal_container'
            page.hide 'modal_overlay'
          end
          if @folder.parent_id == -1 && !@folder.is_master
            show_portfolios
          end
          @partial = @folder.parent_id == -1 && !@folder.is_master ? 'collaboration_hub/collaboration_overview' : @partial
          page.replace_html "show_assets_list",:partial=>"#{@partial}"
          page.call "flash_writter", "#{@msg}"
        end
      elsif params[:action] == "share_folder" || params[:action] =="share_file"
        responds_to_parent do
          render :action => 'update_page_without_request.rjs'
        end
      end
    end
  end

  #view for task collaborators
  def add_collaborators
    if !params[:document_id].blank?
      @document = Document.find_by_id(params[:document_id])
    end
    if !params[:folder_id].blank?
      @folder = Folder.find_by_id(params[:folder_id])
    end
    unless params[:document_id].nil? && params[:document_id].blank?
      params[:id] = params[:document_id]
      find_doc_members
    end
    @data =''
    f = "false"
    if params[:collaborators_list] and !params[:collaborators_list].blank?
      for user in params[:collaborators_list].split(',')
        if user != ''
          user_details = find_user_details(user.strip)
          u_email , u_id , u_name = user_details.email , user_details.id , user_details.name
          if u_email != current_user.email
            @mem_list = @mem_list.to_s + u_email.to_s + ","
            cross_image = ""
            @data = @data + "<div class='add_users_collaboratercol'  id='#{user}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(u_id)}'/></div><div class='collaboraterow'> #{cross_image}<div class='collaboratername'><span title='#{(!u_name.nil? and !u_name.blank?) ?  u_name : user.split('@')[0]}'>#{(!u_name.nil? and !u_name.blank?) ?  lengthy_word_simplification(u_name,7,5) : lengthy_word_simplification(user.split('@')[0],7,5)}</span>
                        </div><div class='collaborateremail'>#{user}</div> </div></div>"
            f = "true"
          end
        end
      end
    end
    render :layout => false
  end

  #displayed while adding collaborators in  new task
  def add_collaborator_to_add_task
    users_to_add = params[:already_added_users].split(",") - params[:deleted_users].split(",")
    if !params[:collaborator_list].blank?
      display_add_collaborator_err_msg
    else
      coll_list,list = form_collaborators_list
      for user in coll_list.split(",").compact
        if user != ""
          user_details = find_user_details(user.strip)
          list=list+"<div class='commentcoll1'><div class='commentimagecol'><img width='36' height='42' src='#{display_image_for_user_add_collab(user_details.id)}'></div><div class='commentbox'><a href='#'> </a></div> <div class='namecol'>#{find_collaborator_name_to_display(user_details)}</div></div>"
        end
      end
      list = list + "<input type='hidden' name='add_coll_list' value='#{coll_list}' id='add_coll_list'/>"
      m1 = (!params[:document_id].nil? and !params[:document_id].blank?) ? "document_id=#{params[:document_id]}&" : ""
      replace_collaborators_list(m1,list,coll_list)
    end
  end


  #to find newly added collaborators
  def  find_newly_added_collaborators
    emails = find_folder_members.collect{|m| m.email}
    @member_emails =[]
    params[:already_added_users] = params[:already_added_users].split(",").uniq - params[:deleted_users].split(",").uniq
    owner=find_folder_owner(params[:folder_id])
    params[:already_added_users].each do |m|
      @member_emails << m.strip  if !emails.include?(m.strip) && m.strip != owner
    end
  end

  #to share_folders_while_sharing_main_folder
  def share_sub_folders_while_sharing_folder(su)
    @subfolders.each do |f|
      if f.parent_id != 0 && !f.is_deleted
        if f.user_id == current_user.id || (is_parent_folder_of_folder_shared(f) != nil)
          sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(f.id,su.id,User.current,@folder.real_estate_property_id)
          sf.update_attributes(:sharer_id=>current_user.id)
        end
      end
    end
  end

  #to share_docs_while_sharing_main_folder
  def share_sub_docs_while_sharing_folder(su)
    @subdocs.each do |d|
      if d.filename != "Cash_Flow_Template.xls" && d.filename != "Rent_Roll_Template.xls"
        if !d.is_deleted && (d.user_id == current_user.id || (is_folder_of_doc_shared(d) != nil))
          sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id(d.id,su.id,User.current,@folder.real_estate_property_id)
          sd.update_attributes(:folder_id=>d.folder_id,:sharer_id=>current_user.id)
        end
      end
    end
  end

  #to share_docs_folders_tasks_while_sharing_main_folder
  def share_sub_folders_docs_tasks(email_ids,folder)
    folder_id = folder.id
    email_ids.each do |e|
      su,su_already = User.create_new_user(e,params,current_user.id)
      su.selected_role = su.user_role(su.id)
      su.save(false)
      #@user = User.find(params[:user_id]) if params[:user_id]
      @user = current_user
      @is_property_sharing = (folder.parent_id.eql?(0) || params[:from_prop_setting] == 'true' || params[:call_from_prop_files] == 'true' || params[:is_property_folder] == 'true' || params[:edit_inside_asset] == 'true' || params[:from_debt_summary] == 'true' || params[:from_property_details] == 'true') ? true : false
      @subfolders,@subdocs,@sub_docnames = Folder.subfolders_docs(folder_id,true,@is_property_sharing,params)
      parent = SharedFolder.find_by_folder_id_and_user_id(folder.parent_id,su.id) if !(folder.parent_id == 0)
      share_sub_folders_while_sharing_folder(su)
      share_sub_docs_while_sharing_folder(su) #unless @is_property_sharing
      is_prop_folder =(folder.parent_id.eql?(0) || params[:from_prop_setting] == 'true' || params[:call_from_prop_files] == 'true' || params[:is_property_folder] == 'true' || params[:edit_inside_asset] == 'true' || params[:from_debt_summary] == 'true' || params[:from_property_details] == 'true') ? 'true' : 'false'
      current_folder = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_is_property_folder(folder_id,su.id,User.current,@folder.real_estate_property_id,is_prop_folder)
      current_folder.update_attributes(:sharer_id=>current_user.id,:comments=>params[:textarea])
      params[:is_property_folder] ? UserMailer.share_notification_for_prop(su,current_folder,'folder',current_user,su_already).deliver :  (params[:deal_room] == 'true' ? UserMailer.share_notification_for_deal(su,current_folder,'folder',current_user,su_already).deliver : UserMailer.delay.share_notification(su,current_folder,'folder',current_user,su_already))
      Event.create_new_event("shared",@user.id,su.id,[current_folder.folder],@user.user_role(@user.id),@folder.name,nil)
    end
  end

  #to share document
  def share_document(email_ids,document)
    email_ids.each do |e|
      su,su_already = User.create_new_user(e,params,current_user.id)
      sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id(document.id,su.id,User.current,@folder.real_estate_property_id)
      sd.update_attributes(:folder_id=>document.folder_id,:sharer_id=>current_user.id,:comments=>params[:textarea])
      if params[:deal_room] == 'true'
        UserMailer.delay.share_notification_for_deal(su,sd,'file',current_user,su_already) rescue ''
      else
        UserMailer.delay.share_notification(su,sd,'file',current_user,su_already) rescue ''
      end
      @user = User.find(params[:user_id])
      Event.create_new_event("shared",@user.id,su.id,[sd.document],@user.user_role(@user.id),document.filename,nil)
    end
  end

  def swig_remove_from_already_existing_users
    msg = remove_already_existing_emails(@wres_users, '6003')
    render :update do |page|
      page.call "remove_from_already_existing_users", "#{params[:collaborator_list]}"
      page.call "flash_writter", "#{msg}"
    end
  end

  def wres_remove_from_already_existing_users
    msg = remove_already_existing_emails(@swig_users, '6004')
    render :update do |page|
      page.call "remove_from_already_existing_users", "#{params[:collaborator_list]}"
      page.call "flash_writter", "#{msg}"
    end
  end

  def replace_collaborators_list(m1,list,coll_list)
    responds_to_parent do
      render :update do |page|
        page.call 'close_control_model'
        page.call 'load_completer'
        page.replace_html 'collbartor_list_display',  raw(list)
        page.replace_html 'add_collaborators_link',raw("<a id='add_collaborators1' href='/collaborators/add_collaborators?#{m1}folder_id=#{params[:folder_id]}&collaborators_list=#{coll_list}&from_task_add_collab=true&from_assign_task=#{params[:from_assign_task]}'><img border='0' width='18' height='17' src='/images/add_collabaraters_icon.png'>Add / Edit Collaborators</a><span>&nbsp;</span> <script> new Control.Modal($('add_collaborators1'), {beforeOpen: function(){load_writter();},afterOpen: function(){load_completer();},className:'modal_container', method:'get'});</script>")
        page.replace_html 'notification_alert' ,raw("<input type='hidden' value='#{params[:notification_alert]}' name='notification_alert' id='notification_alert' />")
        page.replace_html 'text_area_message' ,raw("<input type='hidden' value='#{params[:textarea]}' name='textarea' id='textarea' />")
        page.call "findCollaboratorsInTasks"
      end
    end
  end

  def form_collaborators_list
    list =''
    coll_list = params[:already_added_users].split(",").collect{|value| value.strip}.uniq.compact.delete_if{|value| value.empty?}.join(",")
    coll_list = (coll_list.split(",") - params[:deleted_users].split(",").collect{|value| value.strip}.uniq.compact.delete_if{|value| value.empty?}).join(",")  if params[:deleted_users] and !params[:deleted_users].blank?
    return coll_list,list
  end

  def find_folder_id
    @folder = Folder.find_folder(params[:folder_id])
  end

  def view_contacts
    find_contact_details
  end

  def add_contacts
  end

  def change_session_value
		 if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
		  session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present?) || (params[:real_estate_id].present? && params[:id].present?) )
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id] || params[:id] || params[:nid]
		elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
		  session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
		else
			session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
    end
  end


  def send_exp_mail_to_collaborators
    @property =RealEstateProperty.find_real_estate_property(params[:property_id])
    property = @property
    @portfolio = Portfolio.find_by_id(params[:portfolio_id])
    @folder = find_property_folder_by_property_id(property.id) if property
    property.save_and_send_exp_mail_to_collabrators(params,property) if property
    update_pages
  end

  def check_property_access

    id = params[:id].present? ? params[:id] : params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      @property_ids = properties.present? ? properties.map(&:id) : []
      unless @property_ids.include?(id.to_i)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end
    end
  end

end
