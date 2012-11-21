module CollaboratorsHelper

  def find_folder_members
    if params[:is_lease_agent] == 'true'
       SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",params[:folder_id],current_user.id]).collect{|sf| p sf.user.roles.inspect}.compact
      @members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",params[:folder_id],current_user.id]).collect{|sf| sf.user if sf.user.has_role?("Leasing Agent")}.compact
     else
      @members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",params[:folder_id],current_user.id]).collect{|sf| sf.user }.compact
    end
    if(params[:note_add_edit] == 'true' || params[:highlight_users_form] == 'true') && @folder
          if params[:is_lease_agent] == 'true'
           @members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",@folder.id,current_user.id]).collect{|sf| sf.user if sf.user.has_role?("Leasing Agent")}.compact
         else
          @members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",@folder.id,current_user.id]).collect{|sf| sf.user if !sf.user.has_role?("Leasing Agent")}.compact
         end
        params[:folder_revoke] = 'true'
        params[:folder_id] =  @folder.id
      end
    return @members
  end

  def find_folder_owner(folder_id)
    return Folder.find(folder_id).user.email if Folder.find(folder_id) && Folder.find(folder_id).user
  end

    def display_add_collaborator_err_msg
    responds_to_parent do
      render :update do |page|
        #page.replace_html "errmsg", :text=>"&nbsp;&nbsp;Please click add button to add the collaborator"
        page.call "flash_writter", "Please click add button to add the collaborator"
        if check_is_property_user
          page.assign "form_txt",params[:form_txt] if params[:form_txt]
          page << 're_activate_link();' if params[:is_lease_agent] != 'true'
         end
        #page.call "load_completer"
        page <<  "setTimeout(close_error_msg,(1 * 500));"
      end
    end
  end

  def send_file_folder_update_mail_to_already_added_users(obj)
    type = obj.class == Document ? "file" : obj.class == Folder && obj.parent_id == 0 ? "property" : "folder"
    action_process = ((type=='property') ? "Property User" : "collaborator")
    unless params[:notification_alert].blank?
      msg,deleted_usr_ids = '' , []
      msg = msg+ ("New #{action_process}(s) #{@member_emails.join(",")} added in this #{type} ") if !@member_emails.empty?
      unless params[:deleted_users].blank?
        msg = msg+ ("#{action_process}(s) #{params[:deleted_users]} removed from this #{type} ")
        params[:deleted_users].split(",").each { |deleted_usr| deleted_usr_ids << User.find_by_email(deleted_usr).id }
      end
    if !@member_emails.empty? || !deleted_usr_ids.empty?
     for u in @members.map(&:id) - deleted_usr_ids
        mail_to_user = User.find_by_id(u)
        comment=params[:textarea] ? params[:textarea] : ""
        UserMailer.delay.file_or_folder_update_mail(obj,mail_to_user,raw(msg),current_user,comment)  if mail_to_user
     end
    end
    end
  end

   def recursive_delete_function(id)
    @sharer=SharedFolder.find(:all,:conditions => ["folder_id = ? and user_id = ? ",id,params[:mem_id]])
    documents = SharedDocument.find(:all,:conditions => ["folder_id = ? and user_id = ? and sharer_id = ?",id,params[:mem_id],current_user.id])
    documents.each do |d|
      d.destroy unless d.nil?
    end
    folder_find_mail(@sharer,@sharer)
  end

  def folder_find_mail(sharers,current)
    if !current.empty?
      sharers.each do |sharer|
        if @sub_sharers.index(sharer).nil?
          id=sharer.user_id
          @sub_sharers << sharer
          folders = Folder.find(:all,:conditions=> ["parent_id = ?", sharer.folder_id])
          fid = folders.collect{|f| f.id}
          @sfolders = SharedFolder.find(:all,:conditions=>["(user_id = ? or sharer_id = ?) and folder_id in (?)",sharer.user_id,sharer.user_id,fid])
          documents = SharedDocument.find(:all,:conditions=>["(user_id = ? or sharer_id = ?) and folder_id in (?)",sharer.user_id,sharer.user_id,sharer.folder_id])
          documents.each do |d|
            if d.document.user_id ==  params[:mem_id]
              documents2 = SharedDocument.find(:all,:conditions=>["document_id =?",d.document_id])
              documents2.each do |e|
                e.destroy
              end
            end
						d.destroy unless d.nil?
          end
          folder_find_mail(@sfolders,@sfolders)
        end
      end
      folder_find_sub_sharers(sharers)
    end
  end

  def  folder_find_sub_sharers(sharers)
    sharers.each do |sharer|
      id=sharer.user_id
      fid=sharer.folder_id
      @sub = SharedFolder.find(:all,:conditions=>["sharer_id = ? and folder_id = ? and sharer_id != user_id",id,fid])
      @sub1=@sub1+@sub
    end
    folder_find_mail(@sub1,@sub)
  end

  def display_revoke_option(user)
    if params[:id] !=nil && !params[:id].blank? && params[:folder_revoke] != "true"
      if @note
        @note = RealEstateProperty.find_real_estate_property(params[:id])
        else
          params[:document_id] =  params[:document_id] ? params[:document_id] : ((params[:id] !=nil && !params[:id].blank? && params[:folder_revoke] != "true") ? params[:id] :  nil)
      @doc = Document.find_by_id(params[:document_id]) if params[:document_id]
      @folder  = @doc.folder
      params[:folder_id] = @folder.id if @folder
      end
      params[:show_missing_file] =  params[:show_missing_file] ? params[:show_missing_file] : "false"
    end
    if params[:folder_id]
      @folder = Folder.find_by_id(params[:folder_id])
    end
    if @note
      owner=params[:folder_revoke] ? find_folder_owner(params[:folder_id]) : (params[:revoke_fn] ?  find_fn_owner(params[:id])  : (params[:id] !=nil && !params[:id].blank? ? find_doc_owner_remote(params[:id]) : "") )
      else
    owner=params[:folder_revoke] ? find_folder_owner(params[:folder_id]) : (params[:revoke_fn] ?  find_fn_owner(params[:id])  : (params[:document_id] !=nil && !params[:document_id].blank? ? find_doc_owner_remote(params[:document_id]) : "") )
    end
    current_user.email if owner!= current_user.email
    list = params[:list] == "shared_list" ? 'shared_list' : 'sub_list'
    if owner != user.email
      if  !params[:folder_revoke] && !params[:revoke_fn] && @folder && params[:id] !=nil && params[:id] && check_is_doc_shared_to_displayed_user(@doc,user)
      prop_var = @doc!=nil ? @doc.folder : @note
        if !is_doc_parent_folder(prop_var,user)
          return raw("<a href=# onclick='if (confirm(\"Are you sure you want to remove this user ?\")){deleted_already_added_users.push(\"#{user.email}\");revoke=1;delete_collaborator_users(\"#{user.email}\",\"#{user.id}\",\"true\");} return false'><img border=0 width=7 height=7 src='/images/del_icon.png\' title='#{remove_collaborator_tooltip}' /></a>")
        end
      elsif (params[:folder_revoke]) && @folder && check_is_folder_shared_to_displayed_user(@folder,user)
        if !is_parent_folder(@folder,user)
          return raw("<a href=# onclick='if (confirm(\"Are you sure you want to remove this user ?\")){deleted_already_added_users.push(\"#{user.email}\");revoke=1;delete_collaborator_users(\"#{user.email}\",\"#{user.id}\",\"true\");} return false'><img border=0 width=7 height=7 src='/images/del_icon.png\' title='#{remove_collaborator_tooltip}' /></a>")
        end
      end
    end
  end

  def is_parent_folder(folder,user)
    folder_names = ["Excel Uploads","AMP Files"]
    parent_owner = Folder.find_by_id(folder.parent_id)
    if parent_owner && parent_owner.user_id  == user.id
      if parent_owner && parent_owner.parent_id == 0 && !parent_owner.is_master && parent_owner.name != 'my_files' && folder_names.index(folder.name).nil?
        return false
      else
        return true
      end
    else
      s = SharedFolder.find_by_folder_id(folder.parent_id,:conditions=>["user_id = ?",user.id],:select=>'id')
      if !s.nil?
          if parent_owner && parent_owner.parent_id == 0 && !parent_owner.is_master && parent_owner.name != 'my_files' && folder_names.index(folder.name).nil?
            return false
           else
             return true
          end
      else
        return false
      end
    end
  end

  def is_doc_parent_folder(folder,user)
    folder_names = ["Excel Uploads","AMP Files"]
    doc_parent_owner = Folder.find_by_id(folder.id)
    if doc_parent_owner.user_id  == user.id
      if doc_parent_owner && doc_parent_owner.parent_id == 0 && !doc_parent_owner.is_master && doc_parent_owner.name != 'my_files' && folder_names.index(folder.name).nil?
          return false
      else
      return true
      end
    else
      s = SharedFolder.find_by_folder_id(folder.id,:conditions=>["user_id = ?",user.id],:select=>'id')
      if !s.nil?
        if doc_parent_owner && doc_parent_owner.parent_id == 0 && !doc_parent_owner.is_master && doc_parent_owner.name != 'my_files' && folder_names.index(folder.name).nil?
          return false
        else
          return true
        end
      else
        return false
      end
    end
  end

  def check_is_doc_shared_to_displayed_user(d,user)
    sd = SharedDocument.find_by_document_id(d.id,:conditions=>["user_id = ? and sharer_id =?",user.id,current_user.id],:select=>'id') if d
    if !sd.nil? || (d && d.user_id == current_user.id)
      return true
    else
      return false
    end
  end

  def check_is_folder_shared_to_displayed_user(f,user)
    sf = SharedFolder.find_by_folder_id(f.id,:conditions=>["user_id = ? and sharer_id =?",user.id,current_user.id],:select=>'id')
    if !sf.nil? || (f && f.user_id == current_user.id)
      return true
    else
      return false
    end
  end

 def add_already_added_user(m_list)
    for user in params[:already_added_users].split(",")
      user_details = find_user_details(user.strip)
      m_list = m_list + "<div class='add_users_collaboratercol' id='#{user+user_details.id.to_s}'><div class='add_users_imgcol'><img width='48' height='48' src='#{display_image_for_user(user_details.id)}'/></div><div class='collaboraterow'><div class='collaboratername'>#{(!user_details.name.nil? and !user_details.name.blank?) ?  user_details.name : user.split('@')[0]} <a href='#' onclick='if (confirm(\"Are you sure you want to remove this user ?\")){delete_collaborator_users(\"#{user}\",\"#{user_details.id}\");} return false'><img border='0' width='7' height='7' src='/images/del_icon.png' title='#{remove_collaborator_tooltip}'  /></a></div><div class='collaborateremail'>#{user}</div> </div></div>"
    end
    return raw(m_list)
  end

  def is_parent_folder_of_folder_shared(f)
    is_shared = SharedFolder.find_by_folder_id(f.parent_id,:conditions=>["sharer_id = ? and user_id =?",f.user_id,current_user.id])
    is_shared = SharedFolder.find_by_folder_id(f.parent_id,:conditions=>["user_id = ? and sharer_id =?",f.user_id,current_user.id]) if is_shared.nil?
    is_shared = SharedFolder.find_by_folder_id(f.parent_id,:conditions=>["user_id = ?",current_user.id]) if is_shared.nil?
    return is_shared
 end

  def is_folder_of_doc_shared(d)
    is_doc_shared = SharedDocument.find_by_folder_id(d.folder_id,:conditions=>["sharer_id = ? and user_id =?",d.folder.user_id,current_user.id])
    is_doc_shared = SharedDocument.find_by_folder_id(d.folder_id,:conditions=>["user_id = ? and sharer_id =?",d.folder.user_id,current_user.id]) if is_doc_shared.nil?
   is_doc_shared = SharedDocument.find_by_folder_id(d.folder_id,:conditions=>["user_id = ?",current_user.id]) if is_doc_shared.nil?
    return  is_doc_shared
