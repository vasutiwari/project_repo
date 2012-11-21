class TreeViewController < ApplicationController

# Move & copy functionality in the dropview structure



  def move_action

    real_id = (params[:element_type] and params[:element_type] == "document") ? Document.find_by_id(params[:id]).real_estate_property_id : Folder.find_folder(params[:id]).real_estate_property_id
    @property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(real_id,0,0)
    @property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(real_id,-2,1) if @property_folder.blank? and params[:bulk_upload] == 'true'

    @value  = ''
    if @property_folder
      @tree_structure = []
      form_tree_structure_recursive
    end
    @value = ActionController::Base.helpers.raw(@tree_structure.join('')) if @tree_structure
    render :layout => false
  end



  def form_tree_structure_recursive

    @my_files_collection = []
    portfolio_list = find_portfolio_list
    if portfolio_list && !portfolio_list.empty?
      @tree_structure = []
      @tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:operation] == "move" || params[:operation] == "copy" ) ? 'folder' : 'file'} to select</div><br/><br/><br/>"
      @tree_structure << "<ul id='browser' class='filetree'>"
      @j = 0
      for portfolio in portfolio_list.uniq
        if portfolio
          insert_first_level_portfolio_name_structure(portfolio) if !portfolio.real_estate_properties.empty?
          find_manage_real_estate_shared_folders('false') if @j == 0
          property_collection = portfolio.real_estate_properties.where(:client_id=>current_user.client.id) if current_user && current_user.client
          property_collection = property_collection.group("property_name") if property_collection
          @folders_in_portfolios,@shared_folders_added = [],false
          insert_property_sub_folders_in_tree(property_collection)
          @tree_structure << "</li>"  if !portfolio.real_estate_properties.empty?
          @folders_in_portfolios =  @folders_in_portfolios.reject{|f| f == @folder} if !@folders_in_portfolios.empty? && params[:element_type] !="document"
          @portfolio_name_in_tree_structure = []
          @portfolio_name_in_tree_structure << @portfolio_name_in_tree_structure.uniq
          if params[:deal_room] == "true"
            @deal_name_in_tree_structure = []
            @deal_name_in_tree_structure << @deal_name_in_tree_structure.uniq
          end
          @tree_structure.delete_if{|t| t == "<li><span class='folder'>#{@portfolio_name_in_tree_structure}</span>" } if @folders_in_portfolios.empty? && !portfolio.real_estate_properties.empty?
          @tree_structure.delete_if{|t| t == "<li><span class='folder'>#{@deal_name_in_tree_structure}</span>" } if @folders_in_portfolios.empty? && !portfolio.real_estate_properties.empty?
        end
        @j +=1
      end
      @tree_structure << "</ul>"
    end




=begin
    @fold_template=Template.find_by_sql("select * from templates where propert_type_name='Industrial' and client_id=1")
    puts("**********************************")
    puts(@fold_template.first.folder_name)
    puts(params[:sort])
    @tree_structure = []
    @tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:operation] == "move" || params[:operation] == "copy" ) ? 'folder' : 'file'} to select</div><br/><br/><br/>"
    @tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a  to select</div><br/><br/><br/>"

    @tree_structure << "<ul id='browser' class='filetree'>"
    @tree_structure << "</ul>"
    @fold_template.each do|p|
    @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"
