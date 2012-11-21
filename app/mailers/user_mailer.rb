class UserMailer < ActionMailer::Base
  #default :from => "from@example.com"
  #~ layout "email"
  def set_your_password(user,user_type)
    @user = user
    @name=user.name
    @subject = "Login details for"+" "+"'#{@subject} Asset Management Platform'"
    @url = user.password_code? ? "#{APP_CONFIG[:site_url]}/#{user_type}/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/login"
    mail(:from=>"AMP Alert <#{APP_CONFIG[:noreply_email]}>", :to=>user.email, :subject=>"Login details for 'AMP: Asset Management Platform'")
    @sent_on     = Time.now
  end

  def server_db_setting(client_admin,db_setting,acc_sys_name,server_name,server_email,roles_users)
    if roles_users == "Client Admin"
    #~ @recipients  = "#{APP_CONFIG[:admin_email]}"
    @from  = server_email
    else
    @recipients  = client_admin.email  #,"#{APP_CONFIG[:admin_email]}"
    @from  = server_email
    end
    @subject= "DB URL Settings"
    @server_url = db_setting.server_url
    @prop = db_setting.property_select
    if @prop == true
      @prop_name = "All Properties"
    elsif @prop == false
      @prop_name = "Selected Properties"
    @prop_code = db_setting.add_property
    end
    @acc_sys_name = acc_sys_name
    @server_name = server_name
    @sent_on     = Time.now
  end

  def share_notification(user,shared_obj,share_type,current_user,su_already)
    @recipients  = "#{user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    shared_obj_name = share_type == 'file' ? shared_obj.document.filename : shared_obj.folder.name
    sharer_name_email = name_or_email(current_user)
    @subject = "AMP: #{sharer_name_email} #{current_user.company_name? ? 'from '+current_user.company_name : ''} has shared a #{share_type} '#{shared_obj_name}' with you."
    url = user.password_code? ? "#{APP_CONFIG[:site_url]}/shared_users/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/collaboration_hub?open_folder=#{shared_obj.folder.id}&pid=#{shared_obj.folder.portfolio_id}"
    if user.password_code?
      @first_line = "You are invited to <a href='#{url}'><font color='#2a8ae4'>Join Amp</font></a> to view the file <a href='#{url}'><font color='#2a8ae4'>'#{shared_obj_name}'</font></a> shared by #{sharer_name_email}"
    else
      @first_line = "<b>#{sharer_name_email}</b> #{current_user.company_name? ? 'from '+current_user.company_name : ''} has shared a #{share_type} '#{shared_obj_name}' with you"
    end
    insert_folder_text = share_type == 'folder' ? "files within the folder" : share_type
    @second_line = "Click on the link <a href='#{url}'><font color='#2a8ae4'>#{shared_obj_name}</font></a> to update or download #{insert_folder_text}."
    @comment= shared_obj.comments
    @coll_name_or_mail = name_or_email(user)
    @shared_obj_name = shared_obj_name
    @shared_obj_type= share_type
    @sent_on     = Time.now
  end

  def share_notification_for_deal(user,shared_obj,share_type,current_user,su_already)
    @recipients  = "#{user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    shared_obj_name = share_type == 'file' ? shared_obj.document.filename : shared_obj.folder.name
    sharer_name_email = name_or_email(current_user)
    @subject = "AMP: #{sharer_name_email} #{current_user.company_name? ? 'from '+current_user.company_name : ''} has shared a #{share_type} '#{shared_obj_name}' with you."
    url = user.password_code? ? "#{APP_CONFIG[:site_url]}/shared_users/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/transaction?deal_room=true"
    if user.password_code?
      @first_line = "You are invited to <a href='#{url}'><font color='#2a8ae4'>Join Amp</font></a> to view the file <a href='#{url}'><font color='#2a8ae4'>'#{shared_obj_name}'</font></a> shared by #{sharer_name_email}"
    else
      @first_line = "<b>#{sharer_name_email}</b> #{current_user.company_name? ? 'from '+current_user.company_name : ''} has shared a #{share_type} '#{shared_obj_name}' with you"
    end
    insert_folder_text = share_type == 'folder' ? "files within the folder" : share_type
    @second_line = "Click on the link <a href='#{url}'><font color='#2a8ae4'>#{shared_obj_name}</font></a> to update or download #{insert_folder_text}."
    @comment= shared_obj.comments
    @coll_name_or_mail = name_or_email(user)
    @shared_obj_name = shared_obj_name
    @shared_obj_type= share_type
    @sent_on     = Time.now
  end

  def share_notification_for_prop(shared_user,shared_obj,sh,current_user,alrdy)
    @recipients  = "#{shared_user.email}"
    @from = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @sharer_name_email = name_or_email(current_user)
    @property_name = shared_obj.folder.name
    @property_id = shared_obj.folder.real_estate_property_id if shared_obj && shared_obj.folder
    @comment=shared_obj.comments if shared_obj
    @subject = "#{current_user.nil? ? 'Your friend/colleague' : @sharer_name_email} #{current_user.company_name.blank? ? '' : 'from ' + current_user.company_name} has shared a Property '#{@property_name}' with you"
    #~ @url =  shared_user.password_code? ? "#{APP_CONFIG[:site_url]}/shared_users/set_password/#{shared_user.id}/#{shared_user.password_code}" : "#{APP_CONFIG[:site_url]}/collaboration_hub?open_folder=#{shared_obj.folder.id}&pid=#{shared_obj.folder.portfolio_id}&folder_type=property"
    @url =  shared_user.password_code? ? "#{APP_CONFIG[:site_url]}/shared_users/set_password/#{shared_user.id}/#{shared_user.password_code}" : "#{APP_CONFIG[:site_url]}/dashboard/#{shared_obj.folder.portfolio_id}/financial_info/#{@property_id}/financial_info"
    @user = shared_user
    @sent_on     = Time.now
  end

  def account_detail_changed(user,username,email)
    setup_email(user)
    @subject    += 'Your account detail is changed!'
    @user=user
    @username=username
    @email=email
    @url = user.password_code? ? "#{APP_CONFIG[:site_url]}/users/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/login"
  end

  def contact_us(contact)
    @recipients  = contact.email
    @bcc = ["dhanuja@theamp.com", "adi@theamp.com"]
    @from        = "adi@theamp.com"
    @subject= "Getting Started with the AMP Real Estate Platform"
    @name=contact.name
    @email=contact.email
    @comment=contact.comment
    @sent_on     = Time.now
  end

  def comments_notification(comment, detail, user, sender, fl_name,par)
    @recipients  = "#{user.email}"
    @from        = "#{sender.email}"
    @subject     = "AMP: comments "
    @comment= comment
    @detail  = detail
    @user_name_or_email = name_or_email(user)
    @commented_user_name_or_email = name_or_email(sender)
    @fl_name     = fl_name
    @url= "#{APP_CONFIG[:site_url]}/collaboration_hub?mailer=true&id=#{par[:id]}&type=#{par[:type]}"
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
  end

  #~ def c(comment_lines, user, sender, fl_name)
  #~ @recipients  = "#{user}"
  #~ @from        = "#{sender}"
  #~ @subject     = "AMP: Explanation Comments"
  #~ @sent_on     = Time.now.strftime("%a %b %d %T %Y")
  #~ @comment_lines   = comment_lines
  #~ @fl_name     = fl_name
  #~ end

  def send_mail_to_admin(user,comment,software)
    @recipients  = "#{APP_CONFIG[:admin_email]}"
    @from        = "#{user}"
    @subject     = "AMP: Tool details"
    @user = user
    @comment= comment
    @software = software
    @sent_on     = Time.now
  end

  def folder_file_user_revoke_notification(obj,user,shared_user)
    @recipients  = "#{shared_user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    file_or_fol_name = obj.class.name == "Document" ? obj.filename : obj.name
    file_or_fol_obj = obj.class.name == "Document" ? 'file' : obj.class.name == "Folder" && obj.parent_id == 0 ? 'property' : 'folder'
    action_process = ((file_or_fol_obj=='property') ? (shared_user.has_role?('Leasing Agent') ? 'Leasing Agent level' : 'Property level') : "collaboration")
    @subject     = "AMP: #{!user.name? ? user.email : user.name} has removed the #{action_process} access for you from the #{file_or_fol_obj} '#{file_or_fol_name}'"
    @first_line = "<b> #{!user.name? ? user.email : user.name}</b> has removed the #{action_process} access for you from the #{file_or_fol_obj} '#{file_or_fol_name}'"
    @collaborator = shared_user
    @body[:url] =  "#{APP_CONFIG[:site_url]}/collaboration_hub"
    @sharer_name_email = user.name? ? user.name : user.email
    @sent_on     = Time.now
  end

  def due_date_reminder(task,user)
    @recipients  = "#{user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    if task.document_id?
      @subject    = "AMP: Task on File:#{task.document.filename} due on #{task.due_by.strftime("%dth %b, %Y")}"
      @first_line = "'#{task.task_type.task_name}' task on file '#{task.document.filename}' is due on #{task.due_by.strftime("%dth %b, %Y")}."
    else
      @subject    = "AMP: Task on Folder:#{task.folder.name} due on #{task.due_by.strftime("%dth %b, %Y")}"
      @first_line = "'#{task.task_type.task_name}' task on folder '#{task.folder.name}' is due on #{task.due_by.strftime("%dth %b, %Y")}."
    end
    @subject = task.subject.blank? ? @subject : task.subject
    @name_or_email = user.name? ? user.name.capitalize : user.email
    @sent_on     = Time.now
    @url = "#{APP_CONFIG[:site_url]}#{ link_definer(user, task) }"
  end

  def file_or_folder_update_mail(obj,user,msg,current_user,comment)
    name = obj.class.name == "Folder" ? obj.name : obj.filename
    @recipients  = "#{user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject    = "AMP: '#{name}' has been updated by #{current_user.email}"
    @first_line = "'#{name}' has been updated by #{current_user.email}."
    @msg = msg
    @collaborator = user
    @comment = "Comment: #{comment}" unless comment.empty?
    @sent_on     = Time.now
  end

  def send_collab_folder_updates(action_done, current_user, shared_user,file_name, folder_name,type,object,task=nil)
    @recipients  = "#{shared_user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    sharer_name_or_email = current_user.name? ? current_user.name.capitalize : current_user.email
    @subject    = "AMP: '#{file_name}' has been #{action_done} by #{sharer_name_or_email}"
    @sharer_name_or_email = sharer_name_or_email
    @shared_user_name_or_email = shared_user.name.blank? ? shared_user.email : shared_user.name.capitalize
    @action_done = action_done
    @filename = file_name
    @type=type
    @foldername = folder_name
    @time_update= Time.now.strftime("%I:%M %p on %b %d, %Y")
    time_update = Time.now.strftime("%I:%M %p on %b %d, %Y")
    if type == 'folder'
      @first_line = "#{action_done} a folder '#{folder_name}' on #{time_update}."
    elsif type == 'property'
      @first_line = "#{action_done} a property '#{folder_name}' on #{time_update}."
    else
      @first_line = "#{action_done} a file '#{file_name}' on #{time_update}."
    end
    @file_path = if type == 'property'
      object.portfolio.try(:name)
    else
      get_object_path(object)
    end
    @sent_on     = Time.now
  end

  def modify_variance_threshold(shared_asset_manager,threshold, property_id)
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject     = "AMP: The variance threshold value for '#{threshold.real_estate_property.property_name}' has been updated"
    @sent_on     = Time.now
    @recipients  = "#{shared_asset_manager.email}"
    @name = shared_asset_manager.name? ? shared_asset_manager.name : shared_asset_manager.email
    @threshold = threshold
    @updater_name = threshold.user.name? ? threshold.user.name : threshold.user.email
    @prop = "#{threshold.real_estate_property.property_name}"
    @url = "#{APP_CONFIG[:site_url]}/collaboration_hub/index/#{property_id}?open_portfolio=true"
  end

  def name_or_email(user)
    user.name? ? user.name.capitalize : user.email
  end

  def get_object_path(object)
    if object.class == Document
      path  = Folder.find_mail_path_folder(object.folder)
      object.folder.portfolio.name == "portfolio_created_by_system" ? path : "#{object.folder.portfolio.name} > "+path
    elsif object.class == Folder
      path = Folder.find_mail_path_folder(object)
      object.portfolio.name == "portfolio_created_by_system" ? path : "#{object.portfolio.name} > "+path
    end
  end

  def summary_comments_notification(comment, detail, user, sender, fl_name,portfolio_id,property_id)
    portfolio = Portfolio.find_by_id(portfolio_id)
    @recipients  = "#{user.email}"
    @from        = "#{sender.email}"
    @subject     = "AMP: comments "
    @comment = comment
    @detail  = detail
    @user_name_or_email = name_or_email(user)
    @commented_user_name_or_email = name_or_email(sender)
    @fl_name     = fl_name
    @url = "#{APP_CONFIG[:site_url]}/collaboration_hub/index/#{portfolio_id}?open_portfolio=true"
    @view_comment_url = "#{APP_CONFIG[:site_url]}/real_estate/#{portfolio_id}/properties/#{property_id}"
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
    @portfolio_name = portfolio.name
  end

  def rename_notification(user,collaborator,old_name,new_name,object,type)
    @recipients  = collaborator.email
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject = "AMP: #{type} '#{old_name}' renamed as '#{new_name}' by #{name_or_email(user)}"
    @message = "#{type} '#{old_name}' renamed as '#{new_name}' by #{name_or_email(user)} on #{Time.now.strftime("%I:%M %p on %b %d, %Y")}"
    @collaborator = name_or_email(collaborator)
    @path = get_object_path(object)
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
  end

  def variances_display_mail(user_mail,message,sender,user_name,portfolio_id,property_id)
    @recipients = user_mail
    @from        = "#{sender.email}"
    @subject = "AMP: Message from #{name_or_email(sender)}"
    @content = "AMP: Message from #{name_or_email(sender)}"
    @message = message
    @prop_user_name = user_name
    property = RealEstateProperty.find(property_id) if property_id
    @property_name = property.property_name if property
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
    @url = "#{APP_CONFIG[:site_url]}/real_estate/#{portfolio_id}/properties/#{property_id}?variances=true"
  end

  def variance_explain_request_mail(user_data,updated_user,property,updated_month,updated_year)
    @recipients = user_data.email
    @from        = "#{updated_user.email}"
    @subject = "AMP: Message from #{name_or_email(updated_user)}"
    @content = "AMP: Message from #{name_or_email(updated_user)}"
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
    @url = "#{APP_CONFIG[:site_url]}/real_estate/#{property.portfolio_id}/properties/#{property.id}?variances=true"
    @updated_month = updated_month
    @updated_year= updated_year
    @user_name= name_or_email(user_data)
    @message = "#{property.property_name}'s actual financials for #{updated_month} #{updated_year}, has been updated."
  end

  def property_details_imported_notification(current_user,property_name,property_code,portfolio_id,property_id)
    @property_name =property_name
    @recipients  = current_user.email
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject = "AMP: Property data retrieved"
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
    @url = "#{APP_CONFIG[:site_url]}/real_estate/#{portfolio_id}/properties/#{property_id}?variances=true"
    @prop_user_name = (current_user.login.nil? || current_user.login.blank?) ? current_user.email : current_user.login
    @message = "Property Details of #{property_name} - #{property_code} has been retrieved"
  end

  def clientadmin_setting(acc_sys_types,user)
    @user = user
    @name=user.name
    @subject = "Client Admin Details for Asset Management Platform'"
    @acc_sys_type = acc_sys_types
    @email = user.email
    @company_name = user.company_name
    @url = user.password_code? ? "#{APP_CONFIG[:site_url]}/users/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/login"
    mail(:from=>"AMP Alert <#{APP_CONFIG[:noreply_email]}>", :to=>user.email, :subject=>"Client Admin Details for'AMP: Asset Management Platform'")
    @sent_on     = Time.now

  end

  def send_alert_to_property_users(user,prop_name,note)
    @name = name_or_email(user)
    @recipients = user.email
    @subject = "Property Alerts for #{prop_name}"
    @from  = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @url ="#{APP_CONFIG[:site_url]}/login"
    #~ @lease_find = find_lease
    #~ @option_find = find_option
    #~ @find_insr = find_ins
    #~ @tmp_find =find_tmp
    @note =note
    @prop_name = prop_name
    @sent_on  = Time.now
  end

  def notify_admin(recipient, sender)
    @recipients  = "#{recipient.email}"
    @from        = "#{sender.email}"
    @subject     = "AMP: Permission to allow access "
    @user = sender
    @sent_on     = Time.now.strftime("%b %e, %Y at %I:%M %p")
  end

  def send_mail_to_property_users_after_create_or_update_executive_summary(property_user,exec_summary,variable)
    @last_updated_user = User.find_by_id(exec_summary.try(:user_id))
    @recipients  = property_user.try(:email)
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject= "AMP: Executive Summary"
    @exec_summary    =   exec_summary
    @property_user    =   property_user
    @create_or_update = variable
  #~ @sent_on     = Time.now #.strftime("%b %e, %Y at %I:%M %p")
  end

  def send_mail_to_property_users_after_create_or_update_comments_on_exec_summary(property_user,exec_summary,comment,variable)
    @last_updated_user = User.find_by_id(comment.try(:user_id))
    @recipients  = property_user.try(:email)
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject= "AMP: Executive Summary - Comments"
    @property_user    =   property_user
    @exec_summary    =   exec_summary
    @comment    =   comment
    @create_or_update_comments = variable
  #~ @sent_on     = Time.now #.strftime("%b %e, %Y at %I:%M %p")
  end

  #property/portfolio access thru client admin
  def property_and_portfolio_access_client(user,property_and_portfolio_access,type)
    @type = type
    @user = user
    @name=user.name
    @property_and_portfolio_access=property_and_portfolio_access
    @subject = "#{user.company_name} has shared a property/portfolio with you."
    @url = user.password_code? ? "#{APP_CONFIG[:site_url]}/users/set_password/#{user.id}/#{user.password_code}" : "#{APP_CONFIG[:site_url]}/login"
    mail(:from=>"AMP Alert <#{APP_CONFIG[:noreply_email]}>", :to=>user.email, :subject=>@subject)
    @sent_on     = Time.now
  end

  protected

  def setup_email(user)
    @recipients  = "#{user.email}"
    @from        = "AMP Alert <#{APP_CONFIG[:noreply_email]}>"
    @subject     = "AMP:  "
    @sent_on     = Time.now
    @user = user
  end
end
