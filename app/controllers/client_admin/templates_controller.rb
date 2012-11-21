class ClientAdmin::TemplatesController < ApplicationController
  layout 'client_admin', :except=>"tree_view_template"
  before_filter :client_admin_login_required


  def get_template
    puts("found")
    puts(params[:pname])
    @admin_template = Template.where("property_type_name=?", params[:pname])
    #@admin_template = SuperAdminTemplate.where("id=?", params[:property_type_name])
    render :json => @admin_template
end

  # GET /templates
  # GET /templates.xml
  def index
    #@templates=Template.find_by_sql("select * from templates where property_type_name IN (select Distinct property_type_name from templates) AND parent_id NOT IN (0)")
    @templates=Template.find_by_sql("select * from templates where property_type_name IN (select Distinct property_type_name from templates) AND template_name IS NOT NULL AND client_id=#{current_user.client_id} Group by property_type_name")
    #@templates=Template.find_by_sql("select * from templates where property_type_name IN (select Distinct property_type_name from templates)AND client_id=#{current_user.client_id}")

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @templates }
      end
  end



 def update_folder_new
   #@folder_update=Template.where("id = ? ",params[:template_id])

   @folder_update=Template.find(params[:template_id])
   #@users=User.where("client_id = ? ",current_user.client_id)
   #@users=User.find_by_sql("select * from users u where u.selected_role NOT IN('Shared User','Server Admin','Leasing Agent','#{current_user.id}') AND u.client_id='#{current_user.client_id}'")
   @users=User.find_by_sql("select * from users u where u.selected_role NOT IN('#{current_user.id}') AND u.client_id='#{current_user.client_id}'")
   @user_collab=TemplateFolderCollab.where("template_folder_id = ? AND shared_by = ?",params[:template_id],"#{current_user.id}")
   render "update_folder_new.html.erb"
 end

  def update_folder
    @template_edit=Template.find(params[:template_id])
    #@folder_edit=Folder.where("name = ? AND user_id = ? AND template_folder_id = ?",@template_edit.folder_name,current_user.id,@template_edit.id)
    @folder_edit=Folder.where("template_folder_id = ?",@template_edit.id)
    # @folder_edit=Folder.where("name = ? AND user_id = ?",@template_edit.folder_name,current_user.id)
    #if @folder_edit.first == nil
    @template_edit.folder_name=params[:template][:folder_name]
    @template_edit.description=params[:template][:description]
    @template_edit.updated_date=Date.today
    @template_edit.save
    #else

=begin
    @folder_edit.first.name=params[:template][:folder_name]
    @folder_edit.first.description=params[:template][:description]
    @template_edit.folder_name=params[:template][:folder_name]
    @template_edit.description=params[:template][:description]
    @template_edit.updated_date=Date.today
    @folder_edit.updated_date=Date.today
    @folder_edit.first.save
    @template_edit.save
    end
=end
    #@template_collab=TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ?","#{current_user.id}",params[:template_id])
    if @folder_edit.first == nil
      TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ? ",current_user.id,params[:template_id]).delete_all
      puts("**************************************************")
      puts(@folder_edit.inspect)
      puts("************************************")
      if params[:user]==nil
        redirect_to :back
      else
        params[:user].each do |p,k|
          @template_folder_collab=TemplateFolderCollab.new

          @template_folder_collab.shared_by=current_user.id
          @template_folder_collab.shared_to="#{k}"
          @template_folder_collab.template_folder_id=params[:template_id]
          @template_folder_collab.save
        end
        redirect_to :back
        end
  else
    TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ? ",current_user.id,params[:template_id]).delete_all
    puts("**************************************************")
    puts(@folder_edit.inspect)
    puts("************************************")
    SharedFolder.where("folder_id = ? AND sharer_id = ?",@folder_edit.first.id,"#{current_user.id}").delete_all
    puts("************************")
    if params[:user]==nil
      redirect_to :back
    else
      params[:user].each do |p,k|
        @template_folder_collab=TemplateFolderCollab.new

        @template_folder_collab.shared_by=current_user.id
        @template_folder_collab.shared_to="#{k}"
        @template_folder_collab.template_folder_id=params[:template_id]
        @template_folder_collab.save
      end

        #redirect_to :controller => 'templates', :action => 'folder_template_rename', params[:template_id] => ver
        #params[:user].each do |p,k|
        @folder_edit.each do |f|
          params[:user].each do |p,k|
          @shared_folder=SharedFolder.new
          @shared_folder.user_id="#{k}"
          @shared_folder.sharer_id=current_user.id
          @shared_folder.folder_id=f.id
          @shared_folder.save
          redirect_to :back
      end
    end
    end
    end
    end
    #@folder_edit=Folder.where("name = ? AND user_id = ? AND template_folder_id = ?",@template_edit.folder_name,current_user.id,@template_edit.id)
    #@template_collab=TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ?","#{current_user.id}",params[:template_id])