=end
    end



  #to find_the shared properties -portfolios ,portfolios created by me list

  def find_portfolio_list
    @folder = Folder.find_folder(params[:folder_id])
    @real_estate_property_id = @folder.real_estate_property_id
    @real_estate_property = RealEstateProperty.find_real_estate_property(@real_estate_property_id)
    #shared_folder_portfolios = Portfolio.joins(:real_estate_properties => [:folders => :shared_folders]).where("portfolios.portfolio_type_id =? and shared_folders.user_id = ? and shared_folders.is_property_folder =? and shared_folders.client_id =?", 2,User.current.id,1,User.current.client_id).select("portfolios.id")
    #~ shared_folder_portfolios = Portfolio.find_by_sql("SELECT p.id FROM shared_folders sf INNER JOIN folders ft ON sf.folder_id = ft.id INNER JOIN real_estate_properties pt ON ft.real_estate_property_id = pt.id INNER JOIN portfolios p ON pt.portfolio_id = p.id and p.portfolio_type_id = 2 and (sf.user_id = #{User.current.id}) and sf.is_property_folder = 1 and sf.client_id = #{User.current.client_id}" )
    #pids = shared_folder_portfolios.collect{|p| p.id}.uniq unless shared_folder_portfolios.empty?
    #@shared_portfolio_list = Portfolio.find(:all,:conditions => ["id in (?)",pids]) if pids && !pids.empty?
    portfolio_list = current_user.portfolios.find(:all,:conditions => ["portfolio_type_id=? and name not in (?)", PortfolioType.find_by_name("Real Estate").id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
    my_files_portfolio_list = Portfolio.find_all_by_name_and_user_id("portfolio_created_by_system",User.current).to_a
    my_deal_portfolio_list = Portfolio.find_all_by_name_and_user_id("portfolio_created_by_system_for_deal_room",User.current).to_a
    bulk_upload_portfolio_list = (params[:bulk_upload] == 'true') ? Portfolio.find_all_by_name_and_user_id("portfolio_created_by_system_for_bulk_upload",User.current).to_a : []
   # @shared_portfolio_list = @shared_portfolio_list.nil? || (@shared_portfolio_list && @shared_portfolio_list.empty?) ? [] : @shared_portfolio_list
    #portfolio_list =  my_files_portfolio_list + my_deal_portfolio_list + portfolio_list + @shared_portfolio_list + bulk_upload_portfolio_list
    return portfolio_list
    end


  def recursive_function_for_move_copy_functionality(parent_folder,display_ul)
    if params[:element_type] == "document"
      d =  Document.find_by_id(params[:id])
      current_folder_id =  d.folder_id if !d.nil?
    else
      current_folder_id =  params[:id]
    end
    if parent_folder.id.to_s != current_folder_id
      insert_property_name(parent_folder)
      children = find_shared_and_owned_folders_in_my_files(children,parent_folder)
      if (!children.nil? && !children.empty?)
        @tree_structure << "<ul>"
        if (!children.nil? && !children.empty?)
          @n=0
          for child in children
            if @my_files_collection.index(child).nil?
              recursive_function_for_move_copy_functionality(child,true)
              @folders_in_portfolios << child if check_is_folder_shared(child) == "true"
            end
            @my_files_collection << child
          end
        end
        @tree_structure << "</ul>"
      end
      @tree_structure << "</li>"  if check_is_folder_shared(parent_folder) == "true" && ((parent_folder.name != "my_files" && parent_folder.parent_id != 0) || (parent_folder.name != "my_files" && parent_folder.parent_id == 0))
    end
    @l = @l+1
  end

  #to display portfolio name in first level
  def insert_first_level_portfolio_name_structure(portfolio)
    if portfolio.name == "portfolio_created_by_system"
      @tree_structure << "<li><span class='folder'>Other Files</span>"
      @portfolio_name_in_tree_structure = 'Other Files'
    elsif portfolio.name == "portfolio_created_by_system_for_deal_room"
      @tree_structure << "<li><span class='folder'>Deal Room</span>"
      @deal_name_in_tree_structure = 'Deal Room'
    elsif portfolio.name == "portfolio_created_by_system_for_bulk_upload" and params[:bulk_upload] == 'true'
      @tree_structure << "<li><span class='folder'>Bulk Upload</span>"
      @deal_name_in_tree_structure = 'Bulk Upload'
    else
      @tree_structure << "<li><span class='folder'><a href='#' style=''>#{portfolio.name}</a></span>"
      @portfolio_name_in_tree_structure = portfolio.name
    end
    return @tree_structure
  end

  def task_add_files_using_tree
   @my_files_collection,@my_docs_collection = [],[]
   @restricted_folders = ["Excel Uploads","AMP Files"]
    portfolio_list = find_portfolio_list
    @document = Document.find_document(params[:document_id])
    @documents = Document.find_all_by_real_estate_property_id(@folder.real_estate_property_id)
    @folder = @document.folder if @document
    if !portfolio_list.empty?
      @tree_structure,@j= [], 0
      @tree_structure << "<ul id='browser' class='filetree'>"
      for portfolio in portfolio_list.uniq
        insert_first_level_portfolio_name_structure(portfolio)	if !portfolio.real_estate_properties.empty?
        find_manage_real_estate_shared_folders('false') if @j == 0
        @folders_docs_in_portfolios,@shared_folders_added = [],false
        insert_property_docs_in_tree(portfolio)
        @tree_structure << "</li>"   if !portfolio.real_estate_properties.empty?
        if @folders_docs_in_portfolios.empty?
          @tree_structure.delete_if{|t| t == "<li><span class='folder'>#{@portfolio_name_in_tree_structure}</span>" }
          @tree_structure.delete_if{|t| t == "<li><span class='folder'>#{@deal_name_in_tree_structure}</span>" }
        end
      end
      @j +=1
      @tree_structure << "</ul>"
    end
    @real_estate_property = RealEstateProperty.find_by_id(@folder.real_estate_property_id) if @folder
    render :layout => false
  end

  def recursive_function_for_add_file_functionality(parent_folder)
    if parent_folder.id.to_s != params[:id]
      if !((parent_folder.name == "my_files" ||parent_folder.name == "my_deal_room") && parent_folder.parent_id == 0) && check_is_folder_shared(parent_folder) == 'true'
        @tree_structure << "<li><span class='folder'><a href='#' style=''  id='style_folder_#{parent_folder.id}'> #{parent_folder.name} </a></span>"
        @folders_docs_in_portfolios << parent_folder
      end
      children,documents = find_shared_and_owned_files_in_my_files(children,parent_folder)
      if (!children.nil? && !children.empty?)  || ( !documents.nil? and !documents.empty?)
        @tree_structure << "<ul>"
        if (!children.nil? && !children.empty?)
          for child in children
           unless(@restricted_folders.index(child.name) && is_leasing_agent)
            recursive_function_for_add_file_functionality(child) if @my_files_collection.index(child).nil?
            @my_files_collection << child
            end
          end
        end
        if (!documents.nil? and !documents.empty?)
          for doc in documents
            if check_is_doc_shared(doc) == 'true' && doc.id.to_s != params[:document_id]
              @tree_structure << "<li><span class='file'><a href='#' style='' onclick='store_doc_id(#{doc.id});return false' id='style_doc_#{doc.id}'> #{doc.filename} </a></span></li>" if @my_docs_collection.index(doc).nil?
              @folders_docs_in_portfolios << doc
              @my_docs_collection << doc
            end
          end
        end
        @tree_structure << "</ul>"
      end
      @tree_structure << "</li>" if !((parent_folder.name == "my_files" ||parent_folder.name == "my_deal_room") && parent_folder.parent_id == 0) && check_is_folder_shared(parent_folder) == 'true'
    end
    @l = @l+1
  end

  # Moving , copying activity for folders,files,checklists
  def move_folder
    parent_folder =  Folder.find_folder(params[:folder_id])
    parent_folder1 = Folder.find_folder(parent_folder.parent_id)
    portfolio_id_old = parent_folder.portfolio_id
    @portfolio_old = portfolio_id_old
    folder_id_old = params[:folder_id]
    @folder = parent_folder
    @portfolio = @folder.portfolio
    @parent_folder = parent_folder
    move_folder_id =  Folder.find_folder(params[:move_folder_id])
    @moved_folder = move_folder_id
    @moved_portfolio_old = @moved_folder.portfolio_id
    params[:folder_id] = parent_folder.parent_id if !parent_folder.nil?		and !params[:element_type].nil?  and params[:element_type].blank?
    if params[:move_folder_id] and !params[:move_folder_id].blank?
      move_document(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id) if params[:element_type] == "document" and  params[:operation] and params[:operation] == "move"
      copy_document(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)  if params[:element_type] == "document" and  params[:operation] and params[:operation] == "copy"
      move_folders(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id) if params[:element_type] != "document" and  params[:operation] and params[:operation] == "move"
      copy_folder(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)  if params[:element_type] != "document" and  params[:operation] and params[:operation] == "copy"
    end
    display_collection_of_folders_docs_tasks
  end

  def single_file_upload_in_the_create_task
    if params[:from_portfolio_summary] == "true"
      single_file_upload_in_executive_summary
    else
      if params[:file]
        @task_file = TaskFile.new
        @task_file.uploaded_data = params[:file]
        @task_file.user_id = current_user.id
        fn = params[:task_id] ?  ['delect_selected_file_for_folder',params[:task_id]] : (params[:document_id] ?  ['delect_selected_file',params[:document_id]] : nil)
        @task_file.save
      end
      total = (!params[:already_upload_file].nil? and  !params[:already_upload_file].blank? ) ?  params[:already_upload_file]+","+@task_file.id.to_s	: @task_file.id.to_s
      val_list,final_list = '',[]
      val_list,final_list = display_file_collection_in_single_file_upload(total,val_list,final_list,fn)
      val_list = val_list +"<div class='coll3'></div>"
      responds_to_parent do
        render :update do |page|
          if !(!params[:already_upload_file].nil? and  !params[:already_upload_file].blank? )
            page.show 'upload_file'
          end
          page.replace_html  'upload_files_list',raw("<input type='hidden' name='already_upload_file' id='already_upload_file' value='#{final_list.join(",")}'/>")
          page.replace_html  'single_file_upload_list',raw(val_list)
          page << "jQuery('#toDisable').remove();"
          page.call "flash_writter", FLASH_MESSAGES['treeview']['2001']
        end
      end
    end
  end

  def add_file_using_treeview
    if params[:from_portfolio_summary] == 'true'
      add_secondary_docs_in_summary
    else
      @td = params[:add_doc_id]
     if params[:doc_id]
        display_file_using_treeview_file_with_doc
    else
      display_file_using_treeview_file_with_out_doc
    end
  end
end

def find_document_and_task_document_ids
  doc = Document.find_by_id(params[:doc_id])
  return doc
end

def  share_moveto_folders_docs_to_members(folders,documents,document_names,su)
  folders.each do |f|
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(f.id,su.user_id,su.sharer_id,f.real_estate_property_id)
    owner_folder = sf.folder
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(f.id,su.sharer_id,owner_folder.user_id,f.real_estate_property_id)
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(f.id,owner_folder.user_id,su.sharer_id,f.real_estate_property_id)
  end
  documents.each do |d|
    if d.filename != "Cash_Flow_Template.xls" && d.filename != "Rent_Roll_Template.xls"
      sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,su.user_id,su.sharer_id,d.real_estate_property_id,d.folder_id)
      owner_doc = sd.document
      sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,owner_doc.user_id,su.sharer_id,d.real_estate_property_id,d.folder_id)
      sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,su.sharer_id,owner_doc.user_id,d.real_estate_property_id,d.folder_id)
    end
  end