end

  def permalink_generation(doc_id)
    document = Document.find_by_id(doc_id)
    document.permalink = "/document/"+ActiveSupport::SecureRandom.hex(10) if document.permalink.eql?(nil)
    document.save
  end
  def permalink_generation_for_folder(fol_id)
    folder = Folder.find_by_id(fol_id)
    folder.permalink = "/folder_share/"+ActiveSupport::SecureRandom.hex(10) if folder.permalink.eql?(nil)
    folder.save
  end
  def display_perma_link(doc_or_folder_id,type)
   return Document.find_by_id(doc_or_folder_id).permalink if type == 'document'
   return Folder.find_by_id(doc_or_folder_id).permalink
  end

  def clippy(text, bgcolor='#faf9f9')
  html = <<-EOF
    <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
            width="110"
            height="14"
            id="clippy" >
    <param name="movie" value="/javascripts/clippy.swf"/>
    <param name="allowScriptAccess" value="always" />
    <param name="quality" value="high" />
    <param name="scale" value="noscale" />
    <param NAME="FlashVars" value="text=#{text}">
    <param name="bgcolor" value="#{'#faf9f9'}">
    <embed src="/javascripts/clippy.swf"
           width="110"
           height="14"
           name="clippy"
           quality="high"
           allowScriptAccess="always"
           type="application/x-shockwave-flash"
           pluginspage="http://www.macromedia.com/go/getflashplayer"
           FlashVars="text=#{text}"
           bgcolor="#{'#faf9f9'}"
    />
    </object>
  EOF