=begin
     @folder_edit.each do |f|
       puts("****************************************")
       puts("***************************************")
      SharedFolder.where("folder_id = ? AND sharer_id = ?",f.id,"#{current_user.id}").delete_all
      puts("****************************************")
       puts("***************************************")
      if params[:user]== nil

      else
        params[:user].each do |p,k|
          @shared_folder=SharedFolder.new
          @shared_folder.user_id="#{k}"
          @shared_folder.sharer_id=current_user.id
          @shared_folder.folder_id=f.id
          @shared_folder.save



          redirect_to :back
  end

  end

     end
    end
=end






  def update_folder2
    @template_edit=Template.find(params[:template_id])
    @folder_edit=Folder.where("name = ? AND user_id = ? AND template_folder_id = ?",@template_edit.folder_name,current_user.id,@template_edit.id)
    #if @folder_edit.first == nil


      @template_edit.folder_name=params[:template][:folder_name]
      @template_edit.description=params[:template][:description]
      @template_edit.updated_date=Date.today
      @template_edit.save


    #else

=begin

    @folder_edit.each do |t|

    t.name=params[:template][:folder_name]
    t.description=params[:template][:description]
    @template_edit.folder_name=params[:template][:folder_name]
    @template_edit.description=params[:template][:description]
    @template_edit.updated_date=Date.today
    #t.updated_date=Date.today
    t.save
    @template_edit.save

=end


=begin

  end
  #@template_collab=TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ?","#{current_user.id}",params[:template_id])
    @folder_edit.each do |f|
    SharedFolder.where("folder_id = ? AND sharer_id = ?",f.id,"#{current_user.id}").delete_all
    if params[:user]== nil

    else
    params[:user].each do |p,k|
          @shared_folder=SharedFolder.new
          @shared_folder.user_id="#{k}"
          @shared_folder.sharer_id=current_user.id
          @shared_folder.folder_id=f.id
          @shared_folder.save

    end

=end


    TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ? ",current_user.id,params[:template_id]).delete_all
    if params[:user]==nil
    else
    params[:user].each do |p,k|
      @template_folder_collab=TemplateFolderCollab.new
      @template_folder_collab.shared_by=current_user.id
      @template_folder_collab.shared_to="#{k}"
      @template_folder_collab.template_folder_id=params[:template_id]
      @template_folder_collab.save
      #redirect_to :controller => 'templates', :action => 'folder_template_rename', params[:template_id] => ver

    end
    redirect_to :back
    end
    end

=begin

    if @template_collab.first == nil
      if params[:user] == nil
        puts("user and temp both nil")
        puts("user and temp both nil")
        puts("user and temp both nil")
      #redirect_to :controller => 'templates', :action => 'folder_template_rename', params[:template_id] => ver


      else
          puts("temp nil")
          puts("temp nil")
          puts("temp nil")
          params[:user].each do |p,k|
          @template_folder_collab=TemplateFolderCollab.new
          @template_folder_collab.shared_by=current_user.id
          @template_folder_collab.shared_to="#{k}"
          @template_folder_collab.template_folder_id=params[:template_id]
          @template_folder_collab.save
          #redirect_to :controller => 'templates', :action => 'folder_template_rename', params[:template_id] => ver

          end

      end
     # redirect_to :back
    else




           if params[:user] == nil
            puts("temp not nil user nil")
            puts("temp not nil user nil")
            #TemplateFolderCollab.find_by_share_to_and_template_folder_id('#{current_user.id}',params[:template_id]).destroy_all
            #TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ?",'#{current_user.id}',params[:template_id]).destroy_all
            TemplateFolderCollab.destroy_all(:template_folder_id => params[:template_id])
            #User.destroy_all(:age => 15)
            #render 'Templates/folder_template_rename'
           # redirect_to :controller => 'templates', :action => 'folder_template_rename', params[:template_id] => ver
            #redirect_to :back
          else
              puts("both have value")
              puts("both have value")
              puts("both have value")

            @template_collab.each do |t|
            params[:user].each do |p,k|
          if t.shared_to.to_s == "#{k}".to_s
                puts("ifffffffffffff")
          else
            ver="#{k}".to_s

            puts(t.shared_to)
            puts(t.shared_to)
            puts(t.shared_to)
           puts("((((((((((((((((((((((((((((((((((((((((((((())))))))))))))))))))))))))")
             puts("#{k}")
           TemplateFolderCollab.where("shared_to = ? AND template_folder_id = ? ",t.shared_to,params[:template_id]).delete_all
          end

            end
            end
              @temp_collab=TemplateFolderCollab.where("shared_by = ? AND template_folder_id = ?","#{current_user.id}",params[:template_id])
          params[:user].each do |p,k|
            @temp_collab.each do |t|
            if "#{k}".to_s==t.shared_to.to_s
            else
              @template_folder_collab=TemplateFolderCollab.new
              @template_folder_collab.shared_by=current_user.id
              @template_folder_collab.shared_to="#{k}"
              @template_folder_collab.template_folder_id=params[:template_id]
              @template_folder_collab.save











          end


           end


          end

         end
    end
    #redirect_to :back
      end

