# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  @@mails = []

  def truncate_extra_chars(name)
    return truncate(name, :omission => "...", :length => 30)
  end

  def truncate_extra_chars_for_expl(name,len)
    len = 100 #To display 100 characters in the explanation box
    return convert_lines_to_span(truncate(name, :omission => "...", :length => len))
  end

  def display_date(date)
   (date.nil? || date.blank?) ? '-' : date.strftime('%m/%d/%Y')
  end

  def breadcrump_display(folder,fid)
    arr =[]
    while !folder.nil?
      arr << "<a href='#' onclick='show_folder_content(#{folder.parent_id},#{fid});return false;'>#{folder.name}</a>"
      folder =  MasterFolder.find_by_id(folder.parent_id)
    end
    return raw(arr.reverse.join(" >> "))
  end

  #Called from Admin's panel to display the files count of a folder.Used in master_folders/_folders_view and master_folders/_folders_content
  def no_of_files_of_folder(folder_id, loop_starts)
    folders = MasterFolder.find(:all,:conditions=> ["parent_id = ?",folder_id])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    folders.each do |f|
      no_of_files_of_folder(f.id, false)
      @folder_s << f
    end
    documents = MasterFile.find(:all,:conditions=> ["master_folder_id = ?",folder_id])
    @doc_s += documents
    return @doc_s.length
  end

  def no_of_files_of_asset_folder(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    folders.each do |f|
      no_of_files_of_asset_folder(f.id, false)
      @folder_s << f
    end
    documents = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted=false",folder_id])
    documents.each do |d|
      sd = SharedDocument.find_by_document_id(d.id,:conditions=>["user_id = ? OR sharer_id = ?",current_user.id,current_user.id])
      @doc_s << sd if sd != nil
    end
    return @doc_s.length
  end

  #Called from Properties/_folders_row
  def shared_no_of_files_of_asset_folder(folder_id, loop_starts)
    user=current_user
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id],:select=>'id')
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = 0 if (@doc_s == 0 || loop_starts)
    folders.each do |f|
      shared_no_of_files_of_asset_folder(f.id, false)
      @folder_s << f
    end
    documents = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted=false",folder_id])
    documents.each do |d|
      sd = SharedDocument.find(:first,:conditions=>["document_id = ? and (user_id = ? OR sharer_id = ? AND user_id != sharer_id)",d.id,user.id,user.id]) #Earlier it was find_by
      owner = d.user.email if d.user #find_doc_owner(d.id)
      if user.email == owner
        if(d.folder.user == user || !is_folder_shared_to_current_user(d.folder_id).nil?)
          @doc_s += 1 if d.document_name == nil
        end
      end
      @doc_s += 1 if sd != nil && user.email != owner && sd.document.document_name == nil
    end
    return @doc_s #.length
  end

  #Called from Properties/_folders_row
  def no_of_files_of_deleted_asset_folder(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=true",folder_id])
    @folder_s1 = [ ] if (@folder_s1.nil? || @folder_s1.empty? || loop_starts)
    @doc_s1 = 0 if (@doc_s1 == 0 || loop_starts)
    folders.each do |f|
      no_of_files_of_deleted_asset_folder(f.id, false)
      @folder_s1 << f
    end
    documents = Document.count(:all,:conditions=> ["folder_id = ? and is_deleted=true",folder_id])
    @doc_s1 += documents
    return @doc_s1 #.length
  end

  def no_of_missing_files_of_asset_folder(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || loop_starts)
    folders.each do |f|
      no_of_missing_files_of_asset_folder(f.id, false)
      @folder_s << f
    end
    b = Document.find(:all,:conditions=>["is_deleted = ? and folder_id = ? and is_master = ? and property_id is not NULL and due_date is NOT NULL",false,folder_id,0])
    @doc_s += b
    return @doc_s.length
  end
  #Called from Properties/_folders_row
  def no_of_missing_files_of_asset_folder_real_estate(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s1 = [ ] if (@folder_s1.nil? || @folder_s1.empty? || loop_starts)
    @doc_s1 = 0 if (@doc_s1 == 0 || loop_starts)
    folders.each do |f|
      no_of_missing_files_of_asset_folder_real_estate(f.id, false)
      @folder_s1 << f
    end
    b = Document.count(:all,:conditions=>["is_deleted = ? and folder_id = ? and is_master = ? and real_estate_property_id is not NULL and due_date is NOT NULL",false,folder_id,0]) # Changed find as count
    @doc_s1 += b
    return @doc_s1 #.length - Removed length as count is mentioned in query
  end

  # To display corresponding document's image before filename in partials/docs_list
  def find_content_type(t,shared_or_unshared,is_deleted)
    excel_ext = ['xls','xlsx']
    image_ext = ['jpg','jpeg','png','gif','bmp','tiff','tif']
    docs_ext = ['txt','doc','docx']
    ppt_ext = ['ppt','pps']
    pdf_ext = ['pdf']
    zip_ext = ['zip']
    split_filename = t.filename.split('.') if !t.filename.nil?
    ext = (split_filename.nil? || split_filename.last.nil?) ? '' :  split_filename.last.downcase
    if excel_ext.include?(ext) && shared_or_unshared  == 'shared'
      image = is_deleted == 'true' ? "asset_type_excel_shared_del.png" : "asset_type_excel_shared.png"
    elsif  excel_ext.include?(ext) && shared_or_unshared  == 'unshared'
      image = is_deleted == 'true' ? "asset_type_excel_del.png" : "asset_type_excel.png"
    elsif pdf_ext.include?(ext)  && shared_or_unshared  == 'shared'
      image = is_deleted == 'true' ? "asset_type_pdf_shared_del.png" : "asset_type_pdf_shared.png"
    elsif pdf_ext.include?(ext)  && shared_or_unshared  == 'unshared'
      image = is_deleted == 'true' ? "asset_type_pdf_del.png" : "asset_type_pdf.png"
    elsif image_ext.include?(ext)  && shared_or_unshared  == 'shared'
      image = is_deleted == 'true' ? "asset_type_image_shared_del.png" : "asset_type_image_shared.png"
    elsif image_ext.include?(ext)  && shared_or_unshared  == 'unshared'
      image = is_deleted == 'true' ? "asset_type_image_del.png" : "asset_type_image.png"
    elsif docs_ext.include?(ext) && shared_or_unshared  == 'shared'
      image = is_deleted == 'true' ? "asset_type_word_shared_del.png" : "asset_type_word_shared.png"
    elsif docs_ext.include?(ext) && shared_or_unshared  == 'unshared'
      image = is_deleted == 'true' ? "asset_type_word_del.png" : "asset_type_word.png"
    elsif ppt_ext.include?(ext) && shared_or_unshared  == 'shared'
      image = is_deleted == 'true' ? "asset_type_ppt_shared_del.png" : "asset_type_ppt_shared.png"
    elsif ppt_ext.include?(ext) && shared_or_unshared  == 'unshared'
      image = is_deleted == 'true' ? "asset_type_powerpoint_del.png" : "asset_type_powerpoint.png"
    else
      if shared_or_unshared  == 'shared'
        image = is_deleted == 'true' ? "asset_note_shared_delete.png" : "asset_note_shared.png"
      else
        image =  is_deleted == 'true' ? "asset_note_deleted.png" : "asset_note.png"
      end
    end
    return image
  end

  def breadcrump_display_asset_manager(folder)
    arr =[]
    i = 0
    while !folder.nil?
      tmp_name = "<div class='setupiconrow'><img border='0' width='16' height='16' src='/images/folder.png'></div><div class='setupheadactvelabel'><a href='' onclick=\"load_writter();new Ajax.Request('/assets/show_asset_files?folder_id=#{folder.id}&pid=#{folder.portfolio_id}',{ onComplete: function(request){ load_completer();}});return false;\">#{truncate_extra_chars(folder.name)}</a></div>"
      name = (i == 0) ? "<div class='setupiconrow'><img width='16' height='16' src='/images/folder.png'></div><div class='setupheadlabel'>#{truncate_extra_chars(folder.name)}</div>" :  "#{tmp_name}"
      arr << name
      folder =  Folder.find_by_id(folder.parent_id)
      i += 1
    end
    return raw(arr.reverse.join("<div class='setupiconrow3'><img width='10' height='9' src='/images/eventsicon2.png'></div>"))
  end

  def find_extension(d)
    image_extensions = ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif','jpe', 'cgm', 'tiff','jfif','dib']
    split_filename = d.filename.split('.')
    ext = (split_filename.nil? || split_filename[1].nil?) ? '' :  split_filename[1].downcase
    is_image = image_extensions.include?(ext) ? "yes" : "no"
    return is_image
  end

  def link_for_document(resource,txt)
    if resource
      if Document.find_by_id(resource.id).user_id == current_user.id || SharedDocument.find_by_document_id_and_user_id(resource.id,current_user.id)
        return ( resource.nil? ? '' : raw("<a href='#{download_file_path(resource.id)}' title='#{txt}'>#{lengthy_word_simplification(txt, 12, 18)}</a>"))
      else
        return ( resource.nil? ? '' : raw("<a href='#' onclick='flash_writter(\"Action restricted\");' title='#{txt}'>#{lengthy_word_simplification(txt, 12, 18)}</a>"))
      end
    end
  end

  def dashboard_link_for_document(resource,txt)
    if resource
      if Document.find_by_id(resource.id).user_id == current_user.id || SharedDocument.find_by_document_id_and_user_id(resource.id,current_user.id)
        return ( resource.nil? ? '' : raw("<a href='#{download_file_path(resource.id)}' title='#{txt}'>#{txt}</a>"))
      else
        return ( resource.nil? ? '' : raw("<a href='#' onclick='flash_writter(\"Action restricted\");' title='#{txt}'>#{txt}</a>"))
      end
    end
  end

  def error_message(event,action,share_details="")
    if action == 'deleted'
      return raw("<img class='sprite s_cancel' src='/images/icon_spacer.gif' > You #{action} #{event.description} #{event_type} #{share_details}")
    elsif  action == 'moved'
      return raw("<img class='sprite s_page_white_go' src='/images/icon_spacer.gif' > You #{action} one file/folder #{share_details}")
    else
      return raw("<img class='sprite s_cancel' src='/images/icon_spacer.gif' > You #{action} one file/folder #{share_details}")
    end
  end

  def find_doc_owner(doc_id)
    return Document.find(doc_id).user.email if Document.find(doc_id) && Document.find(doc_id).user
  end

  #Added newly - To find email of the document's owner by passing object
  def find_doc_owner_by_obj(doc)
    return doc.user.email if doc && doc.user
  end

  #Added newly - To find email of the folder's owner by passing object
  def find_folder_owner_by_obj(folder)
    return folder.user.email if folder && folder.user
  end

  def find_document_members(doc)
    if doc.class.name == "SharedDocument"
      doc = doc.document
    end
    members  = SharedDocument.find(:all,:conditions=>["document_id = ? and  user_id !=?",doc.id,current_user.id]).collect{|sf| sf.user}
    owner= User.find_by_email(find_doc_owner(doc))
    members << owner if owner && owner != current_user
    if current_user.has_role?("Shared User") && session[:role] == 'Shared User'
      user = doc.user
      members << user if user != current_user
    end
    members = members.uniq
    return members
  end

  #find collaboratorin hub realted queries
  def find_portfolio_fol_doc_task(port)
    @portfolio_document_count = 0
    port_real_est_props = port.real_estate_properties
    @portfolio_doc = []
    @portfolio_prop = (port.user_id == current_user.id) ? port_real_est_props : SharedFolder.find(:all, :conditions => ["real_estate_property_id in (?) and is_property_folder = ? and user_id = ? and client_id = ?",port_real_est_props.collect{|i| i.id},true,current_user.id,current_user.client_id])
    property_folders = Folder.find_all_by_portfolio_id_and_parent_id_and_is_master(port.id,0,0)
    property_folders.each do |property_folder|
      @portfolio_document_count = @portfolio_document_count + shared_no_of_files_of_asset_folder(property_folder.id,true)
    end
    portfolio_folder = Folder.find_by_parent_id_and_portfolio_id(-1,port.id)
    @portfolio_comment = portfolio_folder.comments if !(portfolio_folder.nil? || portfolio_folder.blank?)
  end

  def find_portfolio_prop(port)
    @portfolio_prop = (port.user_id == current_user.id) ? port.real_estate_properties : SharedFolder.find(:all, :conditions => ["real_estate_property_id in (?) and is_property_folder = ? and user_id = ? and client_id = ?",port.real_estate_properties.collect{|i| i.id},true,current_user.id,current_user.client_id])
    return @portfolio_prop
  end

  def find_folder_member(f)
    property_folder = find_property_folder_by_property_id(f.real_estate_property_id)
    if params[:is_lease_agent] == 'true'
      members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id !=?",f.id,current_user.id]).collect{|sf| sf.user  if sf.user.has_role?("Leasing Agent")}.compact
    elsif params[:data_hub] == "asset_data_and_documents" || (!request.env['HTTP_REFERER'].nil? && request.env['HTTP_REFERER'].include?("collaboration_hub") && property_folder && f.id ==property_folder.id)
      members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id !=?",f.id,current_user.id]).collect{|sf| sf.user  if !sf.user.has_role?("Leasing Agent")}.compact
    else
      members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id !=?",f.id,current_user.id]).collect{|sf| sf.user}.compact
    end
    owner= User.find_by_email(find_folder_owner(f))
    members << owner if owner && owner != current_user
    if(current_user.has_role?("Shared User") && session[:role] == 'Shared User') || (current_user.has_role?("Leasing Agent"))
      user = f.user
      members <<  user if user != current_user
    end
    members = members.uniq
    return members
  end

  def is_folder_shared_to_current_user(folder_id)
    folder = SharedFolder.find_by_folder_id(folder_id,:conditions=>["user_id = #{current_user.id} and client_id = #{current_user.client_id}"])
    return folder
  end

  def is_doc_shared_to_current_user(doc_id)
    doc = SharedDocument.find_by_document_id(doc_id,:conditions=>["user_id = #{current_user.id}"])
    return doc
  end

  def find_portfolio
    shared_folder = SharedFolder.find(:first,:conditions=>["user_id = ? and client_id = ? ",current_user.id,current_user.client_id])
    shared_document = SharedDocument.find(:first,:conditions=>["user_id=?",current_user.id])
    pid = shared_folder.nil? ? (shared_document.nil? ? nil : shared_document.folder.portfolio_id) : shared_folder.folder.portfolio_id
    return pid
  end

  def find_current_user(t)
    if t !=nil
      display = "yes"
      if current_user.has_role?("Shared User") && session[:role] == 'Shared User'
        display = (t.filename != "Rent_Roll_Template.xls" && t.filename != 'Cash_Flow_Template.xls') ? "yes" : "no"
      end
      return display
    end
  end

  def find_folder_by_folder_id(id)
    @sharer=SharedFolder.find(:all,:conditions => ["folder_id = ? and sharer_id = ?",id, current_user.id])
    folder_find_mail_shared(@sharer,@sharer)
    @mail=[]
    return @@mails
  end

  def folder_find_mail_shared(sharers,current)
    if !current.empty?
      sharers.each do |sharer|
        id=sharer.user_id
        @@mails<<User.find(id).email
      end
      folder_find_sub_sharers(sharers)
    end
  end

  def  folder_find_sub_sharers(sharers)
    sub=[]
    @sub1=[]
    sharers.each do |sharer|
      id=sharer.user_id
      fid=sharer.folder_id
      sub = SharedFolder.find(:all,:conditions=>["sharer_id = ? and folder_id = ? and sharer_id != user_id",id,fid])
      @sub1=@sub1+sub
    end
    folder_find_mail_shared(@sub1,sub)
  end

  def find_doc_by_id(id)
    @sharer=SharedDocument.find(:all,:conditions => ["document_id = ? and sharer_id = ?",id, current_user.id])
    doc_find_mail(@sharer)
    return @@mails
  end

  def doc_find_mail(sharers)
    if !sharers.empty?
      sharers.each do |sharer|
        id=sharer.user_id
        @@mails<<User.find(id).email
      end
      doc_find_sub_sharers(sharers)
    end
  end

  def  doc_find_sub_sharers(sharers)
    sub=[]
    sharers.each do |sharer|
      id=sharer.user_id
      doc_id=sharer.document_id
      sub = SharedDocument.find(:all,:conditions => ["document_id = ? and sharer_id = ? and sharer_id != user_id",doc_id, id])
      doc_find_mail(sub)
    end
  end

  def find_folder_sharer(f)
    sharer =  SharedFolder.find(f.id).sharer_id
    return User.find(sharer).email
  end

  def  find_fn_owner(fn)
    d = DocumentName.find(:first,:conditions=>['id = ?',fn])
    return d.user.email
  end

  #Added newly - To find email of the Folder's owner by passing object
  def find_fn_owner_by_obj(fn)
    return fn.user.email
  end

  def find_first_late(properties,chk)
    prp =  properties.detect do  |itr|
      if chk
        ( itr.late_payments_amount_due.nil? || itr.late_payments_amount_due == 0 )
      else
        itr.late_payments_amount_due != 0
      end
    end
    return prp.id
  end

  def prop_occupancy(prop)
    prop.occupancy.nil? ? 0 : prop.occupancy.round(2)
  end

  def fetch_missing_actuals(note_id)
    p = Property.find(note_id)
    f = Folder.find_by_property_id_and_portfolio_id(p.id,p.portfolio_id)
    fetch_folder_of_cashflow(f.id,true)
    @folder_s = @folder_s.blank? ? f.id : @folder_s
    return @folder_s
  end

  def fetch_folder_of_cashflow(folder_id,loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s = '' if (@folder_s.nil? || @folder_s.blank? || loop_starts)
    document_names = ''
    required_fid = ''
    folders.each do |f|
      document_names = f.documents.all(:conditions=>['is_deleted = ?',false]).collect{|x| x.filename}
      if !document_names.empty?  && document_names.include?('Cash_Flow_Template.xls')
        @folder_s = f.parent_id
      else
        fetch_folder_of_cashflow(f.id,false)
      end
    end
    return @folder_s
  end

  def fetch_folder_of_excels(folder_id,loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id],:select=>'id,name,parent_id')
    @folder_s = '' if (@folder_s.nil? || @folder_s.blank? || loop_starts)
    folders.each do |f|
      if !f.name.empty?  && f.name == '2010'
        @folder_s = f.parent_id
      else
        fetch_folder_of_excels(f.id,false)
      end
    end
    return @folder_s
  end

  def fetch_missing_rentroll_folder(note_id,ptype_id)
    if ptype_id == 1
      p = Property.find(note_id)
      f = Folder.find_by_property_id_and_portfolio_id(p.id,p.portfolio_id)
    else
      p = RealEstateProperty.find_real_estate_property(note_id)
      f = Folder.find_by_real_estate_property_id_and_portfolio_id(p.id,p.portfolio_id)
    end
    fetch_folder_of_rentroll(f.id,true)
    @folder_s = @folder_s.blank? ? f.id : @folder_s
    return @folder_s
  end

  def fetch_folder_of_rentroll(folder_id,loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s = '' if (@folder_s.nil? || @folder_s.blank? || loop_starts)
    document_names = ''
    required_fid = ''
    folders.each do |f|
      document_names = f.documents.all(:conditions=>['is_deleted = ?',false]).collect{|x| x.filename}
      if !document_names.empty?  && document_names.include?('Rent_Roll_Template.xls')
        @folder_s = f.parent_id
      else
        fetch_folder_of_rentroll(f.id,false)
      end
    end
    return @folder_s
  end

  def contains_deleted_files(folder)
    folders,documents = find_manage_real_estate_shared_folders('true')
    final_folder_collection = []
    final_doc_collection = []
    if folder != nil
      folders1 = Folder.find(:all,:conditions=>["parent_id = ? and is_deleted = ?",folder.id,true])
      documents1 = Document.find(:all,:conditions=>["folder_id = ? and is_deleted = ?",folder.id,true])
      folders1.each do |f|
        final_folder_collection << f if f.user_id == current_user.id || is_folder_shared_to_current_user(f.id)
        end
      documents1.each do |d|
        final_doc_collection <<  d if d.user_id == current_user.id || is_doc_shared_to_current_user(d.id)
      end
      folders = folders + final_folder_collection
      documents = documents + final_doc_collection
      display =  (folders.empty? && documents.empty?) ? false : true
      return display
    end
  end

  def note_denied(note_id)
    denied_note = PropertyStateLog.find(:last, :conditions=>["user_id = ? && property_id = ? && state_id = ?", current_user, note_id, 6])  #State 6 for note denied
    return denied_note.nil? ? false : denied_note.id
  end

  def resend_request(note_id)
    all_states = PropertyStateLog.find(:all, :conditions=>["user_id = ? && property_id = ?", current_user, note_id]).collect{|x|x.state_id}  #State 4 for requested
    if (!all_states.include?(5) && !all_states.include?(6))
      already_requested = PropertyStateLog.find(:last, :conditions=>["user_id = ? && property_id = ? && state_id = ? && (state_id != ? || state_id != ?)", current_user, note_id, 4, 5, 6])  #State 4 for requested
      return already_requested.nil? ? false : already_requested.id
    else
      return false
    end
  end

  def new_request(note_id)
    all_states = PropertyStateLog.find(:all, :conditions=>["user_id = ? && property_id = ?", current_user, note_id]).collect{|x|x.state_id}  #State 3 for saved, 4 for requested, 5 for confirmed & 6 for denied
    if (!all_states.include?(4) && !all_states.include?(5) && !all_states.include?(6))
      saved_note = PropertyStateLog.find(:last, :conditions=>["user_id = ? && property_id = ? && state_id = ? && state_id != ?", current_user, note_id, 3, 4])  #State 3 for saved note, State 4 for requested
      return saved_note.nil? ? false : saved_note.id
    else
      return false
    end
  end

  #To use to display truncated characters
  def display_truncated_chars(name, len, omission_required)
    if name.nil? || name.blank?
      return ''
    else
      return truncate(name, :omission => "#{omission_required ? '...' : ''}", :length => len)
    end
  end

  #To use to display user friendly dates
  def display_rent_roll_date(date)
    (date.nil? || date.blank?) ? '-' : date.strftime('%b %d, %Y')
  end

  def display_currency(value, precision_count=2)
    if value.nil? || value.blank? || value == 0
      "$0.00"
    elsif value < 0
      value = value.abs
      raw("<font style='color:#CC6633'>-$#{number_with_delimiter(number_with_precision(value, :precision=>precision_count))}</font>")
    else
      "$#{number_with_delimiter(number_with_precision(value, :precision=>precision_count))}"
    end
  end

  def parent_folder_name(folder)
    (!folder.nil? && !folder.parent_id.nil?) ? Folder.find_by_id(folder.parent_id) : nil
  end

  def cal_budget_percentage(a,b)
    c = b - a
    res = ((c/b)*100).to_i rescue ZeroDivisionError
    return  (res <100) ? res : 100
  end

  def find_folder_doc_doc_name_owner(obj_id,obj)
    if obj == "folder"
      owner =  find_folder_owner(obj_id)
    elsif obj == "doc"
      owner =  find_doc_owner(obj_id)
    elsif obj == "doc_name"
      owner=  find_fn_owner(obj_id)
    end
    return owner
  end

  def find_folder_doc_doc_name_sharer(obj_id,obj)
    if obj == "folder"
      sf = SharedFolder.find_by_folder_id(obj_id,:conditions=>["user_id = ? and client_id = ?",current_user.id,current_user.client_id])
      sharer = User.find(sf.sharer_id) if sf != nil
    elsif obj == "doc"
      sd = SharedDocument.find_by_document_id(obj_id,:conditions=>["user_id = ?",current_user.id])
      sharer = User.find(sd.sharer_id) if sd != nil
    end
    return sharer.email if sharer !=nil
  end

  def get_analytics_code
    s = Setting.find_by_name('analytics_code')
    if current_user
      user_defined_code = Setting.find_by_name('user_defined_analytics_code')
      return (s.nil? || s.value.nil? || s.value.empty?) ? "" : raw(s.value + "<script>if (typeof(_gat) == 'object') { try { var pageTrackernew = _gat._getTracker('#{user_defined_code.value}'); pageTrackernew._trackPageview(); pageTrackernew._setVar('customers_#{ current_user.id}_#{current_user.email}'); } catch(err) {} }</script>")
    else
      return (s.nil? || s.value.nil? || s.value.empty?) ? "" : s.value
    end
  end

  def display_graph_values(val)
    val = val.to_i
    if val >= 1000 and val <= 999999
      n = (val/1000).to_i
      return "$"+n.to_s+"K"
    elsif val >= 1000000 and val <= 999999999
      n = (val/1000000).to_i
      return "$"+n.to_s+"M"
    elsif val >= 1000000000 and val <= 9999999999
      n = (val/10000000).to_i
      return "$"+n.to_s+"B"
    else
      return "$"+val.to_s
    end
  end

  #To check if a folder is shared to any
  def check_is_folder_shared(f)
    folder_names = ["Excel Uploads","AMP Files"]
    sf = SharedFolder.find_by_folder_id(f.id,:conditions=>["(user_id = ? or sharer_id =?) and (client_id = #{current_user.client_id})",current_user.id,current_user.id],:select=>'id')  if f
    if (f && sf.nil? && f.user_id != current_user.id)  || (f && f.parent_id != 0 && f.is_master && folder_names.index(f.name) && is_leasing_agent)
      return "false"
    else
      return "true"
    end
  end


  def fetch_missing_actuals_real_estate(note_id)
    p = RealEstateProperty.find_real_estate_property(note_id)
    f = Folder.find_by_real_estate_property_id_and_portfolio_id(p.id,p.portfolio_id)
    fetch_folder_of_cashflow(f.id,true)
    @folder_s = @folder_s.blank? ? f.id : @folder_s
    return @folder_s
  end

  def fetch_excels_folder(note_id)
    if session[:property__id].present? && session[:portfolio__id].blank?
    p = RealEstateProperty.find_real_estate_property(note_id)
    #removed portfolio_id  to solve a nil error..portfolio id is not needed as based on property changes are done..#
    f = Folder.find(:first,:conditions=>['real_estate_property_id =?',p.id],:select=>'id')
    fetch_folder_of_excels(f.id,true)
    @folder_s = @folder_s.blank? ? f.id : @folder_s
    end
    return @folder_s
  end

  def fetch_excel_uploads_folder(note_id)
  if session[:property__id].present? && session[:portfolio__id].blank?
   p = RealEstateProperty.find_real_estate_property(note_id)
    f = Folder.find(:first,:conditions=>['real_estate_property_id =? and portfolio_id = ? and name = ?',p.id,p.portfolio_id,'Excel Uploads'])
    f =Folder.find_by_real_estate_property_id_and_is_master_and_parent_id(p.id,false,0) unless f
    a = f.nil? ? p.id : f.id
    return a
    end
  end

  def select_time_period(period,note_id,partial_page,start_date,timeline_start,timeline_end)
    if params[:start_date] != 0
      @timeline = params[:start_date]
    end
    if (!(request.env['HTTP_REFERER'].nil?) && request.env['HTTP_REFERER'].include?("real_estate") || controller.controller_name == 'real_estates') || (controller.controller_name == 'properties') || (controller.controller_name == "property_acquisitions") || (controller.controller_name == 'performance_review_property') || (controller.controller_name == 'dashboard')
      @note = RealEstateProperty.find_real_estate_property(note_id)
    else
      @note = Property.find(note_id)
    end
    find_dashboard_portfolio_display
    @period = period.to_s
    @time = Time.now
    @date_array = []
    @date_element = []
    @date_month = []
    sd = -6
    ed = 6
    timeline_start_date = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH,'#{@time.to_date}','#{timeline_start.to_date}')  as no_of_months")
    timeline_end_date = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH,'#{timeline_start.to_date}','#{timeline_end.to_date}')  as no_of_months")
    if timeline_start_date["no_of_months"].to_i < sd
      sd = timeline_start_date["no_of_months"].to_i
    end
    if timeline_end_date["no_of_months"].to_i > ed
      ed = timeline_end_date["no_of_months"].to_i
    end
    if @period == "1" or  @period == "4" or @period == "5"  or @period=="6" or @period=="7" or @period == "10" or @period == "11"
      for j in 0 .. timeline_end_date["no_of_months"].to_i
        @date_array << (timeline_start.advance(:months => j).to_date).strftime("%b")+" - "+(timeline_start.advance(:months => j).to_date).strftime("%Y")
        @date_element << (timeline_start.advance(:months => j).to_date).beginning_of_month.strftime("%Y-%m-%d")
      end
    elsif @period == "2"
      @quarter_time = @time.beginning_of_year.advance(:years=>-2)
      i = 1
      (0 .. 36).step(3){ |j|
        @date_array << "Q#{i}"+" - "+(@quarter_time.advance(:months => j).to_date).strftime("%Y")
        @date_element << @quarter_time.advance(:months => j).beginning_of_quarter.strftime("%Y-%m-%d")+" - "+@quarter_time.advance(:months => j).end_of_quarter.strftime("%Y-%m-%d")
        i = i + 1
        i > 4 ? i=1 : i=i
      }
    elsif @period ==  "3" or @period ==  "8"
      @time = @time.beginning_of_year
      for j in -6 .. -1
        @date_array << @time.advance(:years=>j).strftime("%Y")+"  "
        @date_element << (@time.advance(:years => j).to_date).beginning_of_year.strftime("%Y-%m-%d")+" - "+(@time.advance(:years => j).to_date).end_of_year.strftime("%Y-%m-%d")
      end
      @date_array << @time.strftime("%Y")+"  "
      @date_element << @time.strftime("%Y-%m-%d")+" - "+@time.end_of_year.strftime("%Y-%m-%d")
      for k in 1 .. 6
        @date_array << @time.advance(:years=>k).strftime("%Y")+"  "
        @date_element << (@time.advance(:years => k).to_date).beginning_of_year.strftime("%Y-%m-%d")+" - "+(@time.advance(:years => k).to_date).end_of_year.strftime("%Y-%m-%d")
      end
    elsif @period ==  "9"
      @prev_sunday = (Time.now.to_date-Time.now.wday)
      @start_date = (@prev_sunday-(7*7)).strftime("%Y-%m-%d")
      @end_date = (@prev_sunday+(1*7)).strftime("%Y-%m-%d")
       for i in -3...10
#        @date_array << "#{(@start_date.to_date+(i*7)).day}#{(@start_date.to_date+(i*7)).strftime("%b")}"
        @date_array << "#{(@start_date.to_date+(i*7)).day}"
        @date_element << "#{(@start_date.to_date+(i*7)).strftime("%Y-%m-%d")}"
        @date_month << "#{(@start_date.to_date+(i*7)).strftime("%b")}"
      end
    else
      @date = "Select Period"
    end
  end

  def lengthy_word_simplification(word, begin_num=15, end_num=10, sep_char=".",sep_char_repeat=3)
    if word !=nil
      if (begin_num + end_num + sep_char_repeat + 2) < word.length
        return word.slice(0,begin_num).to_s+(sep_char * sep_char_repeat)+word.slice(word.length-end_num,end_num)
      else
        return word
      end
    end
  end

  def find_comment(id,type)
    if type == "folder"
      sf = SharedFolder.find(id)
      comment = sf.nil? ? " " : sf.comments
      return comment
    elsif type == "document"
      sf = SharedDocument.find(id)
      comment = sf.nil? ? " " : sf.comments
      return comment
    end
  end

  def shared_doc_name_doc_comment(id)
    sd = SharedDocument.find_by_document_id(id,:conditions=>["user_id = ? ",current_user.id])
    return sd
  end

  def display_currency_real_estate_overview(value, precision_count=2)
    if (params[:sqft_calc]  == "per_sqft" ||  params[:unit_calc] =='unit_calc') && (params[:partial_page] != "cash_and_receivables" && !params[:cash_find_id] && params[:partial_page] !='cash_and_receivables_for_receivables')
        display_currency_for_persqft(value,precision_count=2)
    else
    return "0" if value.nil? || value.blank? || value == 0
      return "-#{number_with_delimiter(value.round.abs)}" if value < 0
    "#{number_with_delimiter(value.round.abs)}"
    end
  end

  def display_currency_overview(value, precision_count=2)
    if (params[:sqft_calc]  == "per_sqft" ||  params[:unit_calc] =='unit_calc') && (params[:partial_page] != "cash_and_receivables" && !params[:cash_find_id] && params[:partial_page] !='cash_and_receivables_for_receivables')
        display_currency_persqft(value,precision_count=2)
    else
    return "0" if value.nil? || value.blank? || value == 0
      return "-#{number_with_delimiter(value.round.abs)}" if value < 0
    "#{number_with_delimiter(value.round.abs)}"
    end
  end

  def swig_display_currency_real_estate_overview(value, precision_count=2)
    return "$0" if value.nil? || value.blank? || value == 0
    return "-$#{number_with_delimiter(value.round.abs)}" if value < 0
    "$#{number_with_delimiter(value.round.abs)}"
  end

  def swig_rent_roll_display_currency_real_estate_overview(value, precision_count=2)
    return raw("&nbsp;") if value.nil? || value.blank? || value == 0
    return "-#{number_with_delimiter(value.round.abs)}" if value < 0
    "#{number_with_delimiter(value.round.abs)}"
  end

  def display_currency_real_estate_variance(value, precision_count=2)
    if (params[:sqft_calc]  == "per_sqft" ||  params[:unit_calc] =='unit_calc') && (params[:partial_page] != "cash_and_receivables" && !params[:cash_find_id] && params[:partial_page] !='cash_and_receivables_for_receivables')
        display_currency_for_variance_persqft(value,precision_count=2)
    else
    if value.nil? || value.blank? || value == 0 || value .nan?
      "$0"
    elsif value < 0
      "$#{number_with_delimiter(value.round.abs)}"
    else
      "$#{number_with_delimiter(value.round)}"
    end
    end
  end

  def display_currency_variance(value, precision_count=2)
    if (params[:sqft_calc]  == "per_sqft" ||  params[:unit_calc] =='unit_calc') && (params[:partial_page] != "cash_and_receivables" && !params[:cash_find_id] && params[:partial_page] !='cash_and_receivables_for_receivables')
        display_currency_variance_persqft(value,precision_count=2)
    else
    if value.nil? || value.blank? || value == 0 || value .nan?
      "0"
    elsif value < 0
      "#{number_with_delimiter(value.round.abs)}"
    else
      "#{number_with_delimiter(value.round)}"
    end
    end
  end

  def display_currency_real_estate_overview_for_percent_for_exp(value, precision_count=2)
    if value.nil? || value.blank? || value == 0
      "0"
    elsif value < 0
      value = value.abs
      "#{(value.round.abs)}"
    else
      "#{(value.round)}"
    end
  end

  def display_currency_real_estate_variance_for_exp(value, precision_count=2)
    if value.nil? || value.blank? || value == 0
      "0"
    elsif value < 0
      "#{(value.round.abs)}"
    else
      "#{(value.round)}"
    end
  end

  def display_currency_real_estate_overview_for_percent(value, precision_count=2)
    # If any error comes change the data type condition
    if value.class == Float && (value.infinite? || value.nan?)
       "0%"
    elsif value.nil? || value.blank? || value == 0
      "0%"
    elsif value < 0
      value = value.abs
      "#{number_with_delimiter(value.round.abs)}%"
    else
      "#{number_with_delimiter(value.round)}%"
    end
  end

  def display_currency_real_estate_overview_for_percent_variance(value, precision_count=2)
    # If any error comes change the data type condition
    if value.class == Float && (value.infinite? || value.nan?)
       "0%"
    elsif value.nil? || value.blank? || value == 0
      "0%"
    else
      "#{number_with_delimiter(value)}%"
    end
  end

  def display_sqrt_real_estate_overview(value, precision_count=2)
    if value.nil? || value.blank? || value == 0  || value.to_f.nan?
      "0"
    elsif value < 0
      value = value.abs
      "#{number_with_delimiter(value.round.abs)} SF"
    else
      "#{number_with_delimiter(value.round)} SF"
    end
  end

  def display_units(value)
    if value.blank? || value == 0
      "0 Units"
    elsif value == 1
      "1 Unit"
    else
      value < 0  ? "#{number_with_delimiter(value.abs)} Units" : "#{number_with_delimiter(value)} Units"
    end
  end

  def display_currency_persqft(value,precision_count=2)
    return "0" if value.nil? || value.blank? || value == 0
    return "-#{number_with_delimiter(value.round(1).abs)}" if value < 0
      "#{number_with_delimiter(value.round(1))}"
  end

  def  display_currency_variance_persqft(value,precision_count=2)
    if value.nil? || value.blank? || value == 0 || value .nan?
       "0"
     elsif  value < 0
       "#{number_with_delimiter(value.round(1).abs)}"
        else
      "#{number_with_delimiter(value.round(1))}"
      end
    end

  def display_currency_for_persqft(value,precision_count=2)
    return "$0" if value.nil? || value.blank? || value == 0
    return "-$#{number_with_delimiter(value.round(1).abs)}" if value < 0
      "$#{number_with_delimiter(value.round(1))}"
  end

  def  display_currency_for_variance_persqft(value,precision_count=2)
    if value.nil? || value.blank? || value == 0 || value .nan?
       "$0"
     elsif  value < 0
       "$#{number_with_delimiter(value.round(1).abs)}"
        else
      "$#{number_with_delimiter(value.round(1))}"
      end
    end

  def display_rent_analysis_value(value,precision_count=2)
    return "$0" if value.nil? || value.blank? || value == 0
      return "-$#{number_with_delimiter(value.round.abs)}" if value < 0
    "$#{number_with_delimiter(value.round.abs)}"
  end

  def sort_link_helper(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    sel_category = options.delete(:sel_category)
    search_txt = options.delete(:search_txt)
    categories = options.delete(:categories)
    is_primary = options.delete(:is_primary)
    id = options.delete(:id)
    tl_period =  options.delete(:tl_period)
    tl_month =  options.delete(:tl_month)
    tl_year =  options.delete(:tl_year)
    period = options.delete(:period)
    start_date = options.delete(:start_date)
    partial_page = options.delete(:partial_page)
    occupancy_type = options.delete(:occupancy_type) #added for lease sort
    quarter_end_month = options.delete(:quarter_end_month)
    key = parameter
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action => action,:id => id, :sort => key, :page => page ,:per_page => per_page,:sel_category => sel_category,:search_txt => search_txt,:categories => categories,:is_primary=>is_primary,:method=>:get,:start_date =>start_date,:partial_page=> partial_page,:period => period,:tl_period => tl_period,:tl_month => tl_month,:tl_year => tl_year,  :occupancy_type => occupancy_type,:cur_month => params[:cur_month], :cur_year => params[:cur_year],:quarter_end_month=>params[:quarter_end_month] },
    :update => update,
    :loading =>"load_writter();",
    :complete => "load_completer();", :remote=>true
    )
  end

  #To display total value of actuals column in capital improvements in performance review page
  def total_cap_ex_actual(capex)
    return capex.total_cap_ex_act.to_f
    #~ p = capex.tenant_imp_actual.nil? ? 0 : capex.tenant_imp_actual
    #~ q = capex.leasing_comm_actual.nil? ? 0 : capex.leasing_comm_actual
    #~ r = capex.building_imp_actual.nil? ? 0 : capex.building_imp_actual
    #~ s = capex.lease_cost_actual.nil? ? 0 : capex.lease_cost_actual
    #~ t = capex.net_lease_act.nil? ? 0 : capex.net_lease_act
    #~ u = capex.loan_cost_act.nil? ? 0 : capex.loan_cost_act
    #~ return p.to_f+q.to_f+r.to_f+s.to_f+t.to_f+u.to_f
  end

  #To display total value of budget column in capital improvements in performance review page
  def total_cap_ex_budget(capex)
    return capex.total_cap_ex_bud.to_f
    #~ p = capex.tenant_imp_budget.nil? ? 0 : capex.tenant_imp_budget
    #~ q = capex.leasing_comm_budget.nil? ? 0 : capex.leasing_comm_budget
    #~ r = capex.building_imp_budget.nil? ? 0 : capex.building_imp_budget
    #~ s = capex.lease_cost_budget.nil? ? 0 : capex.lease_cost_budget
    #~ t = capex.net_lease_bud.nil? ? 0 : capex.net_lease_bud
    #~ u = capex.loan_cost_bud.nil? ? 0 : capex.loan_cost_bud
    #~ return p.to_f+q.to_f+r.to_f+s.to_f+t.to_f+u.to_f
  end

  def total_cap_ex_variant(capex)
    variant=(capex.total_cap_ex_act.to_f-capex.total_cap_ex_bud.to_f)
    return variant.abs
  end

  def total_cap_ex_percent(capex)
    variant=(capex.total_cap_ex_act.to_f-capex.total_cap_ex_bud.to_f)
    percent=(variant*100)/capex.total_cap_ex_bud.to_f
    return percent.abs
  end

  def sqft_total(sqrt,rent_roll_swig)
   rent_roll_swig.each do |rl |
     sqrt += rl.rentable_sqft.to_f.round
   end
   return sqrt
  end

  def base_rent_total(base,rent_roll_swig)
   rent_roll_swig.each do |rl |
     base +=rl.base_rent.to_f.round
   end
   return base
  end

  def effective_rent_total(effective,rent_roll_swig)
   rent_roll_swig.each do |rl |
     effective +=rl.effective_rate.to_f.round
   end
   return effective if effective != 0
   return raw("&nbsp;")
  end

  def ti_total(ti,rent_roll_swig)
   rent_roll_swig.each do |rl |
     ti += rl.tenant_improvements.to_f
   end
   return ti
  end

  def li_total(lc,rent_roll_swig)
   rent_roll_swig.each do |rl |
     lc += rl.leasing_commisions.to_f
   end
   return lc
  end

  def sd_total(sd,rent_roll_swig)
   rent_roll_swig.each do |rl |
     sd += rl.other_deposits.to_f
   end
   return sd
  end

  def find_sorting_image(params,column, pdf_path= '')
    if params[:sort] && params[:sort].downcase.include?("desc") && params[:sort].downcase.include?(column)
      img = raw("<img class='marginL5' src='#{pdf_path}/images/bulletarrowdown.png' width='7' height='5' />")
    elsif  params[:sort] && params[:sort].split(" ")[1] == nil && params[:sort].downcase.include?(column)
      img = raw("<img class='marginL5' src='#{pdf_path}/images/bulletarrowup.png' width='7' height='5' />")
    else
      img = raw("<img class='marginL5' src='#{pdf_path}/images/bulletarrowdown.png' width='7' height='5' />")
    end
  end

  def sort_link_helper_for_rent_roll(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    is_primary = options.delete(:is_primary)
    portfolio_id = options.delete(:portfolio_id)
    partial_page = options.delete(:partial_page)
    id = options.delete(:id)
    tl_year = options.delete(:tl_year)
    tl_month = options.delete(:tl_month)
    tl_period = options.delete(:tl_period)
    quarter_end_month = options.delete(:quarter_end_month)
    key = parameter
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:sort => key, :partial_page => partial_page, :page => page ,:per_page => per_page,:portfolio_id => portfolio_id,:id => id, :tl_year=>tl_year,:tl_month=>tl_month,:tl_period=>tl_period,:quarter_end_month=>:quarter_end_month},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();", :remote=>true
    )
  end

  def swig_sort_link_helper_for_rent_roll(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    is_primary = options.delete(:is_primary)
    partial_page = options.delete(:partial_page)
    portfolio_id = options.delete(:portfolio_id)
    id = options.delete(:id)
    tl_year = options.delete(:tl_year)
    tl_month = options.delete(:tl_month)
    tl_period = options.delete(:tl_period)
    quarter_end_month = options.delete(:quarter_end_month)
    rent_roll_filter = options.delete(:rent_roll_filter)
    key = parameter
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:sort => key, :page => page ,:per_page => per_page, :partial_page => partial_page,:portfolio_id => portfolio_id,:id => id, :tl_year=>tl_year,:tl_month=>tl_month,:tl_period=>tl_period,:rent_roll_filter => params[:rent_roll_filter],:cur_month => params[:cur_month], :cur_year => params[:cur_year],:quarter_end_month=>params[:quarter_end_month]},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();", :remote=>true
    )
  end

  def sort_link_properties_files(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    partial_page = options.delete(:partial_page)
    is_primary = options.delete(:is_primary)
    portfolio_id = options.delete(:portfolio_id)
    pid = portfolio_id
    data_hub="asset_data_and_documents"
    id = "asset_docs"
    period = options.delete(:period)
    key = parameter
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
    order = " DESC" if params[:sort] == parameter
    order = " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:sort => key, :page => page ,:per_page => per_page,:portfolio_id => portfolio_id,:period => period, :order => order, :partial_page=>partial_page,:pid => pid,:data_hub=>data_hub,:id=>id},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();",
      :remote=>true
    )
  end

  def sort_link(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    partial_page = options.delete(:partial_page)
    is_primary = options.delete(:is_primary)
    portfolio_id = options.delete(:portfolio_id)
    id = options.delete(:id)
    period = options.delete(:period)
    if params[:sort].nil?
      key = "#{parameter} DESC"
    else
      key = parameter
    end
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
    order = " DESC" if params[:sort] == parameter
    order = " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:sort => key, :page => page ,:per_page => per_page,:portfolio_id => portfolio_id,:period => period, :order => order, :partial_page=>partial_page},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();",
      :remote=>true
    )
  end

  #To display texts next to the count in performance review tabs.Count of the collection and the text to be displayed are passed as arguments
  def display_text_for_counts(val,txt)
    if val == 1
      return txt
    elsif val > 1
      return txt.pluralize
    else
      return ""
    end
  end

  #To display tenants name without any special characters in the start and end
  def display_tenant_name(tnt)
    res = tnt.match(/^[^a-zA-Z\d]+/)
    if !res.nil?
      tnt_name = tnt[1..-1]
      return tnt_name
    else
      return raw("&nbsp;")
    end
  end

  def get_google_key
    return Setting.find_by_name("google_key").value
  end

  def bread_crum_cash(targ, result = [])
    data = IncomeAndCashFlowDetail.find(targ)
    unless data.nil?
      result << "#{data.id}----#{data.title}"
      bread_crum_cash(data.parent_id,result) if !data.parent_id.nil?
    end
    result
  end

  def wres_bread_crum_cash(targ, result = [])
    data = PropertyCashFlowForecast.find(targ)
    unless data.nil?
      result << "#{data.id}----#{data.title}"
      wres_bread_crum_cash(data.parent_id,result) if !data.parent_id.nil?
    end
    result
  end

  def display_collaborators_new(members,obj,obj_id,j,leasing_agent)
    z_ind = j
    len = members.uniq.length
    if len == 1
      if members.first !=nil
        owner = find_folder_doc_doc_name_owner_name(obj_id,obj)
        sharer = find_folder_doc_doc_name_sharer_name(obj_id,obj)
        members_first_display = members.first.name.nil? ||  members.first.name.blank? ? members.first.email : members.first.name
        sharer_display = sharer.name.nil?  ||  sharer.name.blank? ? sharer.email : sharer.name if sharer != nil
        if current_user.has_role?('Leasing Agent') || leasing_agent == 'true'
            if sharer && sharer.has_role?('Leasing Agent')
                r =  sharer.email == current_user.email ? members_first_display : sharer_display
            else
                r =  owner.email == current_user.email ? members_first_display : members_first_display
              end
        else
              r =  sharer.email == current_user.email ? members_first_display : sharer_display if sharer != nil
              r =  owner.email == current_user.email ? members_first_display : members_first_display if sharer == nil
        end
        @object = obj
        @object_id = obj_id
        @display_tooltip = r
        @zz_index = z_ind
        r = raw("<span onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{display_truncated_chars(r,20,true)}</span>")
      end
      return r
    elsif len == 2
      if members.first !=nil && members[1] !=nil
        owner = find_folder_doc_doc_name_owner_name(obj_id,obj)
        sharer = find_folder_doc_doc_name_sharer_name(obj_id,obj)
        members_first_display = members.first.name.nil?  || members.first.name.blank? ? members.first.email : members.first.name
        members_second_display = members[1].name.nil? || members[1].name.blank? ? members[1].email : members[1].name
        second_mail =  sharer.email == members.first.email ? members_second_display : members_first_display if sharer != nil
        sharer_email = (sharer.name.nil? || sharer.name.blank?) ? sharer.email : sharer.name if !sharer.nil?
        if current_user.has_role?('Leasing Agent') || leasing_agent == 'true'
            if sharer && sharer.has_role?('Leasing Agent')
                r =  sharer == current_user.name ? "#{members_first_display} & #{members_second_display}" :   "#{sharer_email} & #{second_mail}" if sharer != nil
             else
                r =  owner == current_user.name ? "#{members_first_display} & #{members_second_display}" :   "#{members_first_display} & #{members_second_display}"
             end
        else
          r =  sharer == current_user.name ? "#{members_first_display} & #{members_second_display}" :   "#{sharer_email} & #{second_mail}" if sharer != nil
          r =  owner == current_user.name ? "#{members_first_display} & #{members_second_display}" :   "#{members_first_display} & #{members_second_display}" if sharer == nil
        end
        name_display = r.split("&")
        full_name_display = name_display[0] +"<br>" + name_display[1]
        @object = obj
        @object_id = obj_id
        @display_tooltip = full_name_display
        @zz_index = z_ind
        r = raw("<span onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{display_truncated_chars(r,20,true)}</span>")
      end
      return r
    elsif len > 2
      others = members.collect{|x| x if x !=nil}
      if members.first !=nil
        owner = find_folder_doc_doc_name_owner_name(obj_id,obj)
        sharer = find_folder_doc_doc_name_sharer_name(obj_id,obj)
        if sharer != nil
          others =  members.reject{|m| m == sharer}
        end
        if owner == current_user
          others =  members.reject{|m| m == members.first} if members.first !=nil
        end
        others = others.compact.collect{|u| (u.name.nil? || u.name.blank?) ? u.email : u.name}
        others = others.uniq.join('<br>')
        members_first_display = members.first.name.nil?  || members.first.name.blank? ? members.first.email : members.first.name
        members_first_display_with_out_truncation = members_first_display
        members_first_display =  display_truncated_chars(members_first_display,13,true)
        if sharer != nil
          sharer_display = sharer.name.nil?  || sharer.name.blank? ? sharer.email : sharer.name
          sharer_display_with_out_truncation = sharer_display
          sharer_display =  display_truncated_chars(sharer_display,13,true)
        end
        if sharer != nil
          if sharer.email == current_user.email
            others = "#{members_first_display_with_out_truncation}<br>" + others
          elsif  is_leasing_agent || leasing_agent == 'true'
            others = "#{sharer_display_with_out_truncation}<br>" + others if sharer.has_role?('Leasing Agent')
          else
            others = "#{sharer_display_with_out_truncation}<br>" + others
          end
        else
          others = "#{members_first_display_with_out_truncation}<br>" + others if !others.include?(members_first_display_with_out_truncation)
        end
        @object = obj
        @object_id = obj_id
        @display_tooltip = others
        @zz_index = z_ind
        r =  sharer.email == current_user.email || (!sharer.has_role?('Leasing Agent') && (current_user.has_role?('Leasing Agent') || (leasing_agent == 'true')))   ?   "<span onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{members_first_display} & #{len-1} others</span>" : "<span  onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{sharer_display} & #{len-1} others</span>" if sharer != nil
        r =  owner.email == current_user.email ?   "<span onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{members_first_display} & #{len-1} others</span>" : "<span  onmouseout=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','none');\" onmouseover=\"jQuery('#tooltip_#{obj}_#{obj_id}').css('display','block');\">#{members_first_display} & #{len-1} others</span>" if sharer == nil
      end
      return raw(r)
    else
    end
  end

  def find_folder_doc_doc_name_sharer_name(obj_id,obj)
    if obj == "folder"
      sf = SharedFolder.find_by_folder_id(obj_id,:conditions=>["user_id = ? and sharer_id != ? and client_id =?",current_user.id,current_user.id,current_user.client_id])
      sharer = User.find(sf.sharer_id) if sf != nil && User.exists?(sf.sharer_id)
    elsif obj == "doc"
      sd = SharedDocument.find_by_document_id(obj_id,:conditions=>["user_id = ? and sharer_id != ?",current_user.id,current_user.id])
      sharer = User.find(sd.sharer_id) if sd != nil && User.exists?(sd.sharer_id)
    end
    return sharer
  end

  def find_folder_doc_doc_name_owner_name(obj_id,obj)
    if obj == "folder"
      owner =  find_folder_owner_name(obj_id)
    elsif obj == "doc"
      owner =  find_doc_owner_name(obj_id)
    end
    return owner
  end

  def find_folder_owner_name(folder_id)
    user = Folder.find(folder_id).user
    return user
  end

  def find_doc_owner_name(doc_id)
    user = Document.find(doc_id).user
    return user
  end

  def find_access_given_by(user)
    a =  raw("AMP Administrator <br/> <a href='mailto:praveeny@theamp.com'>praveeny@theamp.com</a><br/>on #{user.created_at.strftime("%b%d, %Y.")}")
    return a
  end

  def goto_asset_view_path(user)
    #~ all_portfolios = Portfolio.find_shared_and_owned_portfolios(current_user.id)
    all_portfolios = Portfolio.find_portfolios(current_user)
    last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
    portfolio_id = params[:real_estate_id].present? ? params[:real_estate_id].to_i : params[:portfolio_id].present? ? params[:portfolio_id].to_i : params[:pid].present? ? params[:pid].to_i : (params[:id].present? && params[:action].eql?("add_property")) ? params[:id].to_i : session[:portfolio__id].present? ? session[:portfolio__id].to_i : last_portfolio.try(:id)
    portfolio_obj = Portfolio.find_by_id(portfolio_id)
    #~ prop = RealEstateProperty.find_owned_and_shared_properties(portfolio_obj,current_user.try(:id),prop_folder=nil).try(:first) if portfolio_obj.present?
    prop = RealEstateProperty.find_properties_of_portfolio(portfolio_obj.id).try(:last) if portfolio_obj.present? rescue nil
    property_id = (params[:id].present? && params[:action].eql?("show")) ? params[:id] : (params[:access].blank? && params[:property_id].present?) ? params[:property_id].to_i : (params[:id].present? && !params[:action].eql?("add_property")) ? params[:id].to_i : params[:nid].present? ? params[:nid].to_i : prop.present? ? prop.try(:id) : first_property.try(:id)
    property = RealEstateProperty.find_by_id(property_id.to_i)
    if session[:portfolio_id].present? && session[:property_id].present? && !is_leasing_agent
      return real_estate_property_path(session[:portfolio_id].to_i,session[:property_id].to_i)
    elsif session[:portfolio__id].present? && session[:property__id].blank? && !params[:action].eql?("page_error") && !params[:action].eql?("scribd_view") && !is_leasing_agent
      #~ port_id = (params[:id].present? && (params[:action].eql?("add_property")) ) ? params[:id].to_i : session[:portfolio__id]
      #~ prop_id = Portfolio.find_by_id(port_id).try(:real_estate_properties).try(:first).try(:id)
      find_dashboard_portfolio_display

      if @note.class.eql?(Portfolio) #&& portfolio_id.present? && property_id.present?
        portfolio_id = @note.id
        property_id = prop.try(:id) #RealEstateProperty.find_owned_and_shared_properties(@note,current_user.id,prop_folder=nil).try(:first).try(:id)
        #~ property_id = @note.try(:real_estate_properties).try(:first).try(:id)
      end
      return real_estate_property_path(portfolio_id,property_id,:portfolio_selection=>true)

    elsif session[:portfolio__id].blank? && session[:property__id].present? && !is_leasing_agent
      port_id = params[:real_estate_id].present? ? params[:real_estate_id] : params[:portfolio_id].present? ? params[:portfolio_id] : params[:pid].present? ? params[:pid] : (params[:id].present? && params[:action].eql?("add_property")) ? params[:id] : last_portfolio.try(:id)
      prop_id = (params[:property_id].present? && params[:access].blank?) ? params[:property_id] : params[:nid].present? ? params[:nid] : (params[:id].present? && params[:controller].eql?("properties") && params[:action].eql?("show")) ? params[:id] : first_property.try(:id)
      return real_estate_property_path(port_id,prop_id,:property_selection=>true)
    elsif params[:portfolio_id].present? && params[:property_id].present? && params[:access].blank? && !is_leasing_agent
      return real_estate_property_path(params[:portfolio_id],params[:property_id])
    elsif params[:real_estate_id].present? && params[:id].present? && !is_leasing_agent
      return real_estate_property_path(params[:real_estate_id],params[:id])
    elsif params[:id].present? && params[:property_id].present? && !is_leasing_agent
      return real_estate_property_path(params[:id],params[:property_id])
    else
      #~ portfolio_type=PortfolioType.find_by_name('Real Estate')

      #~ portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', user,portfolio_type.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]],:order=>"id desc")
      #~ property = RealEstateProperty.find(:first, :conditions=>["portfolio_id IN (?) and property_name not in (?)", portfolios.collect{|x|x.id},["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]], :order=>"id desc") if !portfolios.nil? && !portfolios.empty?

      shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
      shared_portfolios = Portfolio.find(:all, :conditions => ["id in (?)",shared_folders.collect{|x| x.portfolio_id}]) if !(shared_folders.nil? || shared_folders.blank?)
      shared=  SharedFolder.find(:last,:conditions=>['is_property_folder = ? and user_id = ? and client_id = ?',true,current_user.id,current_user.client_id]) if !(shared_portfolios.nil? || shared_portfolios.blank?)
      shared_property = shared.folder.real_estate_property unless shared.nil? || shared.blank?
      if is_leasing_agent || controller.controller_name != "real_estates"
        if (!property.nil? && shared_property.nil?) || (!shared_property.nil? && property && shared_property.created_at < property.created_at)
          if is_leasing_agent
            session[:pipeline] = "/show_pipeline"
            session[:collab_val] = ""
            return "/lease/show_pipeline/#{property_id}"
          else
            return real_estate_property_path(portfolio_id,property_id)
          end
        elsif !(shared_property.nil?)
          if is_leasing_agent
            session[:pipeline] = "/show_pipeline"
            session[:collab_val] = ""
            return "/lease/show_pipeline/#{shared_property.id}"
          else
            return real_estate_property_path(shared_property.portfolio_id,shared_property.id,:prop_folder=>true)
          end
        else
          if is_leasing_agent
            #~ session[:collab_val] = "/collaboration_hub"
            #~ session[:pipeline] = ""
            #~ return "/collaboration_hub?property_id=#{last_prop_id}"
             return '/collaboration_hub'
          else
            flash.now[:error] = 'Add a property to go to Property'
            return "/portfolios?from_view=true"
          end
        end
      else
        if @portfolio.present?
          return real_estate_property_path(@portfolio.id,first_property.try(:id))
        elsif @portfolios.try(:first).try(:real_estate_properties).blank?
          flash.now[:error] = 'Add a property to go to Property'
          return "/portfolios?from_view=true"
        else
          return real_estate_property_path(@portfolios.try(:first).try(:id),first_property.try(:id))
        end
      end
    end
  end

  def explanation_finder(id, doc, month, status)
    IncomeCashFlowExplanation.find(:first, :conditions=>['income_and_cash_flow_detail_id = ? and month= ? and ytd= ?', id, month, status])
  end

  def cap_explanation_finder(id, doc, month, status)
    CapitalExpenditureExplanation.find(:all, :conditions=>['property_capital_improvement_id = ? and month= ? and ytd= ?', id, month, status])
  end

  def show_portfolios
    @user = current_user
    @portfolios = current_user.portfolios.find(:all,:order=>"id desc")
    @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
    @portfolios +=  Portfolio.find(:all, :conditions => ["id in (?)",@shared_folders.collect {|x| x.portfolio_id}]) if !(@shared_folders.nil? || @shared_folders.blank?)
    render :update do |page|
      page.replace_html  "show_assets_list",:partial=>"/collaboration_hub/collaboration_overview"
    end
  end

  def display_image_for_user(user_id)
    image = PortfolioImage.find_by_attachable_id_and_attachable_type(user_id,'User',:conditions=>['filename != ? ','login_logo'])
    return !image.nil? ? image.public_filename : "/images/user.jpeg"
  end

  def display_image_for_user_add_collab(user_id)
    image = PortfolioImage.find_by_attachable_id_and_attachable_type(user_id,'User',:conditions=>['filename != ?','login_logo'])
    return !image.nil? ? image.public_filename : "/images/adduserx_collab_dummy.jpg"
  end


  def count_var_explained_by_user(doc, month, user_id)
    ice = IncomeCashFlowExplanation.find(:last, :conditions=>['document_id = ? and month = ? and user_id = ?', doc, month, user_id])
    @explained_on = ice.updated_at.strftime("%b %d").downcase if ice
    IncomeCashFlowExplanation.count(:all, :conditions=>['document_id = ? and month = ? and user_id = ?', doc, month, user_id])
  end

  def count_var_expenditure_explained_by_user(doc, month, user_id)
    cec = CapitalExpenditureExplanation.find(:last, :conditions=>['document_id = ? and month = ? and user_id = ?', doc, month, user_id])
    @explained_on = cec.updated_at.strftime("%b %d").downcase if cec
    CapitalExpenditureExplanation.count(:all, :conditions=>['document_id = ? and month = ? and user_id = ?', doc, month, user_id])
  end

  def find_bar_color(use_color,act,bud)
    c = act == 0 && bud == 0 ? '' : use_color
    return c
  end

  def find_property_folder(folder)
    prop_folder = SharedFolder.find_by_folder_id_and_is_property_folder_and_user_id_and_client_id(folder.id,true,current_user.id,current_user.client_id)
    return prop_folder
  end

  def find_property_shared(note)
    prop_folder = SharedFolder.find_by_real_estate_property_id_and_is_property_folder_and_user_id_and_client_id(note.id,true,current_user.id,current_user.client_id)
    return prop_folder
  end

  def find_property_sharer(note)
    prop_folder = SharedFolder.find_by_real_estate_property_id_and_is_property_folder_and_sharer_id(note.id,true,current_user.id)
    return prop_folder
  end

  def check_user_own_portfolio
    user_own_portfolio = Portfolio.find(:all, :conditions=>["user_id = ?  and portfolio_type_id = 2 and name not in (?)", current_user,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=>'created_at DESC')
    return user_own_portfolio
  end

  def check_user_owned_for_portfolio(id)
    user_owned_portfolio = Portfolio.find_by_id_and_user_id(id,current_user.id)
    return user_owned_portfolio
  end

  def property_count(value)
    if value > 1
      return "#{value}"
    else
      return "#{value == 0 ? 'No' : value }"
    end
  end

  #called from properties/folder_row
  def file_count(value)
    value = value.to_i if value.class == String
    if value == 1
      "#{value} File"
    else
      "#{value} Files"
    end
  end

  def finding_shared_folders_portfolios
    @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
    @ids = @shared_folders.collect {|x| x.portfolio_id}
    @portfolios+= Portfolio.find(:all, :conditions => ["id in (?) and name not in (?)",@ids,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]]) if !(@shared_folders.nil? || @shared_folders.blank?)
  end

  def show_asset_docs_folder_needed(id)
    folder = Folder.find(id)
    shared_folder = SharedFolder.find(:all, :conditions=>["folder_id = ? and user_id = ? and sharer_id = ? and client_id = ?",folder.id,current_user.id,folder.user_id])
    if (folder.parent_id == 0 and folder.name == "my_files") or !(shared_folder.nil?)
      return false
    else
      return true
    end
  end

  #~ #To find shared folders,docs,tasks

  def find_manage_real_estate_shared_folders(find_deleted_folders)
    @show_deleted = (params[:del_files] == 'true') ? true : false
    conditions =  @show_deleted == true ?   "" : "and is_deleted = false"
    conditions = find_deleted_folders == 'true' ? "and is_deleted = true" : conditions
    #.............................shared folders collection .........................
    unless params[:user] == 'false'
      if params[:deal_room] == 'true'
        tmp = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ?",current_user.id,current_user.client_id]).select{|sf| sf.folder.portfolio.try(:name) == 'portfolio_created_by_system_for_deal_room'}
        s = tmp.collect{|sf| sf.folder_id}
      else
        tmp = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ?",current_user.id,current_user.client_id]).select{|sf| sf.folder.portfolio.try(:name) != 'portfolio_created_by_system_for_deal_room'}
        s = tmp.collect{|sf| sf.folder_id}
      end
    else
      cur_user = Portfolio.find(params[:pid]).user
      if params[:deal_room] == 'true'
        tmp = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ?",cur_user.id,cur_user.client_id]).select{|sf| sf.folder.portfolio.name == 'portfolio_created_by_system_for_deal_room'}
        s = tmp.collect{|sf| sf.folder_id}
      else
        tmp = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ?",cur_user.id,cur_user.client_id]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
        s = tmp.collect{|sf| sf.folder_id}
      end
    end
     #~ fs = Folder.find(:all,:conditions=>["id in (?) and parent_id not in (?) #{conditions} and (real_estate_property_id is NOT NULL or parent_id = -1 )",s,s]).collect{|f| f.id}
    fs = Folder.find(:all,:conditions=>["id in (?) and parent_id not in (?) #{conditions} and (real_estate_property_id is NOT NULL or parent_id != -1 ) and parent_id!=0",s,s]).collect{|f| f.id}
    if params[:user] == 'false'
      @shared_folders_real_estate = SharedFolder.find(:all,:conditions=>["user_id = ? and folder_id in (?) and (is_property_folder != 1 || is_property_folder is null) and client_id = ?",cur_user.id,fs,cur_user.client_id])
    else
      @shared_folders_real_estate = SharedFolder.find(:all,:conditions=>["user_id = ? and folder_id in (?) and (is_property_folder != 1 || is_property_folder is null) and client_id = ?",current_user.id,fs,current_user.client_id])
    end
    unless params[:user] == 'false'
      if params[:deal_room] == 'true'
        sd1 = SharedDocument.find(:all,:conditions=>["user_id = ? ",current_user.id]).select{|sd| sd.folder.portfolio.name == 'portfolio_created_by_system_for_deal_room'}
        sd2 = SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",current_user.id,s]).select{|sd| sd.folder.portfolio.name == 'portfolio_created_by_system_for_deal_room'}
        sdocs1 = sd1.collect{|sd| sd.document_id}
        sdocs2 = sd2.collect{|sd| sd.document_id}
        shared_docs_ids = s.empty? ? sdocs1   : sdocs2
      else
        if s.empty?
          tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? ",current_user.id]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
          shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
        else
          tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",current_user.id,s]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
          shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
        end
        #      shared_docs_ids = s.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? ",current_user.id]).collect{|sd| sd.document_id}   : SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",current_user.id,s]).collect{|sd| sd.document_id}
      end
      @shared_folders_real_estate = @shared_folders_real_estate.collect{|sf| sf.folder if sf.folder.real_estate_property.try(:user_id) != current_user.id && sf.folder.try(:portfolio).try(:user_id) != current_user.try(:id)}.compact
      #.............................shared docs collection .........................
      documents_ids = Document.find(:all,:conditions=>["id in (?) #{conditions} and real_estate_property_id is NOT NULL ",shared_docs_ids]).collect{|d| d.id}
      shared_docs = shared_docs_ids.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",current_user.id,documents_ids]) :  s.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",current_user.id,documents_ids]) : SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?) and document_id in (?)",current_user.id,s,documents_ids])
      @shared_docs_real_estate = shared_docs.collect{|sd| sd.document if sd.folder && sd.folder.real_estate_property.user_id != current_user.id && sd.folder.portfolio.user_id != current_user.id}.compact
         else
      if params[:deal_room] == 'true'
        sd1 = SharedDocument.find(:all,:conditions=>["user_id = ? ",cur_user.id]).select{|sd| sd.folder.portfolio.name == 'portfolio_created_by_system_for_deal_room'}
        sd2 = SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",cur_user.id,s]).select{|sd| sd.folder.portfolio.name == 'portfolio_created_by_system_for_deal_room'}
        sdocs1 = sd1.collect{|sd| sd.document_id}
        sdocs2 = sd2.collect{|sd| sd.document_id}
        shared_docs_ids = s.empty? ? sdocs1   : sdocs2
      else
        if s.empty?
          tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? ",cur_user.id]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
          shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
        else
          tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",cur_user.id,s]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
          shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
        end
        #      shared_docs_ids = s.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? ",current_user.id]).collect{|sd| sd.document_id}   : SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",current_user.id,s]).collect{|sd| sd.document_id}
      end
      @shared_folders_real_estate = @shared_folders_real_estate.collect{|sf| sf.folder if sf.folder.real_estate_property.user_id != cur_user.id && sf.folder.portfolio.user_id != cur_user.id}.compact
      #.............................shared docs collection .........................
      documents_ids = Document.find(:all,:conditions=>["id in (?) #{conditions} and real_estate_property_id is NOT NULL ",shared_docs_ids]).collect{|d| d.id}
      shared_docs = shared_docs_ids.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",cur_user.id,documents_ids]) :  s.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",cur_user.id,documents_ids]) : SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?) and document_id in (?)",cur_user.id,s,documents_ids])
      @shared_docs_real_estate = shared_docs.collect{|sd| sd.document if sd.folder && sd.folder.real_estate_property.user_id != cur_user.id && sd.folder.portfolio.user_id != cur_user.id}.compact
    end
    return   @shared_folders_real_estate,@shared_docs_real_estate
  end


  #....................................To display breadcrumb ....................................................................................................................
  def breadcrump_display_asset_manager_real_estate(folder,event)
    @from_event = event == 'true' ? 'true' : 'false'
    portfolio_folder = Folder.find_by_portfolio_id_and_parent_id(folder.portfolio_id,-1) if folder
    pid = params[:portfolio_id] ? params[:portfolio_id]  :  params[:pid]
    portfolio_folder = Folder.find_by_portfolio_id_and_parent_id(pid,-1) if (params[:portfolio_id] || params[:pid] )
    img = "<div class='breadicon'><img border='0' width='18' height='18' src='/images/collaboration_hub_new_floder.png'></div>"
    if folder && portfolio_folder.nil?
      breadcrump_display_my_files_asset_manager_real_estate(folder)
    else
      arr =[]
      i = 0
      #--------------------------------------------loop to find shared/own folders start----------------------------------------------------------------
      while !folder.nil?  && params[:parent_delete] != "true"
        property_folder  = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(folder.real_estate_property_id,0,0)
        #------------------------------------------to find path folder strucure/shared items------------------------------------------------------------
        find_path_for_breadcrumb(folder)
        #--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if (request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?('properties') && request.env['HTTP_REFERER'].include?('real_estate')) || (request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?('lease') && request.env['HTTP_REFERER'].include?('show_pipeline'))
          tmp_name = "#{img unless (property_folder==folder)}<div class='bread'>#{@path}</div>"
          name = (i == 0) ? "#{img unless (property_folder==folder)}<div class='bread1'>#{truncate_extra_chars(folder.name)}</div>" :  "#{tmp_name}"
          arr << name
        elsif portfolio_folder
          if folder.name != portfolio_folder.name
            tmp_name = "#{img}<div class='bread'>#{@path}</div>"
            name = (i == 0) ? "#{img}<div class='bread1'>#{truncate_extra_chars(folder.name)}</div>" :  "#{tmp_name}"
            arr << name     if  !is_folder_shared_to_current_user(folder.id).nil?  || folder.user_id == current_user.id
          end
        end
        folder = Folder.find(:first,:conditions=> ["id = ?",folder.parent_id])
        i += 1
      end
      #-------------------------------------------loop ends-------------------------------------------------------------------------------------------------------------
      #............................................To display portfolios/my files&tasks in breadcrumb-------------------------------------------
      if (!(request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?('properties') && request.env['HTTP_REFERER'].include?('real_estate'))  && !(request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?('lease') && request.env['HTTP_REFERER'].include?('show_pipeline'))) || params[:parent_delete] == "true"

          portfolios = Portfolio.find_portfolios(current_user)
          portfolio_ids = portfolios.present? ? portfolios.map(&:id) : []
          port_access_var = portfolio_ids.include?(portfolio_folder.try(:portfolio).try(:id).to_i)

        prop_link = @folder && @folder.parent_id == -1 || (@folder.nil?) ? "<font color='#222222'>#{portfolio_folder.name}</font>" : (current_user.has_role?("Shared User") || !port_access_var) ? "<font color='#222222'>#{portfolio_folder.name}</font>" : "<a href='#' onclick=\"load_writter();new Ajax.Request('/properties/show_asset_files?folder_id=#{portfolio_folder.id}&pid=#{portfolio_folder.portfolio.id}&hide_var=true',{ onComplete: function(request){ load_completer();
        }});return false;\">#{portfolio_folder.name}</a>"  if portfolio_folder
        #..................................to find shared property folders ......................................
        shared_property_folders = []
        portfolio_folder.try(:portfolio).try(:real_estate_properties).each do |p|
          p_folder  = Folder.find_by_real_estate_property_id_and_parent_id(p.id,0)
          if @folder && @folder.parent_id != -1
            shared_property_folders << SharedFolder.find_by_folder_id_and_user_id_and_real_estate_property_id_and_client_id(p_folder.id,current_user.id,@folder.real_estate_property_id,current_user.client_id) if p_folder
          else
            shared_property_folders << SharedFolder.find_by_folder_id_and_user_id_and_client_id(p_folder.id,current_user.id,current_user.client_id) if p_folder
          end
        end
        #...................................................................................................................................
        if portfolio_folder  && (portfolio_folder.user_id != current_user.id)  && shared_property_folders.compact.empty?
          arr << "<div class='bread'><a href='' onclick=\"show_collaboration_overview();change_color('overview_tab');return false;\">My Files </a></div>"
        end
        if (portfolio_folder && !shared_property_folders.compact.empty?) ||  portfolio_folder.user_id == current_user.id
          arr << "<div class='bread' style='display:none;'><a href='' onclick=\"show_collaboration_overview();change_color('overview_tab');return false;\">My Files </a></div>
      <div class='saprater' style='display:none;'>></div>#{img}<div class='bread'>#{prop_link}</div>"
        end
      end
      #.............................................................................................................................................................................
      new_arr=arr.reverse
      new_a=[]
      new_arr.each_with_index do|a,i|
        if i==0
          new_a << a
        else
          #~ if params[:show_missing_file].present? || params[:nid].present?
          if (!params[:data_hub].present? || params[:nid].present? || params[:show_missing_file].present? || params[:folder_name].present? || params[:del_files])
          new_a << "<div style='float:left;'><div class='saprater' style='margin-right:0px;'>></div>"+a+"</div>"
          end
        end
      end
      return raw(new_a.join)
      #~ return arr.reverse.join("<div class='setupiconrow3' style='margin-right:0px;'><img width='10' height='9' src='/images/eventsicon2.png' style='margin-top:-3px;'></div>")
    end
  end

  #............................................To find path of the breadcrumb......................................
  def  find_path_for_breadcrumb(folder)
    @path = params[:bulk_upload] == 'true' ? "<a href='' onclick=\"show_hide_asset_docs1_real_estate(#{folder.portfolio_id},#{folder.id},'hide_del');return false;\">#{truncate_extra_chars(folder.name.titleize)}</a>" : (params[:show_past_shared] == 'true' ? (params[:deal_room] == 'true' ? "<a href='' onclick=\"load_writter();show_shared_items('#{folder.id}','#{folder.portfolio_id}','true');load_completer();return false;\">#{truncate_extra_chars(folder.name.titleize)}</a>" : "<a href='' onclick=\"load_writter();show_shared_items('#{folder.id}','#{folder.portfolio_id}','false');load_completer();return false;\">#{truncate_extra_chars(folder.name)}</a>" ) : @from_event == 'true' ?  "<a href='' onclick=\"load_writter();show_events('#{folder.id}');load_completer();return false;\">#{truncate_extra_chars(folder.name)}</a>" :(params[:deal_room] == 'true' ? "<a href='' onclick=\"load_writter();new Ajax.Request('/properties/show_asset_files?folder_id=#{folder.id}&pid=#{folder.portfolio_id}&deal_room=true',{ onComplete: function(request){ load_completer();
        }});return false;\">#{truncate_extra_chars(folder.name.titleize)}</a>" : "<a href='' onclick=\"load_writter();new Ajax.Request('/properties/show_asset_files?folder_id=#{folder.id}&pid=#{folder.portfolio_id}',{ onComplete: function(request){ load_completer();
        }});return false;\">#{truncate_extra_chars(folder.name.titleize)}</a>"))
    return raw(@path)
  end

  #............................................To display breadcrump for my files ..........................................................................
  def breadcrump_display_my_files_asset_manager_real_estate(folder)
    arr =[]
    i = 0
    while !folder.nil?
      #................................................To find path ..............................................................
      find_path_for_breadcrumb(folder)
      #..................................................................................................................................
      if folder.name == "my_files" && folder.parent_id == 0 && find_manage_real_estate_shared_folders('false').flatten.index(folder) == 'nil'
        name2 =  ""
        tmp_name = "<div class='bread'><a href='' onclick=\"load_writter();show_collaboration_overview();change_color('overview_tab');return false;load_completer();return false;\">#{name2}</a></div>"
      else
        if folder.name == "my_files" && folder.parent_id == 0
          tmp_name = "<div class='bread'><a href='' onclick=\"load_writter();show_collaboration_overview();change_color('overview_tab');return false;load_completer();return false;\">My Files </a></div>"
       elsif folder.name == "my_deal_room" && folder.parent_id == 0
          tmp_name = "<div class='bread'><a href='' onclick=\"load_writter();show_transaction_overview_page();return false;load_completer();return false;\">My Deal Room</a></div>"
         else
          tmp_name = "<div class='breadicon'><img border='0' width='18' height='18' src='/images/collaboration_hub_new_floder.png'></div><div class='bread'>#{@path}</div>"
        end
      end
     if folder.name == "Bulk Uploads" && folder.parent_id == -2
        bulk_link =  (i == 0) ?  "<div class='bread1'><div class='breadicon'><img width='18' height='18' src='/images/collaboration_hub_new_floder.png'></div>#{folder.name}</div>" : tmp_name
         name ="<div class='bread' style='#{params[:bulk_upload] ? 'display:block;' : 'display:none;'}'><a href='' onclick=\"load_writter();show_collaboration_overview();change_color('overview_tab');return false;load_completer();return false;\">My Files </a></div><div class='saprater' style='#{params[:bulk_upload] ? 'display:block;' : 'display:none;'}'>></div>#{bulk_link}"
      else
      name = (i == 0) ? "#{((folder.name != "my_files" &&  folder.parent_id != 0)) ? "<div class='breadicon'><img width='18' height='18' src='/images/collaboration_hub_new_floder.png'></div>" : ""}<div class='bread1'>#{truncate_extra_chars(folder.name == "my_files" && folder.parent_id == 0 ? 'My Files' : (folder.name == "my_deal_room" && folder.parent_id == 0 ? 'My Deal Room' : folder.name))}</div>" :  "#{tmp_name}"
     end
      arr << name if check_is_folder_shared(folder) == 'true' || folder.user_id == current_user.id  ||  (name2 && name2 == 'My Files' )
      if find_manage_real_estate_shared_folders('false').flatten.index(folder) && (folder.name != "my_files" &&  folder.parent_id != 0)
        if params[:deal_room] == 'true'
          tmp_name = "<div class='bread'><a href='' onclick=\"load_writter();show_transaction_overview_page();return false;load_completer();return false;\">My Deal Room</a></div>"
        else
          tmp_name = "<div class='bread'><a href='' onclick=\"load_writter();show_collaboration_overview();change_color('overview_tab');return false;load_completer();return false;\">My Files</a></div>"
        end
        arr << tmp_name
      end
      folder = Folder.find(:first,:conditions=> ["id = ?",folder.parent_id])
      i += 1
    end
     new_arr=arr.reverse
    new_a=[]
    new_arr.each_with_index do|a,i|
      if i==0
        new_a << a
      else
        new_a << "<div style='float:left;'><div class='saprater'>></div>"+a+"</div>"
      end
    end
    return raw(new_a.join)
    #~ return arr.reverse.join("<div class='setupiconrow3' style='margin-top: 3px;'><img width='10' height='9' src='/images/eventsicon2.png' ></div>")
  end
  def find_by_parent_id_and_name(folder_id, templates)
    return Folder.find_by_parent_id_and_name(folder_id, templates)
  end

  def find_user_name(id)
    user = User.find_by_id(id)
    user_name = user.name? ? lengthy_word_simplification(user.name, 5, 10) :  lengthy_word_simplification(user.email, 5, 10)
    return user_name
  end

  def find_user_name_without_lengthy_word(id)
    user = User.find_by_id(id)
    user_name = user.name? ? lengthy_word_simplification(user.name, 10,20) :  lengthy_word_simplification(user.email,10,20)
    return user_name
  end

  def display_owner_or_co_owner(obj)
    if obj.user_id == current_user.id && ((@past_shared_folders && @past_shared_folders.index(obj)) || (@past_shared_docs && @past_shared_docs.index(obj)))
      raw("<span><img src='/images/owner.png' border='0' /></span>")
    elsif  obj.user_id != current_user.id
      raw("<span><img src='/images/co_owner.png' border='0' /></span>")
    end
  end

  def check_if_doc_variance_task(doc_id)
    doc = Document.find_by_id(doc_id)
    return doc.id if !doc.nil?
  end

  def find_document_id(id)
    return Document.find_by_id(id)
  end

  def find_first_property(port)
    if port.user_id == current_user.id
      property = RealEstateProperty.find(:first, :conditions=>["portfolios.id = ? and property_name not in (?)",port.id,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]],:joins=>:portfolios, :order=>"real_estate_properties.created_at desc")
      return property
    else
      if port.user_id != current_user.id
        shared_folders = SharedFolder.find(:all, :conditions => ["real_estate_property_id in (?) and is_property_folder = ? and user_id = ? and client_id = ?",port.real_estate_properties.collect{|i| i.id},true,current_user.id,current_user.client_id])
        properties = shared_folders.collect{|sf| sf.folder.real_estate_property}
        if properties
          return properties.first
        end
      end
    end
  end

  def find_by_user_id_and_name(id,my_files)
    return Folder.find_by_user_id_and_name(current_user.id,my_files)
  end

  def find_portfolios_to_display_in_collabhub
    @portfolios = []
    @real_estate_properties = []
    @user = current_user
    @updated_properties = RealEstateProperty.find(:all, :conditions => ["user_id = ? and client_id = ?",current_user.id,current_user.client_id], :order => "created_at desc, last_updated desc", :limit=>4)
    @real_estate_properties = RealEstateProperty.find(:all, :conditions => ["real_estate_properties.user_id = ? and real_estate_properties.client_id = ?",current_user.id,current_user.client_id], :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name",:joins=>:portfolios, :order => "real_estate_properties.created_at desc, real_estate_properties.last_updated desc")
    #~ @real_estate_properties = RealEstateProperty.find(:all, :conditions => ["real_estate_properties.user_id = ? and real_estate_properties.client_id = ? and property_name in ('property_created_by_system','property_created_by_system_for_bulk_upload','property_created_by_system_for_deal_room')",current_user.id,current_user.client_id], :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name",:joins=>:portfolios, :order => "real_estate_properties.created_at desc, real_estate_properties.last_updated desc")
    if params[:deal_room] == 'true'
    @real_estate_properties = @real_estate_properties.select{|i| i.portfolio.try(:name) == 'portfolio_created_by_system_for_deal_room'}
    else
    @real_estate_properties = @real_estate_properties.select{|i| i.portfolio.try(:name) != 'portfolio_created_by_system_for_deal_room'}
    end
    #~ @portfolios = Portfolio.find(:all, :conditions => ["user_id = ? and portfolio_type_id = 2",current_user.id])
    @portfolios = Portfolio.where("user_id = ? and portfolio_type_id = 2 and name in ('portfolio_created_by_system','portfolio_created_by_system_for_bulk_upload','portfolio_created_by_system_for_deal_room')",current_user.id)
    @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
    #~ @portfolios += Portfolio.find(:all, :conditions => ["id in (?)",@shared_folders.collect {|x| x.portfolio_id}]) if !(@shared_folders.nil? || @shared_folders.blank?)
    unless params[:deal_room] == 'true'
    @real_estate_properties += RealEstateProperty.find(:all, :conditions => ["real_estate_properties.id in (?)",@shared_folders.collect {|x| x.real_estate_property_id}],:joins=>:portfolios, :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name").select{|i| i.portfolio.name != 'portfolio_created_by_system_for_deal_room' if i.portfolio.present? } if !(@shared_folders.nil? || @shared_folders.blank?)
    else
     @real_estate_properties += RealEstateProperty.find(:all, :conditions => ["real_estate_properties.id in (?)",@shared_folders.collect {|x| x.real_estate_property_id}],:joins=>:portfolios, :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name").select{|i| i.portfolio.name == 'portfolio_created_by_system_for_deal_room' if i.portfolio.present?} if !(@shared_folders.nil? || @shared_folders.blank?)
   end
  end

  def find_user_has_properties
    @real_estate_properties = RealEstateProperty.find(:all, :conditions => ["user_id = ? and property_name not in (?) and client_id = #{current_user.client_id}",current_user.id,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]])
    @real_estate_properties += RealEstateProperty.find_by_sql("SELECT * FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{current_user.id}  and client_id = #{current_user.client_id})")
  end

  def fetch_req_physical_property_folder(note_id)
    p = RealEstateProperty.find_real_estate_property(note_id)
    f = Folder.find(:first,:conditions=>['real_estate_property_id =? and portfolio_id = ? and name = ?',p.id,p.portfolio_id,'Property Pictures'])
    a = f.nil? ? p.id : f.id
    return a
  end

  def financial_occupancy_claculation(v1,v2,v3)
    return v1.abs - v2.abs - v3.abs
  end

  def financial_vacancy_calculation(v1,v2)
    return v1 + v2
  end

  def find_property_folder_by_property_id(property_id)
    property_folder  = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(property_id,0,0)
  end

  def  find_summary_comments(commentable_id,commentable_type,is_reply)
    Comment.find(:all, :conditions=> ["commentable_id = ? and commentable_type = ? and is_reply = ?", commentable_id,commentable_type, is_reply])
  end

  def find_added_scondary_files
    @folder = Folder.find_by_id(params[:folder_id]) if params[:folder_id]
    @property_folder  = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(@folder.real_estate_property_id,0,0)
    if @property_folder.real_estate_property.portfolio.name == 'portfolio_created_by_system_for_deal_room'
    @amp_folder = Folder.find_by_id(@folder.id)
    @monthly_report_folder = Folder.find_by_id(@folder.id)
    @portfolio = @folder.portfolio
    @documents = @folder.documents
    @folders = Folder.all(:conditions=>['parent_id=?',@folder.id])
    else
    @amp_folder = Folder.find_by_name("AMP Files",:conditions=>["real_estate_property_id = #{@folder.real_estate_property.id} and parent_id = #{@property_folder.id} and is_master = 1"])
    end
    unless @property_folder.real_estate_property.portfolio.name == 'portfolio_created_by_system_for_deal_room'
    if @amp_folder.nil?
    @monthly_report_folder = Folder.find_by_name("Report Docs",:conditions=>["real_estate_property_id = #{@folder.real_estate_property.id} and parent_id = #{@property_folder.id} and is_master = 1"])
    else
    @monthly_report_folder = Folder.find_by_name("Report Docs",:conditions=>["real_estate_property_id = #{@folder.real_estate_property.id} and parent_id = #{@amp_folder.id} and is_master = 1"])
    end
    end
    @subfolders,@subdocs,@sub_docnames = Folder.subfolders_docs(@monthly_report_folder.id,true,false,params)  if @monthly_report_folder
    @subdocs.reject!{|x| check_is_doc_shared(x) != 'true'} if @subdocs && !@subdocs.empty?
    @added_secondary_files = @subdocs.compact.sort_by(&:created_at).reverse  if @monthly_report_folder
  end

  #To check if a document is shared to any
def check_is_doc_shared(d)
    if params[:user] == 'false'
      return "true"
    else
      sd = SharedDocument.find_by_document_id(d.id,:conditions=>["user_id = ? or sharer_id =?",current_user.id,current_user.id],:select=>'id')
      if sd.nil? && d.user_id != current_user.id
        return "false"
      else
        return "true"
      end
    end
  end

  def close_control_model
    responds_to_parent do
      render :update do |page|
        page.call 'close_control_model'
        page.call "load_completer"
      end
    end
  end

    def check_email_validation
    flag_value = true
    if !params[:collaborator_list].nil? && !params[:collaborator_list].blank?
      email_ids = params[:collaborator_list].split(",")
      email_ids = email_ids.reject{|email_id| current_user.email == email_id}
      email_name_regex  = '[\w\.%\+\-]+'.freeze
      domain_head_regex = '(?:[A-Z0-9\-]+\.)+'.freeze
      domain_tld_regex  = '(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum)'.freeze
      email_regex       = /\A#{email_name_regex}@#{domain_head_regex}#{domain_tld_regex}\z/i
      email_ids.each do |e|
        if e.strip.match(email_regex)
          flag_value = true
        else
          flag_value = false
          break
        end
      end
      @validation_msg = "Please enter the valid email address" if flag_value == false
      return  (flag_value == false) ? false : true
    elsif params[:collaborator_list].blank? && !params[:file_coll].blank?
      true
    elsif params[:collaborator_list].blank? && params[:file_coll].blank?
      @validation_msg = "Please enter the valid email address"
      false
    end
  end

  def common_update_page(page,div_ids,partial_filenames,options={})
    div_ids.each_with_index do |id,index|
      page.replace_html id,:partial => partial_filenames[index],:locals => options[id]
    end
  end

  def common_insert_js_to_page(page,js_stmts)
    js_stmts.each do |js_stmt|
      page << js_stmt
    end
  end

  def common_for_wres_swig(tl_month,tl_year,controller_action_name)
    calc_for_financial_data_display
      if !params[:tl_month].nil? and !params[:tl_month].blank?
        executive_overview_details(tl_month,tl_year)
      elsif !params[:tl_period].nil?  and (params[:tl_period] =="4" ||  params[:tl_period] =="7" || params[:tl_period] =="2" || params[:period] =="2")
        executive_overview_details_for_year
      elsif !params[:tl_period].nil?  and params[:tl_period] =="5"
        calc_for_financial_data_display
        executive_overview_details(@financial_month,@financial_year)
      elsif (params[:tl_period] =="6" || params[:tl_period] == "3" || params[:period] == "3" || params[:period] == "6")
        executive_overview_details_for_prev_year
      elsif !params[:tl_period].nil?  and params[:tl_period] =="8"
        executive_overview_details_for_year_forecast
      end
      property_name = @note.try(:class).eql?(Portfolio) ? @note.try(:name) : @note.try(:property_name)
      unless @pdf
      render :update do |page|
        if params[:main_head_call]
          @period = (!params[:tl_month].nil? and !params[:tl_month].blank?) ? "1" : (!params[:tl_period].nil? and !params[:tl_period].blank?) ?  params[:tl_period]  : "1"
          if (!params[:tl_month].nil? and !params[:tl_month].blank?)
            @time1 =  Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
            @ctlm = true
          end
          page.assign "active_sub_call", "#{controller.action_name}" if controller_action_name.eql?("for_notes")
          common_update_page(page,["head_for_titles","overview"],["/properties/head_for_titles/","/properties/portfolio_overview/"],{"head_for_titles"=>{:portfolio_collection => @portfolio,:note_collection => @note},"overview"=>{}})
          class_names = ((params[:tl_month].empty? || params[:tl_month].nil?) && (!params[:tl_period].blank? && params[:tl_period] == "5")) ? ["subtabdeactiverow","subtabactiverow","subtabdeactiverow"] :
          (((params[:tl_month].empty? || params[:tl_month].nil?) && (!params[:tl_period].blank? && params[:tl_period] == "4")) ? ["subtabactiverow","subtabdeactiverow","subtabdeactiverow"] :
          ((@financial_month.to_s == params[:tl_month]) ? ["subtabdeactiverow","subtabactiverow","subtabdeactiverow"] :

          (((params[:tl_month].empty? || params[:tl_month].nil?) && (!params[:tl_period].blank? && params[:tl_period] == "6")) ? ["subtabdeactiverow","subtabdeactiverow","subtabactiverow"] : ["subtabdeactiverow","subtabdeactiverow","subtabdeactiverow"])))

          common_insert_js_to_page(page,["jQuery('#yearToDate').attr('className','#{class_names[0]}');","jQuery('#lastMonth').attr('className','#{class_names[1]}');","jQuery('#lastyear').attr('className','#{class_names[2]}');"]) if params[:tl_period] && params[:tl_period] != '3'
        else
          if request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?("acquisitions")
            common_update_page(page,["head_for_titles","overview"],["/property_acquisitions/titles/","/properties/portfolio_overview/"],{"head_for_titles"=>{:portfolio_collection => @portfolio,:note_collection => @note},"overview"=>{}})
          else
            if params[:partial_page] == "leases_and_occupancy"
              @time_line = RentRoll.find(:all,:conditions=>["resource_id =? and resource_type=?",@note.id, 'RealEstateProperty'])
              @time_line_actual = Actual.find(:all,:conditions=>["resource_id =? and resource_type=?",@note.id, 'RealEstateProperty'])
              @time_line_rent_roll = @time_line if !@time_line.nil?
              common_update_page(page,["head_for_titles","overview"],["/properties/head_for_titles/","/properties/leases_and_occupancy/"],{"head_for_titles"=>{:portfolio_collection => @portfolio,:note_collection => @note},"overview"=>{:time_line_actual=>@time_line_actual,:time_line_rent_roll=>@time_line_rent_roll,:timeline_selector =>@timeline_selector,:period=>@period,:note_collection=>@note,
    :time_line_start_date=>@time_line_start_date,:time_line_end_date=>@time_line_end_date,:rent_roll=>@rent_roll,:end_date=>@end_date,:portfolio_collection=>@portfolio,
    :user_id_graph=>@user_id_graph,:navigation_start_position=>@navigation_start_position,:rent_area=>@rent_area,:prop_collection=>@prop,:rent_sum=>@rent_sum,
    :aged_recievables=>@aged_recievables,:start_date =>@start_date}})
              page[:current_note].innerHTML = property_name
            else
              @period = (!params[:tl_month].nil? and !params[:tl_month].blank?) ? "1" : (!params[:tl_period].nil? and !params[:tl_period].blank?) ?  params[:tl_period]  : "1"
              if (!params[:tl_month].nil? and !params[:tl_month].blank?)
                @time1 =  Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
                @ctlm = true
              end
              page << "jQuery('#time_line_selector').show();"
              page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page =>"portfolio_partial", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date } unless @balance_sheet
              page << "jQuery('#lastMonth').attr('className','subtabactiverow');" if @financial_month.to_s == params[:tl_month]
              if(controller_action_name.eql?("for_notes"))
                 page << "jQuery('#id_for_modify_threshold').hide();"
              end
               page.replace_html "portfolio_overview_property_graph", :partial =>  "/properties/property_financial_performance",:locals =>{:operating_statement => @operating_statement,        :explanation => @explanation,:cash_flow_statement => @cash_flow_statement,:debt_services => @debt_services,:portfolio_collection => @portfolio,
    :notes_collection => @notes,:time_line_actual => @time_line_actual,:time_line_rent_roll => @time_line_rent_roll,:note_collection => @note,:start_date => @start_date,:actual=>@actual,:current_time_period =>@current_time_period,:doc_collection=>@doc}
              #~ page[:current_note].innerHTML = property_name if controller_action_name.eql?("for_notes")
            end
          end
        end
           set_quarterly_msg(page) if params[:period] =="2" || params[:tl_period] =="2"
      end
    end
  end

  def common_financial_wres_swig(params,source)
    #~ @portfolio = Portfolio.find(params[:portfolio_id]) if !@portfolio
    #~ @note = RealEstateProperty.find_real_estate_property(params[:id])  if !@note
    find_dashboard_portfolio_display
    property_name = @note.try(:class).eql?(Portfolio) ? @note.try(:name) : @note.try(:property_name)
    @operating_statement={}
    @cash_flow_statement={}
    #source.eql?("swig") ? financial_month : wres_financial_month
    financial_month
   @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty']) if source.eql?("wres")
   unless @pdf
    render :update do |page|
    time_line_display = @balance_sheet ? "jQuery('.executiverhsrow').hide();" : "jQuery('#time_line_selector').show();"
      if(params[:tl_period] == "4"  ||  params[:period] == "4") &&  ((params[:tl_month].nil? || params[:tl_month].blank?) )
       replace_time_line_selector(page) unless @balance_sheet
      params[:from_performance_review] == "true" ? common_insert_js_to_page(page,["#{time_line_display}"]) : common_insert_js_to_page(page,["jQuery('.subheaderwarpper').show();","jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>#{@balance_sheet ? 'Balance Sheet' : 'Operating Statement'} </div>');"])
      else
      params[:from_performance_review] == "true" ? common_insert_js_to_page(page,["#{time_line_display}","jQuery('.subheaderwarpper').show();"]) : common_insert_js_to_page(page,["#{time_line_display}","jQuery('.subheaderwarpper').show();","jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>#{@balance_sheet ? 'Balance Sheet' : 'Operating Statement'}  </div>');"])
     end
      page << "jQuery('#monthyear').show();"
      page << "jQuery('#id_for_modify_threshold').hide();"
    if source.eql?("swig")
      page.replace_html "portfolio_overview_property_graph", :partial =>  "/properties/property_financial_performance",:locals =>{:operating_statement => @operating_statement,        :explanation => @explanation,:cash_flow_statement => @cash_flow_statement,:debt_services => @debt_services,:portfolio_collection => @portfolio,
    :notes_collection => @notes,:time_line_actual => @time_line_actual,:time_line_rent_roll => @time_line_rent_roll,:note_collection => @note,:start_date => @start_date,:actual=>@actual,:current_time_period =>@current_time_period,:doc_collection=>@doc}
    elsif  source.eql?("balance_sheet")
          page.replace_html "portfolio_overview_property_graph", :partial =>  "/properties/balance_sheet",:locals =>{:operating_statement => @operating_statement,        :explanation => @explanation,:cash_flow_statement => @cash_flow_statement,:debt_services => @debt_services,:portfolio_collection => @portfolio,
    :notes_collection => @notes,:time_line_actual => @time_line_actual,:time_line_rent_roll => @time_line_rent_roll,:note_collection => @note,:start_date => @start_date,:actual=>@actual,:current_time_period =>@current_time_period,:doc_collection=>@doc}
    else
 		 @cash_flow_statement['maintenance projects'] =  @operating_statement["maintenance projects"]
      page.replace_html "portfolio_overview_property_graph", :partial =>"/properties/property_financial_performance",:locals=>{:operating_statement=>@operating_statement,:explanation=>@explanation,:notes_collection=>@notes,:note_collection=>@note,:start_date=>@start_date,:time_line_actual=>@time_line_actual,:actual=>@actual,
    :navigation_start_position=>@navigation_start_position,:time_line_rent_roll => @time_line_rent_roll,:portfolio_collection =>@portfolio,:cash_flow_statement => @cash_flow_statement,:current_time_period =>@current_time_period}
      end
      #~ page[:current_note].innerHTML = @note.property_name if source.eql?("swig")
      set_quarterly_msg(page) if (params[:period] =="2" || params[:tl_period] =="2") && !@balance_sheet
    end
   end
  end

    def find_collaborator_name_to_display(u)
    "<span title=#{(!u.name.nil? and !u.name.blank?) ? u.name : u.email.split("@")}>#{(!u.name.nil? and !u.name.blank?) ?  lengthy_word_simplification(u.name,15,5) : lengthy_word_simplification(u.email.split("@")[0],15,5)}</span>"
  end
  def convert_lines_to_span(name_truncate)
    if !name_truncate.blank?
      span_array = name_truncate.lines.to_a[0..2].collect{|value| "<span>#{value}</span>"}.join("<br/>")
      return raw((name_truncate.lines.to_a.length > 3) ? (span_array+="<br/><span>...</span>") : (span_array))
    else
      return ""
    end
  end

  def find_logo_extension
    portfolio_image = nil
    if current_user
      #~ client_extension = ClientSetting.find_by_extension(current_user.email.match(/\@(.+)/)[1])
      #~ portfolio_image = client_extension.nil? ? nil : PortfolioImage.find(client_extension.portfolio_image_id)
      client_id=User.find_by_id(current_user.id).try(:client_id)
      portfolio_image=PortfolioImage.find_by_attachable_type_and_attachable_id("Client",client_id)
    else
      portfolio_image = nil
    end
    return portfolio_image
  end

  def find_client_logo_extension
    portfolio_image = nil
    if current_user
      portfolio_image = current_user.try(:client_logo_image)
    else
      portfolio_image = nil
    end
    return portfolio_image
  end

  #used whed user,shared user sets passwod
  def finalize_set_password
    if @user.save && params[:user][:portfolio_image] && validate_profile_image
      @user.password_code = nil
      @user.portfolio_image = @portfolio_image
      @user.profile_image_path = @portfolio_image.public_filename
      @user.save
      flash[:notice] = FLASH_MESSAGES['user']['104']
      redirect_to :controller=>"sessions",:action=>"new"
    elsif @user.save && !params[:user][:portfolio_image]
      @user.password_code = nil
      @user.save
      flash[:notice] = FLASH_MESSAGES['user']['104']
      redirect_to :controller=>"sessions",:action=>"new"
    else
      validate_profile_image if params[:user][:portfolio_image]
      render :action=>'set_password'
    end
  end

  #validate user profile image added during set password
  def validate_profile_image
    valid_image_formats = ["jpeg","png","gif","bmp"]
    if params[:user][:portfolio_image] && valid_image_formats.include?(@portfolio_image.content_type.split("/").last)
      true
    else
      @user.errors.add "profile_image", "Please upload (jpg,jpeg,png,gif,bmp) format file only"
      false
    end
  end

  def month_ytd_explanation
    period=params[:period] ? params[:period] : params[:tl_period]
    months = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return if (period=="3" || period=="8")
    if !params[:tl_month].nil? and !params[:tl_month].blank? and !params[:tl_year].nil? and !params[:tl_year].blank?
      months[params[:tl_month].to_i]
    elsif (period=="5" && !params[:tl_month].blank? && !params[:start_date])
      months[params[:tl_month].to_i]
    elsif period=="5" && params[:start_date]
      months[params[:start_date].to_date.month]
    elsif period=="5"
      months[Date.today.month-1]
    elsif period=="4" && !params[:tl_month].blank? && !params[:start_date].blank?
      months[params[:tl_month].to_i]
    elsif (period=="7" && !params[:start_date].blank?)
      months[params[:start_date].to_date.month]
    elsif (period=="7" && params[:start_date].blank? && params[:cur_month])
      #params[:cur_month]
    elsif (period=="7" && params[:start_date].blank?)
      "YTD"
    elsif (period=="4" && !params[:tl_month].blank? && !params[:start_date].blank?)
      months[params[:tl_month].to_i]
    elsif (period=="4" && params[:tl_month].blank? && params[:start_date].blank?)
      "YTD"
    end
  end

 #To display year near breadcrumb in rent roll,receivables
  def find_timeline_message
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_order = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value = find_selected_year(Date.today.year)
      if  !params[:start_date].nil? && (params[:period] == "3" || [:tl_period] == "3") && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables")
      timeline_msg =(@month_red_start && @month_red_start ==0) ? "" :" As Of #{months[@month_red_start - 13]} #{@year}"
      elsif params[:start_date] && (params[:period] != "2" && params[:tl_period] != "2")
            timeline_msg = ""
    		elsif ((!params[:tl_period].nil?  and params[:tl_period] =="4") || params[:period] == "4"  || (params[:period] =="8" || params[:tl_period] =="8")) && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables") && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"
        elsif ((!params[:tl_period].nil?  and params[:tl_period] =="7") ||  (!params[:period].nil?  and params[:period] =="7"))  && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables") && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"
        elsif((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3"))  && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables")&& (params[:tl_month].blank? || params[:tl_month].nil?) || ((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3"))
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"
             elsif ((!params[:tl_period].nil?  and params[:tl_period] =="10") ||  (!params[:period].nil?  and params[:period] =="10") || (params[:period] =="5" || params[:tl_period] =="5") )  && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables")
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"
        elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (params[:partial_page] == "rent_roll" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "cash_and_receivables_for_receivables") && (!params[:tl_year].blank? || !params[:tl_year].nil?) || (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (!params[:tl_year].blank? || !params[:tl_year].nil?)
             #~ start_month = params[:quarter_end_month].to_i - 2
             @month =  params[:partial_page] == "cash_and_receivables_for_receivables" ? @month_red_start  : @month_red_start
              #~ if !@month.nil?
              #~ if months_order[start_month] == months[@month - 13]
               #~ timeline_msg = " As Of #{months_order[start_month]} #{@year}"
               #~ else
                timeline_msg =  (@month && @month==0) ? "" :" As Of #{months[@month - 13]} #{@year}"
              #~ end
              #~ else
                #~ timeline_msg = ""
              #~ end
          elsif params[:partial_page] == "rent_roll_highlight" && params[:from_lease].present?
                timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"
          elsif params[:controller].eql?("nav_dashboard")
                timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of #{months[@month_red_start - 13]} #{@year}"  
        else
        timeline_msg = ""
      end
      return timeline_msg
    end

   #display message for leases
    def find_timeline_msg_for_leases
      if is_multifamily(@note)
      str_val = "As Of "
      else
      str_val = @month_red_start == 13 ? "-" : "Jan - "
    end
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_order = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value = find_selected_year(Date.today.year)
    if  !params[:start_date].nil? && (params[:period] == "3" || [:tl_period] == "3") && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab")
      timeline_msg =(@month_red_start && @month_red_start ==0) ? "" :" #{str_val} #{months[@month_red_start - 13]} #{@year}"
      elsif params[:start_date] && (params[:period] != "2" && params[:tl_period] != "2")
            timeline_msg = ""
           elsif ((!params[:tl_period].nil?  and params[:tl_period] =="4") || params[:period] == "4"  || (params[:period] =="8" || params[:tl_period] =="8")) && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab") && (params[:tl_month].blank? || params[:tl_month].nil?)
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
           elsif ((!params[:tl_period].nil?  and params[:tl_period] =="7") ||  (!params[:period].nil?  and params[:period] =="7"))  && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab")&& (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
            elsif((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3"))  && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab")&& (params[:tl_month].blank? || params[:tl_month].nil?)
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
             elsif ((!params[:tl_period].nil?  and params[:tl_period] =="10") ||  (!params[:period].nil?  and params[:period] =="10") || (params[:period] =="5" || params[:tl_period] =="5") )  && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab")
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
            elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (params[:partial_page] == "leases" || params[:partial_page] == "lease_sub_tab") && (!params[:tl_year].blank? || !params[:tl_year].nil?)
              timeline_msg = is_multifamily(@note)? ((@month_red_start && (@month_red_start.nil? || @month_red_start ==0)) ? "" :" #{str_val} #{months[@month_red_start - 13]} #{year_value}") : ((@month_red_start && (@month_red_start.nil? || @month_red_start ==0)) ? "" :"#{str_val}#{months[@month_red_start - 13]} #{@year}")
             #~ start_month = params[:quarter_end_month].to_i - 2
              #~ if !@month.nil?
              #~ if months_order[start_month] == months[@month - 13]
               #~ timeline_msg = is_multifamily(@note)? " As Of #{months_order[start_month]} #{@year}" :" #{months_order[start_month]} #{@year}"
               #~ else
                #~ timeline_msg = is_multifamily(@note)? ((@month && @month.nil?) ? "" :" As Of #{months[@month - 13]} #{year_value}") : ((@month && @month.nil?) ? "" :" #{months_order[start_month]} - #{months[@month - 13]} #{@year}")
              #~ end
              #~ else
                #~ timeline_msg = ""
              #~ end
           else
        timeline_msg = ""
      end
      return timeline_msg
    end

    #summary page timeline message display
    def find_timeline_msg_summary_rent
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_order = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value = find_selected_year(Date.today.year)
    if !params[:start_date].nil? && (params[:period] == "3" || [:tl_period] == "3")
      timeline_msg =(@month_red_start && @month_red_start ==0) ? "" :"As Of #{months[@month_red_start - 13]} #{@year}"
			elsif ((!params[:tl_period].nil?  and params[:tl_period] =="4") || params[:period] == "4"  || (params[:period] =="8" || params[:tl_period] =="8") || (params[:controller] == "properties" && params[:action] == "show") ) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : "As Of #{months[@month_red_start - 13]} #{@year}"
        elsif ((!params[:tl_period].nil?  and params[:tl_period] =="7") ||  (!params[:period].nil?  and params[:period] =="7")) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : "As Of  #{months[@month_red_start - 13]} #{@year}"
        elsif((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3")) && (params[:tl_month].blank? || params[:tl_month].nil?)
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of  #{months[@month_red_start - 13]} #{@year}"
         elsif ((!params[:tl_period].nil?  and params[:tl_period] =="10") ||  (!params[:period].nil?  and params[:period] =="10") || (params[:period] =="5" || params[:tl_period] =="5") || (params[:period] =="1" || params[:tl_period] =="1") )
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : "As Of  #{months[@month_red_start - 13]} #{@year}"

        elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (!params[:tl_year].blank? || !params[:tl_year].nil?)
            timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " As Of  #{months[@month_red_start - 13]} #{@year}"
             #~ start_month = params[:quarter_end_month].to_i - 2
              #~ if !@month_qtr.nil?
              #~ if months_order[start_month] == months[@month_qtr - 13]
               #~ timeline_msg = "As Of #{months_order[start_month]} #{@year}"
               #~ else
                #~ timeline_msg =  (@month_qtr && @month_qtr.nil?) ? "" :" As Of #{months[@month_qtr - 13]} #{@year}"
              #~ end
              #~ else
                #~ timeline_msg = ""
              #~ end
			  else
			  timeline_msg = ""
			end
      return timeline_msg
    end


    def find_timeline_msg_summary_lease
      if is_multifamily(@note)
      str_val = "As Of "
      else
      str_val = @month_red_start == 13 ? "-" : "Jan - "
      end
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_order = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value = find_selected_year(Date.today.year)
      if !params[:start_date].nil? && (params[:period] == "3" || [:tl_period] == "3")
      timeline_msg =(@month_red_start && @month_red_start ==0) ? "" :" #{str_val} #{months[@month_red_start - 13]} #{@year}"
			elsif ((!params[:tl_period].nil?  and params[:tl_period] =="4") || params[:period] == "4"  || (params[:period] =="8" || params[:tl_period] =="8") || (params[:controller] == "properties" && params[:action] == "show") ) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
        elsif ((!params[:tl_period].nil?  and params[:tl_period] =="7") ||  (!params[:period].nil?  and params[:period] =="7")) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
        elsif((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3")) && (params[:tl_month].blank? || params[:tl_month].nil?)
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
       elsif ((!params[:tl_period].nil?  and params[:tl_period] =="10") ||  (!params[:period].nil?  and params[:period] =="10") || (params[:period] =="5" || params[:tl_period] =="5") || params[:period] =="1" || params[:tl_period] =="1" )
           timeline_msg =(@month_red_start && @month_red_start ==0) ? "" : " #{str_val} #{months[@month_red_start - 13]} #{@year}"
            elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (!params[:tl_year].blank? || !params[:tl_year].nil?)
              timeline_msg = is_multifamily(@note)? ((@month_red_start && @month_red_start ==0) ? "" :" #{str_val} #{months[@month_red_start - 13]} #{@year}") : ((@month_red_start&& @month_red_start ==0) ? "" :"#{str_val} #{months[@month_red_start - 13]} #{@year}")
             #~ start_month = params[:quarter_end_month].to_i - 2
              #~ if !@month_lease.nil?
              #~ if months_order[start_month] == months[@month_lease - 13]
               #~ timeline_msg = is_multifamily(@note)? " As Of #{months_order[start_month]} #{@year}" :" #{months_order[start_month]} #{@year}"
               #~ else
                #~ timeline_msg = is_multifamily(@note)? ((@month_lease && @month_lease.nil?) ? "" :" As Of #{months[@month_lease - 13]} #{@year}") : ((@month_lease&& @month_lease.nil?) ? "" :" #{months_order[start_month]} - #{months[@month_lease - 13]} #{@year}")
              #~ end
              #~ else
                #~ timeline_msg = ""
              #~ end
        else
			  timeline_msg = ""
			end
      return timeline_msg
    end

 def find_contact_details
 user_ids = []
    added_collaborators = Collaborator.find(:all,:conditions=>["user_1_id = #{current_user.id} || user_2_id = #{current_user.id}"],:order=>'created_at desc')
    unless added_collaborators.empty?
     added_collaborators.each do |collaborator|
       user_ids <<  collaborator.user_1_id <<  collaborator.user_2_id
     end
   end
    if current_user && current_user.has_role?("Client Admin")
      client_admin_users=User.by_client_ids(current_user.client_id,current_user.email)
      client_admin_users && client_admin_users.each do |client_admin_user|
        user_ids << client_admin_user.id
      end
    end
    @collaborators = User.find(:all,:conditions=>["id in (?) and id != #{current_user.id}",user_ids],:order=>'created_at desc')
    return @collaborators
end


 def find_timeline_msg_summary_lease_occupancy
      if is_multifamily(@note)
      str_val = "As Of "
      else
      str_val = "Jan - "
      end
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_order = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value = find_selected_year(Date.today.year)
      if !params[:start_date].nil? && (params[:period] == "3" || [:tl_period] == "3")
      timeline_msg_occupancy =(@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" :" #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}"
			elsif ((!params[:tl_period].nil?  and params[:tl_period] =="4") || params[:period] == "4"  || (params[:period] =="8" || params[:tl_period] =="8") || (params[:controller] == "properties" && params[:action] == "show") ) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg_occupancy =(@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" : " #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}"
        elsif ((!params[:tl_period].nil?  and params[:tl_period] =="7") ||  (!params[:period].nil?  and params[:period] =="7")) && (params[:tl_month].blank? || params[:tl_month].nil?)
          timeline_msg_occupancy =(@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" : " #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}"
        elsif((!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3")) && (params[:tl_month].blank? || params[:tl_month].nil?)
           timeline_msg_occupancy =(@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" : " #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}"
            elsif ((!params[:tl_period].nil?  and params[:tl_period] =="10") ||  (!params[:period].nil?  and params[:period] =="10") || (params[:period] =="5" || params[:tl_period] =="5") || (params[:period] =="1" || params[:tl_period] =="1"))
          timeline_msg_occupancy =(@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" : " #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}"
            elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?) && (!params[:tl_year].blank? || !params[:tl_year].nil?)
            timeline_msg_occupancy = is_multifamily(@note)? ((@month_red_start_occupancy && @month_red_start_occupancy ==0) ? "" :" #{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}") : ((@month_red_start_occupancy&& @month_red_start_occupancy ==0) ? "" : "#{str_val} #{months[@month_red_start_occupancy - 13]} #{@year}")

             #~ start_month = params[:quarter_end_month].to_i - 2
              #~ if !@month_lease.nil?
              #~ if months_order[start_month] == months[@month_lease - 13]
               #~ timeline_msg_occupancy = is_multifamily(@note)? " As Of #{months_order[start_month]} #{@year}" :" #{months_order[start_month]} #{@year}"
               #~ else
                #~ timeline_msg_occupancy = is_multifamily(@note)? ((@month_lease && @month_lease.nil?) ? "" :" As Of #{months[@month_lease - 13]} #{@year}") : ((@month_lease&& @month_lease.nil?) ? "" :" #{months_order[start_month]} - #{months[@month_lease - 13]} #{@year}")
              #~ end
              #~ else
                #~ timeline_msg_occupancy = ""
              #~ end
        else
			  timeline_msg_occupancy = ""
			end
      return timeline_msg_occupancy
    end

    def find_redmonth_start_for_capexp(year_value)
      find_dashboard_portfolio_display
    month_qr = find_accounting_system_type(1,@note)  && is_commercial(@note) ? "" : "HAVING max(ci.month)"
      max_month = PropertyCapitalImprovement.find_by_sql("SELECT max(ci.month) as month,id FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND ci.real_estate_property_id = #{@note.id}  AND ci.year=#{year_value} #{month_qr}")
     if @note && (find_accounting_system_type(2,@note) && is_commercial(@note) && !max_month.empty?)
       find_month_using_capital_improvement(max_month[0].month,year_value)
     elsif  @note && ((find_accounting_system_type(2,@note) && is_commercial(@note) && max_month.empty?) || (remote_property(@note.accounting_system_type_id)))
       find_month_using_income_and_cash(year_value)
     elsif @note && (find_accounting_system_type(1,@note)  && is_commercial(@note))
       @month_red_start = !max_month.empty? ? find_month_using_capital_improvement(max_month[0].month,year_value)  : 0
     elsif @note && ((find_accounting_system_type(3,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(2,@note) || find_accounting_system_type(4,@note) || check_yardi_multifamily(@note)) &&  is_multifamily(@note))
       find_month_using_income_and_cash(year_value)
     elsif @note && ((find_accounting_system_type(0,@note) || check_yardi_commercial(@note)) &&  is_commercial(@note) &&  !max_month.empty? )
       find_month_using_capital_improvement(max_month[0].month,year_value)
     elsif @note && ((find_accounting_system_type(0,@note) || check_yardi_commercial(@note)) &&  is_commercial(@note) && max_month.empty? )
       find_month_using_income_and_cash(year_value)
     end
   end

  def get_emails_of_all_users_for_autocomplete
    get_all_groups=[]
    a = Collaborator.all.map{|x| [x.user_1_id,x.user_2_id]}.each{|x| (get_all_groups<<x if x.include?(User.current.id))}
    if get_all_groups && !get_all_groups.empty?
    get_all_groups.flatten!.reject!{|x| x==User.current.id || !User.exists?(x)}
    return User.find(get_all_groups).map(&:email).join("<$>")
    end
  end

  def show_small_amp_logo
    unless (find_logo_extension || User.current.logo_image)
      return false
    else
      return true
    end
  end

    #display collaborators list in lightbox - initial list
  def display_collaborators
    @portfolio = @folder.portfolio
    @user = current_user
    (params[:folder_revoke] == "true" || params[:note_add_edit] == 'true' || params[:call_from_variances] == 'true') ?  find_folder_members : find_doc_members
    @data,@mem_list,@sub_sharers,@sub1,@sub,@leasing_agents_data,@leasing_agent_mem_list ='','',[],[],[],'',''
    @members << @folder.user if @folder.user != current_user &&  params[:folder_revoke] == "true"
    @members << @document.user if @document && @document.user != current_user &&  params[:folder_revoke] != "true"
    add_edit_collab_display_members
  end

  def notify_prop_user
    if params[:document_id]
    @document = Document.find(params[:document_id])  if !params[:document_id].empty? && params[:id] !='show_asset_docs'
    else
    @document = Document.find(params[:id])  if params[:id] && params[:id] !='show_asset_docs'
  end
    @folder = @document.folder if @document
    @portfolio = @folder.portfolio if @folder
    @user = current_user
    @folder = find_property_folder_by_property_id(params[:property_id])
    @notify_prop_user = true
    (params[:folder_revoke] == "true" || params[:step2] == 'true') ?  find_folder_members : find_doc_members
    @data,@mem_list,@sub_sharers,@sub1,@sub ='','',[],[],[]
    @members << @folder.user if @folder.user != current_user &&  params[:folder_revoke] == "true"
    @members << @document.user if @document && @document.user != current_user &&  params[:folder_revoke] != "true"
    i=0
     variance_exp_users = @property.var_exp_users.split(',') if @property.var_exp_users
      for user in @members.uniq
      @mem_list = @mem_list.to_s + user.email.to_s + ","
      @data = @data + "<div class='variances_users_wrapper'><input type ='checkbox' #{(!variance_exp_users.nil? && !variance_exp_users.index(user.id.to_s).nil?) ? 'checked' : ''} name='selected_users[#{user.id}]' value='#{user.email}'/><div class='add_users_collaboratercol' id='#{user.email}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'><div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{user.email}</div> </div></div></div>"
      i+=1
   end
    #render :partial =>"/real_estates/notify_exp_users"
  end

   def  variances_exp_comment
       if params[:document_id].nil? || params[:document_id].blank?
         #~ responds_to_parent do
          render :update do |page|
            page << "Control.Modal.close();"
            if params[:users_form_close] != "true" && params[:users_mail_form_close] != "true" && params[:loan_form_close] != "true" && params[:prop_form_close] != "true" && params[:basic_form_close] != "true" &&  params[:call_from_variances] != "true"
            page << "detect_comment_call=true;"
            page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
            page.replace_html "portfolio_overview_property_graph", :partial => "/properties/variances",:locals => {:partial_page => "variances"}
            end
         #~ end
        end
      else
      @note =  RealEstateProperty.find_real_estate_property(params[:property_id])
       session[:comments],session[:cashflow_explanation_comments],session[:capital_explanation_comments] = {},{},{}
       clear_comments_var
      @item= @document = Document.find_by_id(params[:document_id])
      #~ responds_to_parent do
      render :update do |page|
      page << "Control.Modal.close();"
      page << "detect_comment_call=true;"
          month_details = ['','january','february','march','april','may','june','july','august','september','october','november','december']
          @month_option = month_details[params[:month].to_i]
          parent_fol_name = view_context.find_name_of_the_parents_parent(@document.folder.parent_id)
            @expln_req_props_cash= view_context.explanation_required_property(@document.real_estate_property, @month_option, parent_fol_name)
            @expln_req_props_ytd_cash = view_context.explanation_required_property_ytd(@document.real_estate_property, @month_option, parent_fol_name)
            @expln_req_props_cap_exp = view_context.explanation_required_expenditures(@document.real_estate_property, params[:month].to_i, parent_fol_name)
            @expln_req_props_ytd_cap_exp= view_context.explanation_required_expenditures_ytd(@document.real_estate_property, params[:month].to_i, parent_fol_name)

          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
          page.replace_html "portfolio_overview_property_graph", :partial=>'/performance_review_property/exp_comment_display',:locals => {:document_collection =>@document,:item_collection =>@item,:expln_req_props_ytd_collection => @expln_req_props_ytd_cash,:expln_req_props_collection => @expln_req_props_cash,:expln_req_props_cap_collection=> @expln_req_props_cap_exp,:expln_req_props_cap_ytd=>@expln_req_props_ytd_cap_exp,:item_collection => @item,:month_option => @month_option,
          :note_collection=> @note}
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        #~ end
      end
    end
  end


 def update_pages
   @note = RealEstateProperty.find_real_estate_property(params[:property_id])  if params[:property_id]
   @property_image_path =  property_image(@note.id) if !@note.nil?
   @folder = Folder.find_by_portfolio_id_and_parent_id(@portfolio.id,-1) if @portfolio && params[:is_property_folder] =="true"
if params[:call_from_variances] == "true" && (params[:variances_form_close] == "true" ||  params[:users_mail_form_close] == "true" || params[:users_form_close] == 'true')
  responds_to_parent do
    variances_exp_comment
    end
  elsif params[:step1] == 'true' || params[:step2] == 'true'
     partial = params[:step1] == 'true' ? "/real_estates/variances_form" : "/real_estates/users_mail_form"
     msg = params[:step2] == 'true' ? "Variance Threshold details saved successfully"  : (params[:selected_users] && !params[:selected_users].empty? ? "Users has been selected to perform variance explanations" : nil)
      responds_to_parent do
        render :update do |page|
          notify_prop_user
          page.replace_html "sheet123",:partial =>"#{partial}"
          page.call "flash_writter", msg if msg
        end
      end
      elsif params[:from_debt_summary] == 'true' && (params[:variances_form_close] == "true" ||  params[:users_mail_form_close] == "true")
        loan_details
      elsif params[:from_property_details] == 'true'  && (params[:variances_form_close] == "true" ||  params[:users_mail_form_close] == "true")
        property_view
      elsif params[:from_property_edit] == "true" && params[:users_form_close] != "true" && params[:variances_form_close] != "true" && params[:users_mail_form_close] != "true"
        @msg =(params[:variances_form_submit] == 'true' || params[:variances_form_close] == 'true') ? "Variance Threshold details saved successfully"  : (params[:selected_users] && !params[:selected_users].empty? ? "Users has been selected to perform variance explanations" : nil)
       @tab = params[:tab_id]
        form = params[:form_txt] + "_form"
        @property = RealEstateProperty.find_real_estate_property(params[:property_id]) if params[:property_id]
        update_respond_to_parent("#{form}","#{@tab}",@msg,nil)
      else
        params[:call_from_prop_files] == "true" ? assign_initial_options : assign_options
        partial =  params[:call_from_prop_files] == "true" ? "/properties/properties_and_files" : "/properties/assets_list"
          responds_to_parent do
            render :update do |page|
              page.hide 'modal_container'
              page.hide 'modal_overlay'
              page.call "flash_writter", "Variance Threshold details saved successfully"
              page.replace_html "show_assets_list",:partial=>"#{partial}"
              page.call 'highlight_datahub' if params[:highlight] == '1'
              if @note && params[:call_from_prop_files] == 'true'
               @portfolio = @note.portfolio
               page.replace_html "edit_count_#{@portfolio.id}",:text=>"#{property_count(@portfolio.real_estate_properties.length)}" if !@portfolio.nil? && @portfolio.user_id == current_user.id
              end
              if(params[:edit_inside_asset] == "true" || params[:from_debt_summary] == 'true' || params[:from_property_details] == 'true') && @note
              page.replace_html "portfolio_name_#{@note.id}","#{display_truncated_chars(@note.property_name, 16, true)}"
              page.replace_html "portfolio_location_#{@note.id}","#{get_location_slider(@note)}"
              page.call "change_property_pic", "#{@note.id}", "#{@property_image_path}"  if !@property_image_path.nil?
		          page.call "change_property_title","#{@note.id}","#{@note.property_name}"
              end
            end
          end
     end
   end

  def find_prop_user(id)
    @document = Document.find(id)
    @folder = @document.folder
    @portfolio = @folder.portfolio
    @user = current_user
     #~ find_folder_members
      @members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",@folder.id,current_user.id]).collect{|sf| sf.user}.compact
    @data,@mem_list,@user_name,@sub_sharers,@sub1,@sub ='','','',[],[],[]
    @members << @folder.user if @folder.user != current_user
    #~ @members << @document.user if @document && @document.user != current_user &&  params[:folder_revoke] != "true"
      for user in @members.uniq
      @mem_list = @mem_list.to_s + user.email.to_s + ","
      @data = @data + "<div style='float:left;'><input type ='checkbox' name='selected_users[#{user.id}]' value='#{user.email}'/></div><div class='add_users_collaboratercol' id='#{user.email}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{lengthy_word_simplification(user.email,30,5)}</div> </div></div>"
    end
  end

  def find_user_for_remote(id)
    @note = RealEstateProperty.find_real_estate_property(id)
    @portfolio = @note.portfolio
    @user = current_user
    @members  = SharedFolder.find(:all,:conditions=>["real_estate_property_id = ? and user_id!= ?",@note.id ,current_user.id]).collect{|sf| sf.user}.compact.uniq
    @data,@mem_list,@user_name,@sub_sharers,@sub1,@sub ='','','',[],[],[]
     if !@members.blank?
      @members += @members if @note.user != current_user
        for user in @members.uniq
        @mem_list = @mem_list.to_s + user.email.to_s + ","
        @data = @data + "<div style='float:left;'><input type ='checkbox' name='selected_users[#{user.id}]' value='#{user.email}'/></div><div class='add_users_collaboratercol' id='#{user.email}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{lengthy_word_simplification(user.email,30,5)}</div> </div></div>"
        end
      end
    end

  def display_prop_user
    if (@members && !@members.empty? && !@members.blank?)
      if @members.length > 1
        @member_display = (display_truncated_chars((@members[0].name.blank? || @members[0].name.nil? ? @members[0].email.split(/@/)[0] : @members[0].name).titleize,9,true) + ' + ' + (@members.length-1).to_s)
      else
      @member_display = display_truncated_chars((@members[0].name.blank? ? @members[0].email.split(/@/)[0] : @members[0].name).titleize,12,true)
    end
    else
      @member_display = ""
    end
    return @member_display
  end

  def sort_link_portfolio_weekly(text, parameter, options)
    update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
    page = options.delete(:page)
    per_page = options.delete(:per_page)
    partial_page = options.delete(:partial_page)
    is_primary = options.delete(:is_primary)
    portfolio_id = options.delete(:portfolio_id)
    id = options.delete(:id)
    period = options.delete(:period)
    key = parameter
    key += " DESC" if params[:prop_sort] == parameter
    key += " ASC" if params[:prop_sort] == "nil"
    order = " DESC" if params[:prop_sort] == parameter
    order = " ASC" if params[:prop_sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:prop_sort => key, :page => page ,:per_page => per_page,:portfolio_id => portfolio_id,:period => period, :order => order, :partial_page=>partial_page},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();",
      :remote=>true
    )
  end
  def weekly_sorting_image(params,column, pdf_path= '')
    if params[:prop_sort] && params[:prop_sort].downcase.include?("desc") && params[:prop_sort].downcase.include?(column)
      img = raw("<img src='#{pdf_path}/images/bulletarrowdown.png' width='7' height='5' />")
    elsif  params[:prop_sort] && params[:prop_sort].split(" ")[1] == nil && params[:prop_sort].downcase.include?(column)
      img = raw("<img src='#{pdf_path}/images/bulletarrowup.png' width='7' height='5' />")
    else
      img = raw("<img src='#{pdf_path}/images/bulletarrowdown.png' width='7' height='5' />")
    end
  end

def wrap_text(txt,col)
  txt.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/,
    "\\1\\3\n")
end

  def google_parsing
    output_filepath ||= "#{RAILS_ROOT}/public/News/News_feeds.xml"
    @out_file = output_filepath
    doc1 = Nokogiri::XML(open(@out_file))
    @a=doc1.elements
    @parent_title={}
    @parent_title_count=0
    @child = {}
    @child_count=0
    @a.each do |p|
			c= p.elements
			c.each do |k|
				d= k.elements
				d.each do|x|
					if x.name == 'outline' and x.node_type==1
            @parent_title_count+=1
            @child_count+=1
						@title_parent= x.attributes
						g=@title_parent["text"]
						@parent_title[@parent_title_count]={"text"=>g.value}
            @child[@child_count] = {"children"=>x.children}
          end
        end
			end
    end
  end

  def round_calc(sqft_percentage)
    return sqft_percentage.abs if sqft_percentage.to_f.abs.infinite?
    sqft_percentage.round.abs
  end

  def find_accounting_system_type(type_id,prop)
   a_name= ['AMP Excel','MRI, SWIG','MRI','Real Page','YARDI V1','Griffin_YARDI']
   acc_type_name = AccountingSystemType.find(prop.accounting_system_type_id).type_name if prop.accounting_system_type_id
   acc_sys_name = acc_type_name && a_name[type_id] == acc_type_name ? true : false
  return acc_sys_name
end

def check_yardi_multifamily(prop)
  type_check =  remote_property(prop.accounting_system_type_id) && prop.leasing_type == "Multifamily" ?  true : false
  return type_check
end

def check_yardi_commercial(prop)
  type_check =  remote_property(prop.accounting_system_type_id) && prop.leasing_type == "Commercial" ?  true : false
  return type_check
end

def is_commercial(note)
   type = note.leasing_type == "Commercial" ? true : false
   return type
end

def is_multifamily(note)
   type = note.leasing_type == "Multifamily" ? true : false
   return type
end

#To check whether the property is remote or not
def remote_property(id)
   remote_type = RemoteAccountingSystemType.find_by_accounting_system_type_id(id)
   if remote_type.nil?
     return false
   else
     return true
   end
end

def  find_remote_accounting_system_types
     remote_types = RemoteAccountingSystemType.find(:all).map(&:accounting_system_type_id)
     return remote_types
end

#To check whether the portfolio contains remote property
def check_portfolio_contains_remote_prop(portfolio)
   portfolio.real_estate_properties.each do |real_estate_property|
   remote_type = RemoteAccountingSystemType.find_by_accounting_system_type_id(real_estate_property.accounting_system_type_id)
   if !remote_type.nil?
     return true
   end
 end
 return false
end

#To find the owner of the property
def find_doc_owner_remote(doc_id)
  if @note
    return RealEstateProperty.find(doc_id).user.email
  else
    return Document.find(doc_id).user.email
  end
end

#To find the month
def get_month(y)
    record_month = (y.to_i < Date.today.year.to_i) ? 12 : (Date.today.month.to_i)
    return record_month
end

#If the user is leasing agent redirect to properties page
def  check_leasing_agent
  if is_leasing_agent
    redirect_to "#{goto_asset_view_path(current_user.id)}"
  else
    true
  end
end

#To check whether the user is leasing agent
def is_leasing_agent
  current_user && current_user.has_role?('Leasing Agent') ? true : false
end

	def interested_and_negotiated_leases(id,page1,page)
    id = params[:id] if id.nil? && params[:id].present? && @pdf
    id = params[:property_id] if id.nil? && params[:param_pipeline]
    @property = RealEstateProperty.find_real_estate_property(id)  # if @pdf
    a, @negotiated_six_mnth = Lease.negotiated_leases_method(id)
    page1 = page1.to_i.zero? ? 1 : page1.to_i
    page = page.to_i.zero? ? 1 : page.to_i
    @property_lease_suites_negotiated = @pdf ? a.compact.sort_by(&:updated_at).reverse! : a.compact.sort_by(&:updated_at).reverse!.paginate(:per_page=>25,:page=>page1, :initiate=>page1)
   # @prop_leas_suites_id_coll = PropertyLeaseSuite.all.map(&:suite_ids).flatten.compact
    #~ prop_id_arr= []
    #~ prop_id_arr = @property.leases.map(&:id)
    #~ @prop_leas_suites_id_coll = PropertyLeaseSuite.where(:lease_id =>  prop_id_arr).map(&:suite_ids).flatten.compact
    @vac_suites_id_coll = @property.vacant_suites.map(&:id)
    @vac_suite_ids = @vac_suites_id_coll #- @prop_leas_suites_id_coll
    if params[:selected_value] == "Inactive Items"
      archeived_val= Lease.interested_prospects_leases_archieve_method(id)
      @property_lease_suites_interested = @pdf ? archeived_val.compact.sort_by(&:updated_at).reverse! : archeived_val.compact.sort_by(&:updated_at).reverse!.paginate(:per_page=>25,:page=>page)
    else
      b, @interested_six_mnth = Lease.interested_prospects_leases_method(id)
      @vacant_suites_incl_six_mnth = @vac_suite_ids + @interested_six_mnth.map(&:suite_ids).flatten.compact
      @vacant_suites = Suite.find(:all, :conditions=>["id IN (?)", @vacant_suites_incl_six_mnth])
      @property_lease_suites_interested = @pdf ? b.compact.sort_by(&:created_at).reverse! : b.compact.sort_by(&:created_at).reverse!.paginate(:per_page=>25,:page=>page)
    end
   end


#To find the name of the tenant
def find_tenant_legal_name
  if((@lease && !@lease.nil? ) || (params[:lease_id].present? && params[:lease_id] != 'undefined' && !params[:lease_id].blank? && params[:lease_id] != ''))
  	abstract_title =  (params[:lease_id].present? && params[:lease_id] != 'undefined' && !params[:lease_id].blank? && params[:lease_id] != '')  ?  PropertyLeaseSuite.find_by_lease_id(params[:lease_id]).tenant.tenant_legal_name : ''
  else
    abstract_title = ''
   end
end

def find_month_for_alert_view
      month_ind = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        @date_month = []
        @months = []
         for i in Date.today.strftime("%m").to_i.. 12 do
			     @date_month << month_ind[i] +"'"+ Date.today.strftime("%y")
					 if i < 10
					 @months <<  Date.today.strftime("%Y") + "-" + "0" + i.to_s
					 else
						@months <<  Date.today.strftime("%Y") + "-" +  i.to_s
					 end
           if i == 12
						for j in 1...Date.today.strftime("%m").to_i do
				 	@date_month << month_ind[j] +"'"+ Date.today.next_year.to_date.strftime("%y")
					 if j < 10
					 @months <<  Date.today.next_year.to_date.strftime("%Y") + "-" + "0" + j.to_s
					 else
						@months <<  Date.today.next_year.to_date.strftime("%Y") + "-" +  j.to_s
					 end
				 end
				end
			end
      return @months
    end

  def find_alerts_for_month(month_val,property_id)
		 month = YAML::load(month_val)
		@leases = Lease.find(:all,:conditions=>['real_estate_property_id = ? and is_executed = ?',property_id,true])
		@insurance = Insurance.find(:all,:conditions=>['lease_id IN (?)' ,@leases])
    lease_id = PropertyLeaseSuite.find(:all,:conditions=>['lease_id IN (?)',@leases])
		@tenant= []
		lease_id.each do |val|
			@tenant << val.tenant_id
			end
   	@options = Option.find(:all,:conditions=>['tenant_id IN (?)',@tenant])
		cap_ex = CapEx.find(:all,:conditions=>['lease_id IN (?)' ,@leases])
		@tenant_imp = TenantImprovement.find(:all,:conditions=>['cap_ex_id IN (?)',cap_ex])
			@month_list = []
			@month_name = []
			if @leases.present? || @options.present? || @insurance.present? || @tenant_imp.present?
				find_lease_comm_exp(month,property_id)
        find_option_for_alert(month,property_id)
			@insurance.uniq.each do |ins|
        insurance_docs = ins.documents if ins.present?
        if insurance_docs.present?
          insurance_docs.each do |ins_doc|
          if ins_doc && ins_doc.expiration_date.present? && ins_doc.expiration_date.to_date.strftime("%Y-%m") == month
              @find_insurance =  Insurance.find_by_sql("select doc.expiration_date as expiration_date, doc.filename as filename,t.tenant_legal_name,pl.*,ins.* from documents doc inner join insurances ins on ins.id = doc.insurance_id left join leases l on ins.lease_id = l.id  left outer join property_lease_suites pl on pl.lease_id = l.id right join tenants t on pl.tenant_id = t.id and l.real_estate_property_id = #{property_id} and l.is_executed=true where doc.expiration_date between '#{month}-01' and '#{month}-31' and doc.expiration_date IS NOT NULL")
           end
          end
        end
					#~ if ins.expiration_date.present? && ins.expiration_date.to_date.strftime("%Y-%m") == month
						#~ @find_insurance = Insurance.find_by_sql("select ins.expiration_date,pl.*,t.tenant_legal_name from insurances ins inner join leases l on ins.lease_id = l.id left outer join property_lease_suites pl on pl.lease_id = l.id right join tenants t on pl.tenant_id = t.id and l.real_estate_property_id = #{property_id} and l.is_executed=true where ins.expiration_date between '#{month}-01' and '#{month}-31'")
					#~ end
					@find_insurance.present? && @find_insurance.compact.each do |l_month|
						@ins_suite_ids = l_month.suite_ids.present? && YAML::load(l_month.suite_ids).present? &&  l_month.expiration_date.present? && l_month.expiration_date.to_date.strftime("%Y-%m") == month
					  if @ins_suite_ids &&  l_month.expiration_date.present? && l_month.expiration_date.to_date.strftime("%Y-%m") == month
							@month_list << l_month.expiration_date.to_date.strftime("%B, %Y")
							@month_name << l_month.expiration_date.to_date.strftime("%b'%y")
				  	end
					end
				end

				@tenant_imp.uniq.each do |tmp|
					if tmp.work_start_date.present? &&  tmp.work_start_date.to_date.strftime("%Y-%m") == month
						@find_tmp = TenantImprovement.find_by_sql("select tmp.work_start_date,pl.*,t.tenant_legal_name from tenant_improvements tmp inner join cap_exes cp on tmp.cap_ex_id = cp.id left outer join property_lease_suites pl on pl.lease_id = cp.lease_id right join tenants t on pl.tenant_id = t.id  right join leases l on pl.lease_id = l.id  and l.real_estate_property_id = #{property_id} and l.is_executed=true where tmp.work_start_date between '#{month}-01' and '#{month}-31'")
					end
					@find_tmp.present? && @find_tmp.each do |l_month|
						@tmp_suite_ids =  l_month.suite_ids.present? &&  YAML::load(l_month.suite_ids).present? && l_month.work_start_date.present? &&  l_month.work_start_date.to_date.strftime("%Y-%m") == month
					 if @tmp_suite_ids && l_month.work_start_date.present? && l_month.work_start_date.to_date.strftime("%Y-%m") == month
					@month_list << l_month.work_start_date.to_date.strftime("%B, %Y")
          @month_name << l_month.work_start_date.to_date.strftime("%b'%y")
						end
					end
				end
      end
      @month = month
      return @month
   end

   def find_lease_comm_exp(month,property_id)
    		@leases.uniq.each do|lease|
				if lease.expiration? && lease.expiration.to_date.strftime("%Y-%m") == month || lease.commencement? && lease.commencement.to_date.strftime("%Y-%m") ==  month
					@find_lease = Lease.find_by_sql("select l.commencement as commencement,l.expiration as expiration ,l.mtm as mtm, t.tenant_legal_name as tenant_legal_name, ps.* from leases l right join property_lease_suites ps on l.id = ps.lease_id inner join tenants t  on ps.tenant_id = t.id and l.real_estate_property_id = #{property_id} and l.is_executed=true where l.commencement between '#{month}-01' and '#{month}-31'or l.expiration between '#{month}-01' and '#{month}-31'")
				end
					@find_lease.present? && @find_lease.each do |l_month|
						@lease_com =  l_month.suite_ids.present? && YAML::load(l_month.suite_ids).present? && (l_month.expiration.present? && l_month.expiration.to_date.strftime("%Y-%m") == month || l_month.commencement.present? && l_month.commencement.to_date.strftime("%Y-%m") ==  month)
					 if l_month.suite_ids.present? && YAML::load(l_month.suite_ids).present? &&  l_month.expiration.present? && l_month.expiration.to_date.strftime("%Y-%m") == month
					@month_list << l_month.expiration.to_date.strftime("%B, %Y")
					@month_name << l_month.expiration.to_date.strftime("%b'%y")
					elsif  l_month.suite_ids.present? && YAML::load(l_month.suite_ids).present? &&  l_month.commencement.present? && l_month.commencement.to_date.strftime("%Y-%m") == month
						@month_list << l_month.commencement.to_date.strftime("%B, %Y")
						@month_name << l_month.commencement.to_date.strftime("%b'%y")
						end
					end
				end
return @find_lease
      end

    def find_option_for_alert(month,property_id)
				@options.compact.uniq.each do |opt|
						if opt.option_end.present? && opt.option_end.to_date.strftime("%Y-%m") == month || opt.notice_end.present? && opt.notice_end.to_date.strftime("%Y-%m") == month || opt.option_start.present? && opt.option_start.to_date.strftime("%Y-%m") == month || opt.notice_start.present? && opt.notice_start.to_date.strftime("%Y-%m") == month
								@find_option = Option.find_by_sql("select opt.*,t.tenant_legal_name,pl.* from options opt inner join tenants t on opt.tenant_id = t.id left outer join property_lease_suites pl on pl.tenant_id = t.id right join leases l on pl.lease_id = l.id and l.real_estate_property_id = #{property_id} and l.is_executed=true where opt.option_start between '#{month}-01' and '#{month}-31'  or opt.notice_start between '#{month}-01' and '#{month}-31' and opt.option_end between '#{month}-01' and '#{month}-31' or opt.notice_end between '#{month}-01' and '#{month}-31'")
						end
					end
					@find_option.present? && @find_option.each do |l_month|
					@opt_suite_ids = l_month.suite_ids.present? && YAML::load(l_month.suite_ids).present? && ( l_month.option_end.present? && l_month.option_end.to_date.strftime("%Y-%m") == month ||l_month.notice_end.present? && l_month.notice_end.to_date.strftime("%Y-%m") == month || l_month.option_start.present? && l_month.option_start.to_date.strftime("%Y-%m") == month || l_month.notice_start.present? && l_month.notice_start.to_date.strftime("%Y-%m") == month)
					if @opt_suite_ids  &&   l_month.option_start.present? && l_month.option_start.to_date.strftime("%Y-%m") == month
					@month_list << l_month.option_start.to_date.strftime("%B, %Y")
					@month_name << l_month.option_start.to_date.strftime("%b'%y")
					elsif @opt_suite_ids  &&  l_month.option_end.present? && l_month.option_end.to_date.strftime("%Y-%m") == month
						@month_list << l_month.option_end.to_date.strftime("%B, %Y")
						@month_name << l_month.option_end.to_date.strftime("%b'%y")
						elsif @opt_suite_ids  &&  l_month.notice_start.present? && l_month.notice_start.to_date.strftime("%Y-%m") == month
							@month_list << l_month.notice_start.to_date.strftime("%B, %Y")
							@month_name << l_month.notice_start.to_date.strftime("%b'%y")
							elsif @opt_suite_ids  &&  l_month.notice_end.present? && l_month.notice_end.to_date.strftime("%Y-%m") == month
								@month_list << l_month.notice_end.to_date.strftime("%B, %Y")
								@month_name << l_month.notice_end.to_date.strftime("%b'%y")
  					end
          end
          return @find_option
  end

     # This is for displaying the date in 25 jan 2012 format
  def lease_date_format(date)
      date.strftime("%m/%d/%Y") rescue nil  if date.present?
  end

  #To display logo and company name in PDF
  def find_logo_and_company_name
    check_user_logo = current_user.logo_image.nil?
    logo_img = check_user_logo ? (find_logo_extension.nil? ? "/images/logo_pdf.png" : find_logo_extension.public_filename(:thumb)) : current_user.logo_image.public_filename
    client = ClientSetting.find(:first,:conditions=>["separate_email = '#{current_user.email}' or  extension = \'#{current_user.email.split('@')[1]}\'"])
    client_company_name = User.find_by_id(client.user_id).company_name if client
    company_name = current_user.company_name ? current_user.company_name : (client.present? ? client_company_name : 'Your Company Name')
    return logo_img,company_name
  end

  def options_and_ti(tenant)
	string = ""
  if tenant.present?
	options_collection = tenant.options
	options_collection.each do |option|
		option_start = option.try(:option_start) ? "#{option.try(:option_type).present? ? ':' : ''} #{option.option_start.strftime('%m/%y')}" : ''
		option_end =  option.try(:option_end) ? " to #{option.option_end.strftime('%m/%y')}" : ''
    string << "#{option.try(:option_type)}#{option_start}#{option_end}#{ ((option.try(:option_type).present? || option_start.present? || option_end.present?) && option != options_collection.last) ? ', ' : '' }"
    end
	end
	return string
end

 #Method moved from controller to helper as used for inc proj and abstract top bar display#
    def mgmt_lease_details(lease)
    @lease = lease
    if @lease.present?
      @property_name = @lease.real_estate_property.property_name
      @property_lease_suite =  @lease.property_lease_suite
      @suite_ids = @property_lease_suite.suite_ids
      @suites, @suite_nos , @lease_rentable_sqft = Suite.get_suite_details(@suite_ids)

      # Invoking cap_ex.rb for getting below details
      @cap_ex, @tenant_improvements, @tenant_improvements_total_amount, @tenant_improvements_average_of_total_amount, @tenant_improvements_total_amount_psf, @tenant_improvements_average_of_total_amount_psf, @leasing_commissions,
      @procurement_and_listing_leasing_commissions, @bonus_leasing_commissions,@check_leasing_commissions_first_year_percentages,
      @other_exps, @other_exps_total_amount = CapEx.get_cap_ex_details(@lease.cap_ex)

      # Invoking tenant.rb for getting below details
      @tenant, @info, @options, @option_types = Tenant.get_tenant_details(@lease.tenant)

      # Invoking Rent.rb for getting below details
      @rent, @rent_schedules,@rent_schedules_total_amount_per_month, @rent_schedules_total_rent_revenue,@procurement_leasing_commission_total_amount, @listing_leasing_commission_total_amount, @rent_schedules_leasing_commissions_total_amount, @display_leasing_commissions_total_amount, @other_revenues, @parkings, @percentage_sales_rents, @displayed_percentage_sales_rents,
      @final_percentage_sales_rent, @sales_percentage_total, @estimation_sales_total, @total_rent_revenue, @total_other_revenue,
      @total_parking_revenue, @sales_revenue, @total_lease_revenue,@total_base_rent_revenue, @total_escalation_revenue,@budget_psf = Rent.rent_details(@lease.rent, @lease, @check_leasing_commissions_first_year_percentages, @leasing_commissions, @lease_rentable_sqft)

       @procurement_leasing_commission_dollar_per_sqft, @listing_leasing_commission_dollar_per_sqft, @bonus_leasing_commission_dollar_per_sqft, @leasing_commission_total_dollar_per_sqft = LeasingCommission.find_dollar_per_sqft_of_leasing_commissions(@lease_rentable_sqft, @procurement_leasing_commission_total_amount, @listing_leasing_commission_total_amount, @bonus_leasing_commissions.try(:first).try(:total_amount))

      @total_lease_capital_costs = LeasingCommission.find_lease_capital_cost(@tenant_improvements_total_amount.to_f , @display_leasing_commissions_total_amount.to_f , @other_exps_total_amount.to_f)
      @net_lease_cash_flow = @total_lease_revenue.to_f - @total_lease_capital_costs.to_f
      @net_lease_cash_flow_psf = IncomeProjection.net_lease_cash_flow_psf(@net_lease_cash_flow, @lease_rentable_sqft) #Added to display the actual psf val in abstract top bar#
    end
  end

  #Method added to calculate the month based on financial update date#
  def calc_for_financial_data_display
    date_for_financial_update = current_user.try(:client).try(:monthly_financial_closing_day)
    if Date.today.day <= date_for_financial_update
      @month_format = Date.today.prev_month #for trailing months calc#
      @financial_month = Date.today.prev_month.prev_month.month
      @financial_year = Date.today.prev_month.prev_month.year
    elsif Date.today.day > date_for_financial_update
      @month_format = Date.today #for trailing months calc#
      @financial_month = Date.today.prev_month.month
      @financial_year = Date.today.prev_month.year
    end
    return @financial_month,@financial_year,@month_format
  end

  #Common method used to find the actuals for yrforecast calc (except for cash sub view)#
  def common_method_for_yrforecast
    calc_for_financial_data_display
    unless @result.nil?
      @month = @result.flatten.to_s
      year_to_date = @financial_month
      @ytd_actuals= []
      for m in 1..year_to_date
        if @month.include?("#{Date::MONTHNAMES[m].downcase}")
          @ytd_actuals << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
        else
          @ytd_actuals << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
        end
      end
    end
    @ytd_actuals = Date.today.month == 1 ? 0 : @ytd_actuals.join("+") if !@ytd_actuals.nil?
    year_date = (Date.today.month == 1 && @financial_month == 12) ? 1 : (Date.today.month == 2 && @financial_month == 12) ? 2 :  @financial_month + 1
    @ytd_budget= []
    for m in year_date..12
      @ytd_budget << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
    end
    @ytd_budget = @ytd_budget.join("+")
    return @ytd_actuals,@ytd_budget,@financial_month
  end

  #Method used display the financial month in portfolio overview and in Yrforecast msg#
  def find_financial_month_update
    calc_for_financial_data_display
    months = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    @month_value = months[@financial_month]
    year_date = (Date.today.month == 1 && @financial_month == 12) ? 1 : (Date.today.month == 2 && @financial_month == 12) ? 2 :  @financial_month + 1
    @month_financial = months[year_date]
    return @month_value,@month_financial,@financial_year
  end


  def find_portfolios_properties_in_megadrop
      @portfolio_type=PortfolioType.find_by_name('Real Estate')
      @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,@portfolio_type.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc")
      #~ @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
      @portfolio_index= true
      @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolios.first,User.current.id,params[:prop_folder])  if !@portfolios.blank?
      if @notes && !@notes.empty?
        @note = @notes.first
        @note_old =  @note
      end
    end

    def url_formation_for_mega_drop_down(port_id,prop_id,leasing_type)
      controller = params[:controller]
      action = params[:action]

dashboard_url = "/dashboard/#{port_id}/financial_info/#{prop_id}/financial_info"

      if action.eql?("financial_info")
        url = "/dashboard/#{port_id}/financial_info/#{prop_id}/financial_info"
      elsif((action.eql?("rent_roll") || action.eql?("management")) && (controller.eql?("performance_review_property") || controller.eql?("lease")) && (leasing_type.eql?("Multifamily")))
        url = "/performance_review_property/rent_roll?portfolio_id=#{port_id}&id=#{prop_id}&property_id=#{prop_id}&partial_page=rent_roll_highlight&tl_year=#{Time.now.year}&from_lease=ya"
      elsif((action.eql?("management") || action.eql?("dashboard_terms")) && controller.eql?("lease"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/management/#{prop_id}/management" : dashboard_url
      elsif(action.eql?("pipeline") || action.eql?("show_pipeline"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/pipeline/#{prop_id}/property_pipeline" : dashboard_url
      elsif(action.eql?("alert"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/alert/#{prop_id}/property_alert" : dashboard_url
      elsif(action.eql?("stacking_plan"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/stacking_plan/#{prop_id}/stacking_plan" : dashboard_url
      elsif(action.eql?("budget"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/budget/#{prop_id}/budget" : dashboard_url
      elsif(action.eql?("encumbrance"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/encumbrance/#{prop_id}/property_encumb" : dashboard_url
      elsif(action.eql?("rent_roll")  && (controller.eql?("lease") || controller.eql?("performance_review_property")) && leasing_type.eql?("Commercial") )
        url = "/lease/#{port_id}/rent_roll/#{prop_id}/property_rentroll"
      elsif(action.eql?("suites"))
        url = leasing_type.eql?("Commercial") ? "/lease/#{port_id}/suites/#{prop_id}/suites_form" : dashboard_url
      elsif(action.eql?("show_asset_files"))
        url = "/files/#{port_id}/#{prop_id}"
      elsif(action.eql?("add_property"))
        url ="/real_estates/add_property/#{port_id}/?property_id=#{prop_id}"
      elsif(action.eql?("news"))
        url = "/home/news?portfolio_id=#{port_id}&property_id=#{prop_id}"
      elsif (action.eql?("show"))
        url = "/real_estate/#{port_id}/properties/#{prop_id}?property_selection=true"
      elsif (action.eql?("property_info"))
        url = "/dashboard/#{port_id}/property_info/#{prop_id}/property_info"
      elsif (controller.eql?("collaboration_hub") && action.eql?("index"))
        #~ url = "/collaboration_hub?property_id=#{prop_id}"
        url = "/collaboration_hub?portfolio_id=#{port_id}&property_id=#{prop_id}&folder_id=#{Folder.folder_of_a_portfolio(port_id).try(:id)}"
      elsif params[:deal_room]
        url = "/transaction?deal_room=true&portfolio_id=#{port_id}&property_id=#{prop_id}"
      #~ elsif action.eql?("show_pipeline")
        #~ url = goto_asset_view_path(current_user.id)
      elsif action.eql?("property_commercial_leasing_info")
        url = "/dashboard/#{port_id}/property_commercial_leasing_info/#{prop_id}"
      elsif action.eql?("property_multifamily_leasing_info")
        url = "/dashboard/#{port_id}/property_multifamily_leasing_info/#{prop_id}"
      elsif (controller.eql?("users") && (action.eql?("welcome") || action.eql?("dashboard_commercial_leases")))
        #~ url = "/dashboard/property_info?property_id=#{prop_id}&portfolio_id=#{port_id}"
        url = "/dashboard/#{port_id}/financial_info/#{prop_id}/financial_info"
      elsif (controller.eql?("dashboard") && action.eql?("trends"))
        #~ url = "/dashboard/property_info?property_id=#{prop_id}&portfolio_id=#{port_id}"
        url = "/dashboard/#{port_id}/trends/#{prop_id}"
      elsif (controller.eql?("nav_dashboard") && action.eql?("dashboard"))
        #~ url = "/dashboard/property_info?property_id=#{prop_id}&portfolio_id=#{port_id}"        
        url = "/nav_dashboard/dashboard?portfolio_id=#{port_id}&property_id=#{prop_id}"
      end
      return url
    end

  def find_property_details

     #~ all_portfolios = Portfolio.find_shared_and_owned_portfolios(current_user.id)
     all_portfolios = Portfolio.find_portfolios(current_user)

    last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)

      portfolio = session[:portfolio__id].present? ? session[:portfolio__id] : params[:real_estate_id].present? ? params[:real_estate_id].to_i : params[:portfolio_id].present? ? params[:portfolio_id].to_i : params[:pid].present? ? params[:pid].to_i : (params[:id].present? && params[:action].eql?("add_property")) ? params[:id].to_i : last_portfolio.present? ? last_portfolio.try(:id) : @portfolio.present?  ? @portfolio.try(:id) : last_portfolio.try(:id)

portfolio_obj = Portfolio.find_by_id(portfolio)

      note = session[:property__id].present? ? session[:property__id] : params[:property_id].present? ? params[:property_id].to_i : (params[:id].present? && !params[:action].eql?("add_property")) ? params[:id].to_i : params[:nid].present? ? params[:nid].to_i : portfolio_obj.present? ? first_property.try(:id) : @note.present? ? @note.id : first_property.try(:id)


property_obj = RealEstateProperty.find_by_id(note)
@portfolio_obj = portfolio_obj
@property_obj = property_obj
return @portfolio_obj,@property_obj
  end

def mega_dd_sqft_cals(portfolio)
  @total_sf = 0
  properties = RealEstateProperty.find_properties_of_portfolio(portfolio.try(:id)).uniq #.includes(:commercial_lease_occupancies)
  property_ids = properties.map(&:id) || []
  if portfolio.try(:leasing_type).eql?("Commercial")
  @total_sf = Suite.where(:real_estate_property_id => property_ids).sum(:rentable_sqft)
  else
  #~ @total_sf = PropertySuite.where(:real_estate_property_id => property_ids).count(:suite_number)  
  properties && properties.uniq.each do |property|
    if property.try(:leasing_type).eql?("Multifamily") && portfolio.try(:leasing_type).eql?("Multifamily")
      multifamily_prop_units  = calculations_multifamily(property)
      @total_sf += ( multifamily_prop_units.present? ? multifamily_prop_units : 0 )

    end
  end  
end
return @total_sf
=begin
  properties && properties.each do |property|
    if property.try(:leasing_type).eql?("Commercial") && portfolio.try(:leasing_type).eql?("Commercial")
     @total_sf += calculations_commercial(property)
    elsif property.try(:leasing_type).eql?("Multifamily") && portfolio.try(:leasing_type).eql?("Multifamily")
     @total_sf += calculations_multifamily(property)
    end
  end
  return
=end
end

def calculations_properties(property)
  @note = property
  find_occupancy_values
  year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',property.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
  year = year.compact.empty? ? nil : year[0].year
  os = CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",property.id,year,get_month(year)],:order => "month desc",:limit =>1)
  if os.present?
    renewal_occu = property.try(:commercial_lease_occupancies).where(:year=> year, :month=>os.first.month).try(:first).try(:renewals_actual)
    @total_renewal_sf = @total_renewal_sf + (renewal_occu.present? ? renewal_occu : 0)
    renewal_bud = property.try(:commercial_lease_occupancies).where(:year=> year, :month=>os.first.month).try(:first).try(:renewals_budget)
    @total_renewal_bud = @total_renewal_bud + (renewal_bud.present? ? renewal_bud : 0) if @total_renewal_bud.present?
    new_leases_occu = property.try(:commercial_lease_occupancies).where(:year=> year, :month=>os.first.month).try(:first).try(:new_leases_actual)
    @total_new_leases_sf = @total_new_leases_sf + (new_leases_occu.present? ? new_leases_occu : 0)
    new_leases_bud = property.try(:commercial_lease_occupancies).where(:year=> year, :month=>os.first.month).try(:first).try(:new_leases_budget)
    @total_new_leases_bud = @total_new_leases_bud + (new_leases_bud.present? ? new_leases_bud : 0) if @total_new_leases_bud.present?
  end
end


def calculations_commercial(property)
  property_sqft = property.try(:suites).sum(:rentable_sqft) if property.try(:leasing_type).eql?("Commercial")
end

def calculations_multifamily(property)
   #~ property_sqft = property.try(:property_suites).count(:suite_number) if property.try(:leasing_type).eql?("Multifamily") #for multifamily need to take from property suites and the count of suite number#   
  @note = property
  year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
  year = year.compact.empty? ? nil : year[0].year
  os = PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1) 
  property_sqft = property.try(:property_occupancy_summaries).where(:year=> year, :month=>os.first.month).try(:first).try(:current_year_units_total_actual) if os.present?  
  return property_sqft
end

def percentage_cals_for_bar(property,tot_sqft)
  suite_properties = Suite.where("suite_no is not null and real_estate_property_id=?",property.try(:id))
suite_all_sqft = suite_properties.sum(:rentable_sqft)
percentagee = (suite_all_sqft.present? && suite_all_sqft!= 0.0) ? (tot_sqft * 100 ) / suite_all_sqft : 0
sqft_percentage = "#{number_with_precision(percentagee, :precision=>2)}"
return bar_percentage_tenants(sqft_percentage,true)
end

  def bar_percentage_tenants(val,flag=nil)
    val = val.to_f/20*100 if flag
    val = val >=100.0 ? 100.0 : val
    "#{val.round}%"
  end

  def find_dashboard_portfolio_display
     if session[:portfolio__id].present?  && session[:property__id].blank?
      portfolio_id = session[:portfolio__id]
      @note = Portfolio.find_by_id(portfolio_id)
      @resource = "'Portfolio'"
      elsif session[:portfolio__id].blank? && session[:property__id].present?
         session[:property__id] = session[:property__id].to_s.include?("review")  ? session[:property__id].split("?")[0] : session[:property__id]
        @note = RealEstateProperty.find_real_estate_property(session[:property__id])
        @resource = "'RealEstateProperty'"
        @portfolio = Portfolio.find_by_id(params[:portfolio_id]) if params[:portfolio_id].present?
      end
    end

  def per_sqft_available
    @note.user_id==current_user.id ? true : ((@note.gross_rentable_area.blank? || @note.gross_rentable_area==0) ? nil : true)
  end

  def no_of_units_available
    @note.user_id==current_user.id ? true : ((@note.no_of_units.blank? || @note.no_of_units==0) ? nil : true)
  end

  def find_last_visited_url(current_user)
    current_user.last_visited_url = ""
    financial_access = current_user.try(:client).try(:is_financials_required)
    #~ if current_user.email.eql?("kwilliams.amp@gmail.com") || current_user.email.eql?("kwilliams.amp.dev@gmail.com")
      #~ current_user.last_visited_url = financial_access ? "/dashboard/106/financial_info" : portfolio_leasing_info_url(106) #hard coded for kwilliams  login to Cal Office#
    #~ els
    if session[:portfolio__id].present? && session[:property__id].blank?
      portfolio_access = Portfolio.find_by_id_and_user_id_and_is_basic_portfolio(session[:portfolio__id],current_user.id,false)
      if portfolio_access.present?
      current_user.last_visited_url = "/nav_dashboard/dashboard?portfolio_id=#{session[:portfolio__id]}"
      else
         last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
          if last_portfolio.present? && first_property.present?
           current_user.last_visited_url = "/nav_dashboard/dashboard?portfolio_id=#{last_portfolio.id}&property_id=#{first_property.id}"
          end
      end
    elsif session[:property__id].present? && session[:portfolio__id].blank?
      property = RealEstateProperty.find_real_estate_property(session[:property__id],nil)
      portfolio_access = Portfolio.find_by_id_and_user_id_and_is_basic_portfolio(property.try(:portfolio_id),current_user.id,false)
      
      if portfolio_access.present?
      current_user.last_visited_url =  "/nav_dashboard/dashboard?portfolio_id=#{property.try(:portfolio_id)}"
      else
        current_user.last_visited_url =  "/nav_dashboard/dashboard?portfolio_id=#{property.try(:portfolio_id)}&property_id=#{property.try(:id)}"        
         #~ last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
          #~ if last_portfolio.present? && first_property.present?
            #~ current_user.last_visited_url = "/nav_dashboard/dashboard?portfolio_id=#{last_portfolio.id}&property_id=#{first_property.id}"
          #~ end          
      end        
    end
    current_user.save(false)
  end

  def portfolio_leasing_info_url(port_id)
    portfolio = Portfolio.find_by_id(port_id)
    leasing_url = portfolio.try(:leasing_type).eql?("Commercial") ? "/dashboard/#{portfolio.id}/portfolio_commercial_leasing_info" : "/dashboard/#{portfolio.id}/portfolio_multifamily_leasing_info"
    return leasing_url
  end


  def property_leasing_info_url(port_id,prop_id)
    property = RealEstateProperty.find_by_id(prop_id)
    leasing_url = property.try(:leasing_type).eql?("Commercial") ? "/dashboard/#{port_id}/property_commercial_leasing_info/#{property.id}" : "/dashboard/#{port_id}/property_multifamily_leasing_info/#{property.id}"
    return leasing_url
  end


  #Find the properties of the user
  def find_properties_client_user(user)
     users_properties_collection=SharedFolder.find(:all,:select=>[:id,:user_id,:is_property_folder,:real_estate_property_id],:conditions=>["user_id=? AND is_property_folder=?",user.id,true])
    users_properties=users_properties_collection.present? ? users_properties_collection.map(&:real_estate_property_id) : []
    properties =RealEstateProperty.find(:all,:select=>[:id,:property_name],:conditions=>["id in (?) and property_name NOT in (?)",users_properties,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]
    ])
    if properties.count>2
    count=properties.count-2
    filtered_properties= properties[0..1].map(&:property_name)
    filtered_properties_id=properties[0..1].map(&:id)
    else
    count=""
     filtered_properties_id=properties[0..1].map(&:id)
    filtered_properties=properties.map(&:property_name)
    filtered_properties_id=filtered_properties_id.present? ?  filtered_properties_id : []
    end
  return count,filtered_properties,filtered_properties_id
end

  def find_user_roles(user)
    roles=user.roles.map(&:name).join(",")
  end

  def find_user_portfolios(user)
    users_portfolios_collection=SharedFolder.find(:all,:conditions=>["user_id=? AND is_portfolio_folder=?",user.id,true])
    users_portfolios=users_portfolios_collection.present? ? users_portfolios_collection.map(&:portfolio_id) : []
    portfolios=Portfolio.find(:all,:conditions=>["id in (?) and name NOT in (?)",users_portfolios,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]
    ])
    if portfolios.count>2
    portfolios_count=portfolios.count-2
    filtered_portfolios_id=portfolios[0..1].map(&:id)
    filtered_portfolios= portfolios[0..1].map(&:name)
    else
    portfolios_count=""
    filtered_portfolios_id=portfolios[0..1].map(&:id)
    filtered_portfolios=portfolios.map(&:name)
    filtered_portfolios_id=filtered_portfolios_id.present? ?  filtered_portfolios_id : []
    end
  return portfolios_count,filtered_portfolios,filtered_portfolios_id
end

    def find_properties_based_on_portfolios(portfolio_data)
    properties=portfolio_data.real_estate_properties
    if properties.count>2
    count=properties.count-2
    filtered_properties_id=properties[0..1].map(&:id)
    filtered_properties= properties[0..1].map(&:property_name)
    else
    count=""
    filtered_properties_id=properties[0..1].map(&:id)
    filtered_properties=properties.map(&:property_name)
    filtered_properties_id=filtered_properties_id.present? ?  filtered_properties_id : []
    filtered_properties=filtered_properties.present? ?  filtered_properties : []
  end
  return count,filtered_properties,filtered_properties_id
end

#To check whether the user has files
 def check_shared_documents
     current_user && current_user.shared_documents.present? ? true : false
   end
   
#Nav dashboard multifamily property vacant,notice,available
def multifamily_property_vacant_notice_avail
  sundays=RealEstateProperty.get_last_week_dates[0].reverse
  sundays && sundays.each do |sunday|
   weekly_data = calculate_property_weekly_display_data(sunday)
   if weekly_data.flatten.present?
      count = @property_week_vacant_total.count
      property_weekly_display_total(count)
      break
    end
  end
end  

#Alerts to show in nav dashboard
def alerts_nav_dashboard
  count=0
  if params[:property_id]
    find_alerts_for_month(Date.today.strftime("%Y-%m"),params[:property_id])
    count +=(@find_insurance.present? ? @find_insurance.count : 0)+(@find_tmp.present? ? @find_tmp.count : 0)+(@find_lease.present? ? @find_lease.count : 0)+(@find_option.present? ? @find_option.count : 0)
    find_alerts_for_month(Date.today.next_month.strftime("%Y-%m"),params[:property_id])
     count +=(@find_insurance.present? ? @find_insurance.count : 0)+(@find_tmp.present? ? @find_tmp.count : 0)+(@find_lease.present? ? @find_lease.count : 0)+(@find_option.present? ? @find_option.count : 0)
  else
    @real_estate_property_ids && @real_estate_property_ids.each do |property_id|
       find_alerts_for_month(Date.today.strftime("%Y-%m"),property_id)
    count +=(@find_insurance.present? ? @find_insurance.count : 0)+(@find_tmp.present? ? @find_tmp.count : 0)+(@find_lease.present? ? @find_lease.count : 0)+(@find_option.present? ? @find_option.count : 0)
    find_alerts_for_month(Date.today.next_month.strftime("%Y-%m"),property_id)
     count +=(@find_insurance.present? ? @find_insurance.count : 0)+(@find_tmp.present? ? @find_tmp.count : 0)+(@find_lease.present? ? @find_lease.count : 0)+(@find_option.present? ? @find_option.count : 0)
      end
  end
  return count
end

end
