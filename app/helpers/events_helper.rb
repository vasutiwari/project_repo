module EventsHelper
  def event_link_formation(event)
    ev = []
    if @from_dash_board.eql?(true)
      for res in event.event_resources
        if event.action_type == "rename"
          if res.resource_type == 'Document'
            ev << "#{dashboard_link_for_document(res.resource,event.description2)}" if  res.resource
            ev << "#{dashboard_link_for_document(res.resource,event.description)}" if  res.resource
          else
            ev << event.description2  if  res.resource
            ev << event.description  if  res.resource
          end
        else
          if res.resource_type == 'Document'
            ev << "#{dashboard_link_for_document(res.resource,event.description)}" if  res.resource
          else
            ev << event.description if  res.resource
          end
        end
      end
    else
      for res in event.event_resources
        if event.action_type == "rename"
          if res.resource_type == 'Document'
            ev << "#{link_for_document(res.resource,event.description2)}" if  res.resource
            ev << "#{link_for_document(res.resource,event.description)}" if  res.resource
          else
            ev << lengthy_word_simplification(event.description2, 5, 10)  if  res.resource
            ev << lengthy_word_simplification(event.description, 5, 10)  if  res.resource
          end
        else
          if res.resource_type == 'Document'
            ev << "#{link_for_document(res.resource,event.description)}" if  res.resource
          else
            ev << lengthy_word_simplification(event.description, 5, 10)  if  res.resource
          end
        end
      end
    end
    return ev
  end

  # below method is used for event time
  def display_event_time(event)
    if event and event.created_at
      dis = distance_of_time_in_words_to_now(event.created_at).gsub(/about /,'')
      if dis.split(' ').include?("day")
        return "Yesterday #{event.created_at.strftime("%I:%S%p")}"
      elsif dis.split(' ').include?("days")
        return "#{event.created_at.strftime("%m/%d/%y  %I:%S%p")}"
      elsif (dis.split(' ').include?("less") && dis.split(' ').include?("than"))
        return dis
      else
        return dis+" ago"
      end
    else
      return ""
    end
  end

  def event_user_id(event)
    event_user_id = event.user_id
    return event_user_id
  end

  #below method is used to display user name
  def display_event_users(event)
    if event.user_id == current_user.id
      user_name =  "You"
    else
      user = User.find_by_id(event.user_id)
      user_name = user.name? ? lengthy_word_simplification(user.name, 5, 10) :  lengthy_word_simplification(user.email, 5, 10)
      name = user.name? ? user.name : user.email
    end
    if user_name.include?("...")
      return raw("<span title='#{defined?(name).nil? ? "" : name}'>#{user_name}</span>")
    else
      return user_name
    end
  end

  #this is the new method to display all events
  def display_event(event)
    event_type = EventResource.find_by_event_id(event.id).resource_type
    val = event.action_type.downcase.strip if !event.nil?
    shared_user_exists = (val == "collaborators" || val == "de_collaborators" || val == "share" || val == "shared" || val == "unshare" ||  val == "unshared") ? !(User.find_by_id(event.shared_user_id).nil? || User.find_by_id(event.shared_user_id).blank?) : true
    if !event.nil? && !(User.find_by_id(event.user_id).nil? || User.find_by_id(event.user_id).blank?) && (shared_user_exists)
      case ( val )
      when 'sharelink'
        if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Folder"
            event_resource_id = EventResource.find_by_event_id(event.id).resource_id
            property_folder = Folder.find_by_id_and_parent_id_and_is_master(event_resource_id,0,0)
            if !(property_folder.nil? || property_folder.blank?)
              return raw("<img src='/images/added.png' > #{user} got the link to share the Property #{ev.join(',')}")
            else
              return raw("<img src='/images/added.png' > #{user} got the link to share the #{event_type} #{ev.join(',')}")
            end
          elsif event_type == "Document"
            return raw("<img src='/images/added.png' > #{user} got the link to share #{ev.join(',')}")
          else
            return raw("<img src='/images/added.png' > #{user} got the link to share the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "create":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Folder"
            event_resource_id = EventResource.find_by_event_id(event.id).resource_id
            property_folder = Folder.find_by_id_and_parent_id_and_is_master(event_resource_id,0,0)
            if !(property_folder.nil? || property_folder.blank?)
              return raw("<img src='/images/added.png' > #{user} created the Property #{ev.join(',')}")
            else
              return raw("<img src='/images/added.png' > #{user} added the #{event_type} #{ev.join(',')}")
            end
          elsif event_type == "Document"
            return raw("<img src='/images/added.png' > #{user} added #{ev.join(',')}")
          else
            return raw("<img src='/images/added.png' > #{user} added the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "upload":
        if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/uploaded.png' > #{user} uploaded #{ev.join(',')}")
          else
            return raw("<img src='/images/uploaded.png' > #{user} uploaded the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "new_version":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img class='sprite s_add' src='/images/icon_spacer.gif' > #{user} added a new version for #{ev.join(',')}")
          else
            return raw("<img class='sprite s_add' src='/images/icon_spacer.gif' > #{user} added a new version for the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "delete":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/deleted.png' > #{user} deleted #{ev.join(',')}")
          else
            return raw("<img src='/images/deleted.png' > #{user} deleted the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "permanent_delete":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/permanently_deleted.png' > #{user} permanently deleted #{ev.join(',')}")
          else
            return raw("<img src='/images/permanently_deleted.png' > #{user} permanently deleted the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "download":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          event_resource_id = EventResource.find_by_event_id(event.id).resource_id
          property_folder = Folder.find_by_id_and_parent_id_and_is_master(event_resource_id,0,0)
          if !(property_folder.nil? || property_folder.blank?)
            return raw("<img src='/images/download.png' > #{user} downloaded the Property #{ev.join(',')}")
          else
            if event_type == "Document"
              return raw("<img src='/images/download.png' > #{user} downloaded #{ev.join(',')}")
            else
              return raw("<img src='/images/download.png' > #{user} downloaded the #{event_type} #{ev.join(',')}")
            end
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "rename":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/rename.png' > #{user} renamed #{ev.join(' as ')}")
          else
            return raw("<img src='/images/rename.png' > #{user} renamed the #{event_type} #{ev.join(' as ')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "shared":
          if !event.event_resources.empty?
          shared_user = User.find_by_id(event.shared_user_id)
          if event.user_id == current_user.id
            user = "You"
            sharer = shared_user.email if shared_user !=nil
          else
            user = User.find_by_id(event.user_id).email
            sharer = shared_user.email if shared_user !=nil
            if sharer == current_user.email
              sharer = "You"
            end
          end
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/shared.png' /> #{user} shared #{ev.join(',')} with #{sharer}")
          else
            return raw("<img src='/images/shared.png' /> #{user} shared the #{event_type} #{ev.join(',')} with #{sharer}")
          end
        else
          user = User.find_by_id(event.user_id).email
          sharer = shared_user.email if shared_user !=nil
        end
        break;
      when "moved":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/move.gif' > #{user} moved #{ev.join(',')} #{event.description2}")
          else
            return raw("<img src='/images/move.gif' > #{user} moved the #{event_type} #{ev.join(',')} #{event.description2}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "copied":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/copy.png' > #{user} copied #{ev.join(',')} #{event.description2}")
          else
            return raw("<img src='/images/copy.png' > #{user} copied the #{event_type} #{ev.join(',')} #{event.description2}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "commented":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/commented.png' >  #{user} added a comment for #{ev.join(',')}")
          else
            return raw("<img src='/images/commented.png' >  #{user} added a comment for #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "del_comment":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/comments_delete.png' >  #{user} deleted a comment for #{ev.join(',')}")
          else
            return raw("<img src='/images/comments_delete.png' >  #{user} deleted a comment for #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "rep_comment":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/comment_reply.png' >  #{user} replied a comment for #{ev.join(',')}")
          else
            return raw("<img src='/images/comment_reply.png' >  #{user} replied a comment for #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "up_comment":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/commented_updated.png' >  #{user} edited a comment for #{ev.join(',')}")
          else
            return raw("<img src='/images/commented_updated.png' >  #{user} edited a comment for #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "restored":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/restored.png' > #{user} restored #{ev.join(',')}")
          else
            return raw("<img src='/images/restored.png' > #{user} restored the #{event_type} #{ev.join(',')}")
          end
        else
          error_message(event,'deleted')
        end
        break;
      when "mapped_secondary_file":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          return raw("<img src='/images/task_updated.png' > #{user} added / removed a secondary file #{event.description} in the #{event_type} #{event.description2}")
        else
          error_message(event,'deleted')
        end
        break;
      when "create_secondary_file":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          return raw("<img src='/images/task_updated.png' > #{user} added / removed a secondary file #{event.description} in the #{event_type} #{event.description2}")
        else
          error_message(event,'deleted')
        end
        break;
      when "collaborators":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          event.description2 = event.description2.include?("my_files") ? event.description2.gsub("my_files",'') : event.description2
          return raw("<img src='/images/shared.png' > #{user} added #{event.action_type.gsub('collaborators','collaborator(s)')} #{lengthy_word_simplification(event.description, 5, 10)} #{event.description2}")
        else
          error_message(event,'deleted')
        end
        break;
      when "de_collaborators":
          if !event.event_resources.empty?
          user = display_event_users(event)
          ev = event_link_formation(event)
          event.description2 = event.description2.include?("my_files") ? event.description2.gsub("my_files",'') : event.description2
          return raw("<img src='/images/shared.png' > #{user} removed #{event.action_type.gsub('de_collaborators','collaborator(s)')} #{lengthy_word_simplification(event.description, 5, 10)} #{event.description2}")
        else
          error_message(event,'deleted')
        end
        break;
      when "unshared":
          if !event.event_resources.empty?
          shared_user = User.find_by_id(event.shared_user_id)
          if event.user_id == current_user.id
            user = "You"
            sharer = shared_user.email
          else
            user = User.find_by_id(event.user_id).email
            sharer = shared_user.email
            if sharer == current_user.email
              sharer = "You"
            end
          end
          ev = event_link_formation(event)
          if event_type == "Document"
            return raw("<img src='/images/unshared.png' /> #{user} unshared #{ev.join(',')} with #{sharer}")
          else
            return raw("<img src='/images/unshared.png' /> #{user} unshared the #{event_type} #{ev.join(',')} with #{sharer}")
          end
        else
          user = User.find_by_id(event.user_id).email
          sharer = shared_user.email
        end
        break;
      else
        return ""
      end
    end
  end

  def find_all_events_of_folder(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ?",folder_id])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    @doc_names = [ ] if (@doc_names.nil? || @doc_names.empty? || loop_starts)
    folders.compact.each do |f|
      find_all_events_of_folder(f.id, false)
      @folder_s << f if f && check_is_folder_shared(f) == "true"
    end
    documents = Document.find(:all,:conditions=> ["folder_id = ?",folder_id],:select=>'id,user_id') # - Selected only id field
    @doc_s += documents
    @doc_s = @doc_s.compact.collect{|d| d if check_is_doc_shared(d) == "true"}
    document_names = DocumentName.find(:all,:conditions=> ["folder_id = ?",folder_id],:select=>'id') # - Selected only id field
    @doc_names += document_names
    return @folder_s.compact,@doc_s.compact,@doc_names.compact
  end

  def breadcrump_display_event_asset_manager(folder)
    arr =[]
    i = 0
    while !folder.nil?
      tmp_name = "<div class='setupiconrow'><img border='0' width='16' height='16' src='/images/folder.png'></div><div class='setupheadactvelabel'><a href='' onclick=\"load_writter();show_events('#{folder.id}');load_completer();return false;\">#{truncate_extra_chars(folder.name)}</a></div>"
      name = (i == 0) ? "<div class='setupiconrow'><img width='16' height='16' src='/images/folder.png'></div><div class='setupheadlabel'>#{truncate_extra_chars(folder.name)}</div>" :  "#{tmp_name}"
      arr << name
      folder =  Folder.find_by_id(folder.parent_id)
      i += 1
    end
    return raw(arr.reverse.join("<div class='setupiconrow3'><img width='10' height='9' src='/images/eventsicon2.png'></div>"))
  end

  def breadcrump_display_event_shared_user(folder)
    arr =[]
    i = 0
    f = folder.parent_id != 0 ?  Folder.find(folder.parent_id) : ""  if !folder.nil?
    while !folder.nil?
      if  !is_folder_shared_to_current_user(folder.id).nil?
        if current_user.has_role?("Shared User") && session[:role] == 'Shared User' && f == 0
          tmp_name = "<div class='setupiconrow'><img border='0' width='16' height='16' src='/images/package.png'></div><div class='setupheadactvelabel'><a href='/shared_users?data_hub=asset_data_and_documents&pid=#{folder.portfolio_id}'>#{folder.name}</a></div>"
        else
          tmp_name = "<div class='setupiconrow'><img border='0' width='16' height='16' src='/images/package.png'></div><div class='setupheadactvelabel'><a href='' onclick=\"load_writter();show_events('#{folder.id}');load_completer();return false;\">#{folder.name}</a></div>"
        end
      end
      name = (i == 0) ? "<div class='setupiconrow'><img width='16' height='16' src='/images/folder.png'></div><div class='setupheadlabel'>#{folder.name}</div>" :  "#{tmp_name}"
      arr << name if !is_folder_shared_to_current_user(folder.id).nil?
      folder =  Folder.find_by_id(folder.parent_id)
      i += 1
    end
    return raw(arr.reverse.join("<div class='setupiconrow3'><img width='10' height='9' src='/images/eventsicon2.png'></div>"))
  end
  def display_pagination
    return will_paginate @events, :renderer => 'RemoteLinkRenderer', :page_links => false, :previous_label => "<div class='previouscol'><span class='previousicon'><img src='/images/previous_icon.png' width='17' height='15' border='0' /></span>newer</div>",  :next_label =>"<div class='previouscol'>older<span class='nexticon'><img src='/images/next_icon.png'  width='17' height='15' border='0'/></span></div>", :params=>{:folder_id => params[:folder_id], :shared_user_id => params[:shared_user_id]  }  if params[:shared_user_id]
    will_paginate @events, :renderer => 'RemoteLinkRenderer', :page_links => false, :previous_label => "<div class='previouscol'><span class='previousicon'><img src='/images/previous_icon.png' width='17' height='15' border='0' /></span>newer</div>",  :next_label =>"<div class='previouscol'>older<span class='nexticon event_page'><img src='/images/next_icon.png'  width='17' height='15' border='0'/></span></div>", :params=>{:folder_id => params[:folder_id]  }
  end
  def initial_assignments
    @shared_folders_real_estate,@shared_docs_real_estate = find_manage_real_estate_shared_folders('false')
    find_portfolios_to_display_in_collabhub
    @sahred_folders_collection,@shared_docs_collection,@shared_properties_collection = [],[],[]
    @sahred_folders_collection = @shared_folders_real_estate.collect{|x| x.id}.join(",")
    @shared_docs_collection = @shared_docs_real_estate.collect{|x| x.id}.join(",")
    @shared_and_owned_properties_collection = @real_estate_properties.collect{|x| x.id}.join(",")
  end
end