=end



  def find_properties_user_for_template
    @users=User.by_client_ids(current_user.client_id,current_user.email)
    end

  # GET /templates/1
  # GET /templates/1.xml

  def show
    @template = Template.find(params[:id])
     puts("show")
    puts("show")
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @template }
    end
  end


  def add_new
    @template1 = Template.new
     @temp3=Template.where("id = ?",params[:template_id])
    str1=@temp3.first.property_type_name
     @temp4=Template.where("property_type_name = ? AND client_id = ? ",str1,current_user.client_id)

    render "add_new.html.erb"

  end

  def add_new_folder_template
	@user=User.where("id = ?",current_user.id)
    @template1 = Template.new
   @template1.folder_name=params[:folder_name][:classinpt150]
   @template1.description=params[:discription][:classinpt150]
   @template2=Template.where("id = ?",params[:template_id])
   @template1.client_id=  @template2.first.client_id
   @template1.is_editable=true
   @template1.property_type_name=@template2.first.property_type_name
   @template1.parent_id=params[:post][:id]
   @template1.template_name=@template2.first.template_name
  @template1.template_id=@template2.first.template_id
   @template1.created_date=Date.today
   @template1.updated_date=Date.today
   @template1.save
   add_collaborators_in_template_folder(@template1)

    #create_template_folder( @template1)

    redirect_to :back
   #redirect_to client_admin_templates_path
  end

      def add_collaborators_in_template_folder(template)
        puts("""""""""""""""""")
        puts("add_collaborators_in_template_folder")
        puts("***********************")
        @collab_users=User.find_by_sql("select * from users u where u.selected_role NOT IN('Shared User','Server Admin','Leasing Agent') AND u.client_id='#{current_user.client_id}'")
        @collab_users.each do |u|
          puts("************")
          puts(u.name)
          puts("************")
          @template_collab=TemplateFolderCollab.new
           @template_collab.shared_by=current_user.id
          @template_collab.shared_to=u.id
          @template_collab.template_folder_id=template.id
          @template_collab.save
         add_role_to_collabrators(u.id)

        end
          end





      def add_role_to_collabrators(user_id)
      puts("""""""""""""""""")
      puts("add_role_to_collabrators")
      puts("***********************")
      @role=Role.where("name = ?","Shared User")
      @user=User.find_by_sql("select * from users u where u.selected_role NOT IN('Shared User','Server Admin','Leasing Agent') AND u.client_id='#{current_user.client_id}'")
      @collab_users.each do |u|
       @roles_user=RolesUsers.new
      @roles_user.role_id=@role.first.id
      @roles_user.user_id=user_id
       @roles_user.save
    end
    end


  def folder_template_rename
    #@template_folder_rename=Template.where("id = ? ",params[:template_id])
    @template_folder_rename=Template.where("id = ? ",params[:template_id])
    #@template_folder=Template.where("is_editable = ? AND client_id = ? AND property_type_name = ? ",true,current_user.client_id,@template_folder_rename.first.property_type_name)
    @template_folder=Template.where("client_id = ? AND property_type_name = ? ",current_user.client_id,@template_folder_rename.first.property_type_name)
    #tree_view_template
  end

  def     form_tree_structure_recursive_template