end

# Recursive function for copying folder functionality
def properties_subfolders_docs_documentnames_for_move_to_function(mf,af,pid)
  master_folders = Folder.find(:all,:conditions=> ["portfolio_id = ? and parent_id = ? and is_deleted = ?",pid,mf.id,false])
  master_files = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted = ?",mf.id,false])
  master_folders.each do |mfldr|
    fol = Folder.new
    fol.attributes = mfldr.attributes
    fol.parent_id = af.id
    fol.user_id = current_user.id
    fol.real_estate_property_id = af.real_estate_property_id
    fol.portfolio_id = af.portfolio_id
    fol.save
    properties_subfolders_docs_documentnames_for_move_to_function(mfldr,fol,pid)
  end
  master_files.each do |fl|
    path ="#{Rails.root.to_s}/public"+fl.public_filename.to_s
    temfile = Tempfile.new(fl.filename)
    begin
      temfile.write(File.open(path).read)
      temfile.flush
      upload_data = ActionDispatch::Http::UploadedFile.new({:filename=>fl.filename,:type=>fl.content_type, :tempfile=>temfile})
      d= Document.new
      d.attributes = fl.attributes
      d.uploaded_data = upload_data
      d.user_id = current_user.id
      d.folder_id = af.id
      d.real_estate_property_id = af.real_estate_property_id
      d.save
    ensure
      temfile.close
      temfile.unlink
    end
    @task_and_variance_task = false
    @loop =1
  end