end

def find_parent_folder_members(f)
   f_id =  params[:folder_revoke] == "true" ? f.parent_id : f.id
   members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id !=? ",f_id,current_user.id]).collect{|sf| sf.user.email}.compact
   return members
end

def find_property_folder_members(f)
 parent_folder_id =  params[:folder_revoke] == "true" ? Folder.find_by_id(f.parent_id).parent_id  : f.parent_id
 members = SharedFolder.find(:all,:conditions=>["folder_id = ?",find_property_folder_by_property_id(f.real_estate_property.id).id]).collect{|sf| sf.user.email}.compact
    if parent_folder_id != 0
     members << find_folder_owner(find_property_folder_by_property_id(f.real_estate_property.id).id)
   end
   return members
 end

 #Updates the page after every action
  def update_respond_to_parent(form,tab,msg,page)
  if params[:is_property_folder] == "true"
      portfolio_id = @folder ? @folder.portfolio_id : (params[:portfolio_id] ? params[:portfolio_id] : '')
      @folder = Folder.find_by_portfolio_id_and_parent_id(portfolio_id,-1)
    end
    if (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == 'true' ||  params[:users_form_close] == 'true' || params[:users_mail_form_close] == 'true')
      send_weekly_alert_mail
    elsif params[:call_from_variances] == "true" &&  (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == 'true' ||  params[:users_form_close] == 'true' || params[:users_mail_form_close] == 'true' ) #|| params[:alert_form_close] != 'false')
  responds_to_parent do
  variances_exp_comment
  end
    elsif params[:from_property_details] == "true" && (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == 'true' ||  params[:users_form_close] == 'true' || params[:users_mail_form_close] == 'true') #|| params[:alert_form_close] != 'false')
      property_view
    elsif params[:from_debt_summary] == "true" && (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == 'true' ||  params[:users_form_close] == 'true' || params[:users_mail_form_close] == 'true') #|| params[:alert_form_close] != 'false')
      loan_details
    elsif  (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true")
      @dispaly_initial_list = true  if params[:edit_inside_asset] == "true"
      respond_to_parent_initial_page
    else
      @tab = tab
      form_hash_for_loan_details if form == "loan_form" && !@loan_hash
      if @property && params[:tab_id] == "4"
          form = "loan_form"
          @tab= "3"
      end
      if @property && params[:tab_id] == "5"
          form = "users_form"
          @tab= "5"
      end
      if @property && params[:tab_id] == "6"
          form = "variances_form"
          @tab= "6"
        end
    if params[:users_form_submit]  == 'true'
          #~ page.replace_html "tabs",:partial =>"/real_estates/property_sub_tab",:locals=>{:tab_collection => @tab,:property_collection =>@property}
          page.replace_html "sheet123",:partial =>"/real_estates/#{form}"
          #~ page.call "activate_tabs","#{@tab}","#{is_commercial(@property)}" if @tab != "4"
          page.call "flash_writter", "#{msg}" if msg && !msg.blank?
    else
      responds_to_parent do
        render :update do |page|
          #~ page.replace_html "tabs",:partial =>"/real_estates/property_sub_tab",:locals=>{:tab_collection => @tab,:property_collection =>@property}
          page.replace_html "sheet123",:partial =>"/real_estates/#{form}"
          #~ page.call "activate_tabs","#{@tab}","#{is_commercial(@property)}" if @tab != "4"
          page.call "flash_writter", "#{msg}" if msg && !msg.blank?
          page << "jQuery('#property_name_id').html('#{@property.property_name}')"
          end
        end
      end
    end
  end


def display_lease_agents
    @folder = Folder.find_by_id(params[:folder_id])
    @data,@mem_list,@manager_list,@sub_sharers,@sub1,@sub,@asset_managers_data ='','','',[],[],[],''
    @portfolio = @folder.portfolio
    @user = current_user
    find_folder_members
    add_edit_leasing_agents
end

 #to display lease agent name in add/edit leasing agent lightbox
def add_edit_leasing_agents
    for user in @members.uniq
      @mem_list = @mem_list.to_s + user.email.to_s + ","
      @data = @data + "<div class='add_users_collaboratercol' id='#{user.email}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{user.email}</div> </div></div>"
    end
     @asset_managers = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",params[:folder_id],current_user.id]).collect{|sf| sf.user if !sf.user.has_role?("Leasing Agent")}.compact
     for user in @asset_managers.uniq
      @manager_list = @manager_list.to_s + user.email.to_s + ","
      @asset_managers_data = @asset_managers_data + "<div class='add_users_collaboratercol' id='added_asset_manager_#{user.email}' style='display:none'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{user.email}</div> </div></div>"
    end
    if params[:add_contacts] == 'true' && params[:note_add_edit] != 'true'
       responds_to_parent do
         render :update do |page|
             page.replace_html "basicbodycontainer",:partial=>"collaborators/view_to_add_collaborators"
        end
       end
    end
  end

#Collect all collaborators and asset managers except  leainsg agents
def  find_collaborators_and_asset_managers
     proeprty_folder = find_property_folder_by_property_id(@folder.real_estate_property_id)
     property_members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",proeprty_folder.id,current_user.id]).collect{|sf| sf.user.email }.compact
  if params[:is_lease_agent] != 'true' && current_user.has_role?("Asset Manager")
   @users_collection = User.find_by_sql("SELECT users.email FROM `users` INNER JOIN `roles_users` ON `roles_users`.`user_id` = `users`.`id` INNER JOIN `roles` ON `roles`.`id` = `roles_users`.`role_id` WHERE (`roles`.`name` = 'Leasing Agent') group by users.email").map(&:email)
  else
  @users_collection = User.find_by_sql("SELECT users.email FROM `users` INNER JOIN `roles_users` ON `roles_users`.`user_id` = `users`.`id` INNER JOIN `roles` ON `roles`.`id` = `roles_users`.`role_id` WHERE (`roles`.`name` = 'Asset Manager') group by users.email").map(&:email)
end
@users_collection  = @users_collection  - property_members if property_members.present?
return @users_collection
end

#To check whether adding property user or collaborator
def check_is_property_user
        params[:is_lease_agent] == 'true' ? false : ((params[:note_add_edit] == 'true' || params[:is_property_folder] == 'true' || params[:edit_inside_asset] == "true" || params[:from_debt_summary] == "true" || params[:from_property_details] || params[:call_from_prop_files] == 'true') ? true : false)
      end


#To display tooltip in delete image
def  remove_collaborator_tooltip
  params[:is_lease_agent] == 'true' ? 'Remove Leasing Agent' : (check_is_property_user ? 'Remove Property User' : 'Remove Collaborator')
end


end