=begin
    real_id = (params[:element_type] and params[:element_type] == "document") ? Document.find_by_id(params[:id]).real_estate_property_id : Folder.find_folder(params[:id]).real_estate_property_id
    @property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(real_id,0,0)
    @property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(real_id,-2,1) if @property_folder.blank? and params[:bulk_upload] == 'true'
=end
    @value  = ''
   # if @property_folder
      @tree_structure = []
      form_tree_structure_recursive_template
    #end
    @value = ActionController::Base.helpers.raw(@tree_structure.join('')) if @tree_structure
    render :layout => false
  end

  def tree_view_template_praveen
    @value  = ''
    @tree_structure = []

    @tree=Template.find(params[:template_id])
    @fold_template=Template.find_by_sql("select * from templates where property_type_name='#{@tree.property_type_name}' and client_id=#{@tree.client_id} and parent_id=0")

    @fold_template.each do |parent_folder|
      @tree_structure << "<ul><span class='template'><a href='#' style=''  id='style_#{parent_folder.id}'> #{parent_folder.folder_name} </a></span>"
      @fold_sub_template=Template.where("parent_id = ?",t.id)
      if @fold_sub_template==nil

      else
        find_children_folder(@fold_sub_template)
        @fold_sub_template=Template.where("parent_id = ?",t.id)

        #@tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:operation] == "move" || params[:operation] == "copy" || params[:operation] == "edit") ? 'folder' : 'file'} to select</div><br/><br/><br/>"
        #@tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:sort] == "edit_template") ? 'folder' : 'file' } to select</div><br/><br/><br/>"
        @tree_structure << "<ul id='browser' class='filetree'>"
        @tree_structure << "</ul>"
        #@tree_structure << "<ul><span class='template'><a href='#' style=''  id='style_#{t.id}'> #{t.folder_name} </a></span>"
        @fold_sub_template.each do|p|
          # @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"

          @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"
        end
        @value = ActionController::Base.helpers.raw(@tree_structure.join('')) if @tree_structure
        #render :layout => false
      end
    end
  end










=begin

   def tree_view_template
     @value  = ''
     @tree_structure = []

     @tree=Template.find(params[:template_id])
    @fold_template=Template.find_by_sql("select * from templates where property_type_name='#{@tree.property_type_name}' and client_id=#{@tree.client_id} and parent_id=0")

      @fold_template.each do |parent_folder|
       @tree_structure << "<ul><span class='template'><a href='#' style=''  id='style_#{parent_folder.id}'> #{parent_folder.folder_name} </a></span>"
       @fold_sub_template=Template.where("parent_id = ?",t.id)
       if @fold_sub_template==nil

       else
       find_children_folder(@fold_sub_template)
     @fold_sub_template=Template.where("parent_id = ?",t.id)

     #@tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:operation] == "move" || params[:operation] == "copy" || params[:operation] == "edit") ? 'folder' : 'file'} to select</div><br/><br/><br/>"
     #@tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on a #{ ( params[:sort] == "edit_template") ? 'folder' : 'file' } to select</div><br/><br/><br/>"
     @tree_structure << "<ul id='browser' class='filetree'>"
     @tree_structure << "</ul>"
     #@tree_structure << "<ul><span class='template'><a href='#' style=''  id='style_#{t.id}'> #{t.folder_name} </a></span>"
     @fold_sub_template.each do|p|
       # @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"

       @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"
     end
     @value = ActionController::Base.helpers.raw(@tree_structure.join('')) if @tree_structure
     #render :layout => false
     end
      end
     end
=end
=begin
     s1=TreeViewController.new
     s1.move_action