end

def rename_my_files_and_tasks(parent_folder)
  if parent_folder.name  == "my_files" && parent_folder.is_master == false && parent_folder.parent_id == 0
    return "My Files"
  else
    return parent_folder.name
  end
end

def move_document(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)
  document = Document.find_by_id(params[:id])
  is_doc_exists = check_doc_exists(document.filename, params[:move_folder_id])
  modify_document_folder_id(document,is_doc_exists,move_folder_id)
  #remove_task_collaborators_move_to_copy_to(document)
  remove_document_collaborators(document)
  modify_shared_documents_folder_id(move_folder_id,document)
  share_doc_to_moved_folder_collaborators(document,move_folder_id)
  @msg =  FLASH_MESSAGES['treeview']['2002']
  Event.create_new_event("moved",current_user.id,nil,[document],current_user.user_role(current_user.id),document.filename,[rename_my_files_and_tasks(parent_folder),parent_folder.id,move_folder_id.name,move_folder_id.id])
end

def  copy_document(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)
  document = Document.find_by_id(params[:id])
  document_name = document.filename
  path ="#{Rails.root.to_s}/public"+document.public_filename.to_s
    tempfile = Tempfile.new(document.filename)
    begin
      tempfile.write(File.open(path).read)
      tempfile.flush
      upload_data = ActionDispatch::Http::UploadedFile.new({:filename=>document.filename,:type=>document.content_type, :tempfile=>tempfile})
      d= Document.new
      d.attributes = document.attributes
      d.uploaded_data = upload_data
      d.filename = document_name
      d.folder_id = params[:move_folder_id]
      d.real_estate_property_id = move_folder_id.real_estate_property_id
      d.user_id = current_user.id
      d.save
    ensure
      tempfile.close
      tempfile.unlink
    end
    members = share_file_to_parent_folder_collaborators(d,move_folder_id)
    @task_and_variance_task = false
    @loop= 1
    @msg =  FLASH_MESSAGES['treeview']['2003']
    Event.create_new_event("copied",current_user.id,nil,[document],current_user.user_role(current_user.id),document.filename,[rename_my_files_and_tasks(parent_folder),parent_folder.id,move_folder_id.name,move_folder_id.id])
end

def move_folders(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)
  folder = Folder.find_folder(params[:id])
  is_folder_exists = check_folder_exists(parent_folder.name, params[:move_folder_id])
  if is_folder_exists
    folder_name = find_folder_name(params[:move_folder_id],parent_folder.name) if !parent_folder.nil?
    if parent_folder.parent_id.to_i != params[:move_folder_id].to_i
      parent_folder.update_attributes(:name => folder_name,:parent_id => params[:move_folder_id],:real_estate_property_id =>move_folder_id.real_estate_property_id,:portfolio_id =>move_folder_id.portfolio_id)  if !parent_folder.nil?
    end
  else
    parent_folder.update_attributes(:parent_id => params[:move_folder_id],:real_estate_property_id =>move_folder_id.real_estate_property_id,:portfolio_id =>move_folder_id.portfolio_id)  if !parent_folder.nil?
  end
  #To remove previously shared collaborators
  remove_sharing_for_sub_folders_and_docs(folder.id, true)
  shared_folders = folder.shared_folders.collect{|s| s if s.user_id != current_user.id}
  shared_folders.collect{|sf| sf.destroy if  sf != nil}       unless shared_folders.empty? || shared_folders == [nil]
  #To add share for the collaborators to whom the parent folder is shared
  add_new_parent_folder_collaborators(move_folder_id)
  @msg = FLASH_MESSAGES['treeview']['2002']
  Event.create_new_event("moved",current_user.id,nil,[folder],current_user.user_role(current_user.id),folder.name,[rename_my_files_and_tasks(parent_folder1),parent_folder1.id,move_folder_id.name,move_folder_id.id])
end