=end

  # GET /templates/new
  # GET /templates/new.xml

  def find_children_folder(root)

  @children_folder=Template.find_by_sql("select * from templates where parent_id=#{root.id}")
     if   @children_folder == nil

     else

          # @sub_root=Template.find_by_sql("select * from templates where parent_id=i")


       @children_folder.each do |child|


       @tree_structure << "<li><span class='template'><a href='#' style=''  id='style_#{p.id}'> #{p.folder_name} </a></span>"
       find_children_folder(@children_folder)
       end

     end
     end

  def new
    @template = Template.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @template }
    end
  end





  # POST /templates
  # POST /templates.xml
  def create
    puts("******************************")
    @template = Template.new(params[:template])
    @template.template_name=params[:template_name][:classinpt150]
    @template.folder_name=params[:folder_name][:classinpt150]
    @template.client_id=current_user.client_id
    @template.description=params[:template][:description]
    @template.property_type_name=params[:post][:name]
    @template.is_editable=true
    temp2=@template.get_template_id(current_user.client_id)
    @template.template_id=temp2
    #@template.parent_id=params[:post][:parent_name]
    @tem=Template.where("folder_name = ? AND  client_id = ? AND property_type_name = ?",params[:post][:parent_name],current_user.client_id,params[:post][:name])
    puts("*******************************")
     puts(@tem.first.id)

    @template.parent_id=@tem.first.id
    @template.property_type_name=params[:post][:name]
    @templates=@template.save
    redirect_to client_admin_templates_path

  end

  # PUT /templates/1
  # PUT /templates/1.xml
  def update
    puts("********************************")

    @template = Template.find(params[:id])

    respond_to do |format|
      if @template.update_attributes(params[:template])
        format.html { redirect_to(@template, :notice => 'Template was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @template.errors, :status => :unprocessable_entity }
      end
    end
  end


  def insert_parent_folder_name(parent_folder)
      parent_folder.parent_id == 0
        @tree_structure << "<li><span class='folder'><a href='#' style=''  id='style_folder_#{parent_folder.id}' onclick='store_folder_id(#{parent_folder.id});return false'  > #{parent_folder.folder_name}</a></span>"
  end


  def  find_children(children,parent_folder)

    #children = Template.find_all_by_parent_id_and_is_deleted(parent_folder.id,false)
    children = Template.find_by_sql("select * from templates where parent_id = #{parent_folder.id}")
     puts("=-=-=-=-=children-=-=-=-=-=-")
     puts(children.inspect)
      children = children
      return children
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


  def recursive_function_for_template_tree_view_functionality(template,display_ul)

      #current_folder_id =  params[:id]
    #for template in template_list.uniq
      insert_parent_folder_name(template)
      children = find_children(children,template)
                                puts(children.length != 0)
      if (children.length != 0)
        @tree_structure << "<ul>"
        if (children.length != 0)
          @n=0
          for child in children
            if @my_files_collection.index(child).nil?
              recursive_function_for_template_tree_view_functionality(child,true)
             if child.length != 0
              @folders_in_portfolios << child
            end
            end
            @my_files_collection << child
          end
        end
        @tree_structure << "</ul>"
      end
      @tree_structure << "</li>"
   # @l = @l+1
    #end
  end

  def insert_first_level_temp_name_structure(temp)
    if temp.parent_id == 0
      @tree_structure << "<li><span class='folder'><a href='#' style=''>#{temp.folder_name}</a></span>"
      @portfolio_name_in_tree_structure = temp.template_name
    else
      puts("in else")
      puts(temp.parent_id )
    end
      return @tree_structure
  end




  def tree_view_template
    @value  = ''
    #if @property_folder
    @tree_structure = []
    form_tree_structure_recursive
    # end
    @value = ActionController::Base.helpers.raw(@tree_structure.join('')) if @tree_structure
    render :layout => false
  end


  def find_template_list
    #@tree=Template.find(params[:template_id])
    template_list =Template.find_all_by_template_id(1)
    puts(template_list .inspect)
    return template_list
  end

  def form_tree_structure_recursive

    @my_files_collection = []
    template_list = find_template_list
    if template_list && !template_list.empty?
      @tree_structure = []
      @tree_structure << "<div class='add_files_headercol' style='width:356px;margin-left:2px;' id='click_text'>Click on  folder to select</div><br/><br/><br/>"
      @tree_structure << "<ul id='browser' class='filetree'>"
      @j = 0
      for template in template_list.uniq
        if template
          #insert_first_level_temp_name_structure(template_list)

          recursive_function_for_template_tree_view_functionality(template,false)

          @folders_in_templates = [],false
          @tree_structure << "</li>"
          @folders_in_templates =  @folders_in_templates.reject{|f| f == @folder} if !@folders_in_templates.empty? && params[:element_type] !="document"
          @portfolio_name_in_tree_structure = []
          @portfolio_name_in_tree_structure << @portfolio_name_in_tree_structure.uniq
         end
        @j +=1
      end
      @tree_structure << "</ul>"
    end
    puts(@tree_structure.inspect)
  end
end