def add_new_parent_folder_collaborators(move_folder_id)
  members = find_move_to_folder_members
  subfolders,subdocs,sub_docnames = Folder.subfolders_docs(@moved_folder.id,true,false,params)
  members.each do |su|
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(@parent_folder.id,su.user_id,su.sharer_id,@moved_folder.real_estate_property_id)
    sf.update_attributes(:sharer_id=>su.sharer_id)
    owner_folder = sf.folder
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(@parent_folder.id,owner_folder.user_id,su.sharer_id,move_folder_id.real_estate_property_id)
    sf.update_attributes(:sharer_id=>su.sharer_id)
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(@parent_folder.id,su.sharer_id,owner_folder.user_id,move_folder_id.real_estate_property_id)
    share_moveto_folders_docs_to_members(subfolders,subdocs,sub_docnames,su)
  end
end

def copy_folder(parent_folder,parent_folder1,portfolio_id_old,folder_id_old,move_folder_id)
  folder = Folder.find_folder(params[:id])
  fol = Folder.new
  fol.attributes = parent_folder.attributes
  fol.parent_id = params[:move_folder_id]
  folder_name = find_folder_name(fol.parent_id,fol.name)
  fol.name = folder_name
  fol.real_estate_property_id = move_folder_id.real_estate_property_id
  fol.portfolio_id = move_folder_id.portfolio_id
  fol.user_id = current_user.id
  fol.save
  properties_subfolders_docs_documentnames_for_move_to_function(parent_folder,fol,params[:pid])
  share_folder_to_parent_folder_collaborators(fol,move_folder_id)
  @msg =  FLASH_MESSAGES['treeview']['2003']
  Event.create_new_event("copied",current_user.id,nil,[folder],current_user.user_role(current_user.id),folder.name,[rename_my_files_and_tasks(parent_folder1),parent_folder1.id,move_folder_id.name,move_folder_id.id])
end

def remove_document_collaborators(document)
  shared_documents = document.shared_documents.collect{|d| d if d.user_id != current_user.id}
  unless shared_documents.empty? || shared_documents == [nil]
    shared_documents.compact.collect{|sd| sd.destroy if sd != nil}
  end
end

def modify_document_folder_id(document,is_doc_exists,move_folder_id)
  if is_doc_exists
    document_name = document.filename
    if document.folder_id.to_i != params[:move_folder_id].to_i
      document.update_attributes(:folder_id => params[:move_folder_id],:filename => document_name,:real_estate_property_id =>move_folder_id.real_estate_property_id)  if !document.nil?
    end
  else
    document.update_attributes(:folder_id => params[:move_folder_id],:real_estate_property_id =>move_folder_id.real_estate_property_id)  if !document.nil?
  end
end

def modify_shared_documents_folder_id(move_folder_id,document)
  document.shared_documents.update_all("folder_id = #{params[:move_folder_id]},real_estate_property_id = #{move_folder_id.real_estate_property_id}")
end

def share_doc_to_moved_folder_collaborators(document,move_folder_id)
  members = find_move_to_folder_members.uniq
  members.each do |su|
    sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id(document.id,su.user_id,su.sharer_id,document.real_estate_property_id)
    sd.update_attributes(:folder_id=>document.folder_id,:sharer_id=>su.sharer_id,:real_estate_property_id =>move_folder_id.real_estate_property_id)
    owner_doc = sd.document
    sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(document.id,owner_doc.user_id,su.sharer_id,move_folder_id.real_estate_property_id,@moved_folder.id)
    sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(document.id,su.sharer_id,owner_doc.user_id,move_folder_id.real_estate_property_id,@moved_folder.id)
    sd.update_attributes(:folder_id=>document.folder_id,:real_estate_property_id =>move_folder_id.real_estate_property_id)
  end
end

def insert_property_name(parent_folder)
  if check_is_folder_shared(parent_folder) == "true"
    if parent_folder.name != "my_files" && parent_folder.parent_id != 0
      @tree_structure << "<li><span class='folder'><a href='#' style=''  id='style_folder_#{parent_folder.id}' onclick='store_folder_id(#{parent_folder.id});return false'  > #{parent_folder.name}</a></span>"
    elsif  parent_folder.name != "my_files" && parent_folder.parent_id == 0
      @tree_structure << "<li><span class='folder'><a href='#' style=''  id='style_folder_#{parent_folder.id}' onclick='store_folder_id(#{parent_folder.id});return false'  > #{parent_folder.name}</a></span>"
    end
  end
end

def  find_shared_and_owned_folders_in_my_files(children,parent_folder)
  children = Folder.find_all_by_parent_id_and_is_deleted(parent_folder.id,false)
  if @prop_loop == 0 && @l ==0 && @shared_folders_real_estate && 	@shared_folders_added == false
    children = children + @shared_folders_real_estate
    @shared_folders_added = true
  end
  return children
end

def  find_shared_and_owned_files_in_my_files(children,parent_folder)
  children = Folder.find_all_by_parent_id_and_is_deleted(parent_folder.id,false)
  documents = Document.find_all_by_folder_id_and_is_deleted(parent_folder.id,false)
  if @prop_loop == 0 && @l ==0 && @shared_folders_real_estate && 	@shared_folders_added == false && @shared_docs_real_estate
    children = children + @shared_folders_real_estate
    documents = documents + @shared_docs_real_estate
    @shared_folders_added = true
  end
  return children,documents
end

def insert_property_sub_folders_in_tree(property_collection)
  if !property_collection.flatten.compact.uniq.empty?
    @tree_structure << "<ul>"  if !property_collection.flatten.compact.uniq.empty?
    @prop_loop = 0
    @l = @j == 0 ? 0 : @j
    for property in property_collection.flatten.compact.uniq
      parent_folder = Folder.find_by_real_estate_property_id_and_parent_id(property.id,0)
      if !parent_folder.nil?
        recursive_function_for_move_copy_functionality(parent_folder,false)
      end
      @prop_loop += 1
    end
    @tree_structure << "</ul>"  if !property_collection.flatten.compact.uniq.empty?
  end
end

def insert_property_docs_in_tree(portfolio)
  if !portfolio.real_estate_properties.empty?
    @tree_structure << "<ul>"
    @prop_loop = 0
    @l = @j == 0 ? 0 : @j
    for property in portfolio.real_estate_properties
      parent_folder = Folder.find_by_real_estate_property_id_and_parent_id(property.id,0)
      recursive_function_for_add_file_functionality(parent_folder) if parent_folder
      @prop_loop += 1
    end
    @tree_structure << "</ul>"
  end
end


def create_comment(comment,commentable_id,commentable_type)
  task_comment = Comment.new(comment.attributes)
  task_comment.update_attributes(:commentable_id =>commentable_id,:commentable_type =>commentable_type)
  task_comment.save
end

def display_secondary_files(second,del_option,download_path,val,task)
  if second.class == Document
    val << "<div class='coll3' id='#{second.class.to_s+"_"+second.id.to_s}' ><div class='collabdelcol'>#{del_option}</div><div class='collabusercol'> <a href='#{download_file_path(download_path,:type=>second.class,:task_id=>task)}'>#{lengthy_word_simplification(second.filename,10,8)}</a></div></div>"
  else
    (second.document_id.nil? and second.task_id.nil?) ? val <<  "<div class='coll3' id='#{second.class.to_s+"_"+second.id.to_s}' ><div class='collabdelcol'>#{del_option}</div><div class='collabusercol'> <a style='color:black'>#{lengthy_word_simplification(second.filename,10,8)}</a></div></div>" :  val << "<div class='coll3' id='#{second.class.to_s+"_"+second.id.to_s}' ><div class='collabdelcol'>#{del_option}</div><div class='collabusercol'> <a href='#{download_file_path(download_path,:type=>second.class,:task_id=>task)}'>#{lengthy_word_simplification(second.filename,10,8)}</a></div></div>"
  end
  return raw(val)
end

def display_file_using_treeview_file_with_doc
  doc = find_document_and_task_document_ids
  get_secondary_new_for_document
  val =[]
  responds_to_parent do
    render :update do |page|
      page.call 'close_control_model'
      page.replace_html  'all_uploaded_files_list',raw("<input type='hidden' name='all_already_upload_file' id='all_already_upload_file' value='#{params[:all_already_upload]}'/>")
      page.replace_html  'all_tree_selected_file',raw("<input type='hidden' name='all_tree_structure_file' id='all_tree_structure_file' value='#{params[:all_tree_structure]}'/>")
      page.call 'load_completer'
    end
  end
end

def display_file_using_treeview_file_with_out_doc
  @task = Task.find_by_id(params[:task_id])
  if @task.nil?
    @task = Task.new
    @task.folder_id = params[:folder_id]
    @task.save
  end
  task_document_ids = TaskDocument.find_all_by_user_id_and_task_id(User.current,@task.id).map(&:document_id)
  task_document_ids = [] if task_document_ids.nil?
  task_document_ids = ( task_document_ids + params[:recently_added_files_by_tree].split(',').collect { |id| id.to_i } ).uniq unless params[:recently_added_files_by_tree].blank?
  get_secondary_new_for_document
  val =[]
  if !@secondary_files.empty?
    for second in @secondary_files
      download_path = second.id
      if @task.temp_task? || @task.user_id == current_user.id || ( second.class == TaskFile && second.user_id == current_user.id ) || ( second.class == Document && task_document_ids.include?(second.id) )
        del_option = "<a href='#' onclick=\"if (confirm('Are you sure you want to remove this file ?')){jQuery(\'##{second.class.to_s+"_"+second.id.to_s}\').hide();delect_selected_file_main_for_folder(\'#{second.class.to_s}\',#{second.id},#{params[:task_id]},\'#{second.filename}\');} return false\"><img border='0' width='7' height='7' src='/images/del_icon.png' title='Remove File'></a>"
      else
        del_option = ""
      end
      val = display_secondary_files(second,del_option,download_path,val,@task)
    end
  end
  responds_to_parent do
    render :update do |page|
      page.call 'close_control_model'
      page.replace_html  "added_files_list",raw(val)
      page.replace_html  'all_uploaded_files_list',raw("<input type='hidden' name='all_already_upload_file' id='all_already_upload_file' value='#{params[:all_already_upload]}'/>")
      page.replace_html  'all_tree_selected_file',raw("<input type='hidden' name='all_tree_structure_file' id='all_tree_structure_file' value='#{params[:all_tree_structure]}'/>")
      if request.env["HTTP_REFERER"].include?("shared_users")
        page << "jQuery('#add_files_task').attr('href',jQuery('#add_files_task').attr('href')+'&recently_added_files_by_tree=#{params[:recently_added_files_by_tree]}');"
        page << "if(jQuery('#add_files_task').attr('href').search(/recently_added_files_by_tree/) >0){
						url = jQuery('#add_files_task').attr('href').split('=');
						url[url.length-1] = '#{params[:recently_added_files_by_tree]}';
						jQuery('#add_files_task').attr('href',url.join('='));
						new Control.Modal($('add_files_task'), {beforeOpen: function(){load_writter();},afterOpen: function(){load_completer();},className:'modal_container', method:'get'});
						}
						else { jQuery('#add_files_task').attr('href',jQuery('#add_files_task').attr('href')+'&recently_added_files_by_tree=#{params[:recently_added_files_by_tree]}');
						new Control.Modal($('add_files_task'), {beforeOpen: function(){load_writter();},afterOpen: function(){load_completer();},className:'modal_container', method:'get'});
						}"
      end
      page.call "load_completer"
    end
  end
end

def share_file_to_parent_folder_collaborators(d,move_folder_id)
  members = find_move_to_folder_members
  members.each do |su|
    sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,su.user_id,su.sharer_id,@moved_folder.real_estate_property_id,params[:move_folder_id])
    owner_doc = sd.document
    sf = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,su.sharer_id,owner_doc.user_id,move_folder_id.real_estate_property_id,params[:move_folder_id])
    sf = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,owner_doc.user_id,su.sharer_id,move_folder_id.real_estate_property_id,params[:move_folder_id])
  end
  return members
end

def share_folder_to_parent_folder_collaborators(fol,move_folder_id)
  members = find_move_to_folder_members
  subfolders,subdocs,sub_docnames = Folder.subfolders_docs(fol.id,true,false,params)
  members.each do |su|
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(fol.id,su.user_id,su.sharer_id,@moved_folder.real_estate_property_id)
    owner_folder = sf.folder
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(fol.id,su.sharer_id,owner_folder.user_id,move_folder_id.real_estate_property_id)
    sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(fol.id,owner_folder.user_id,su.sharer_id,move_folder_id.real_estate_property_id)
    share_moveto_folders_docs_to_members(subfolders,subdocs,sub_docnames,su)
  end
end
end
