class ClientAdmin::PropertiesController < ApplicationController
  before_filter :user_required
  layout "client_admin",:except=>['other_users']
  before_filter :find_real_property,:only=>['edit','update','other_users']
  before_filter :find_user,:only=>['create','update','destroy']

  def index
    sort = params[:sort] || 'Commercial'
    properties = RealEstateProperty.property_client_ids(Client.current_client_id,User.current.id,sort)
    @comm_prop_count = RealEstateProperty.property_client_ids(Client.current_client_id,User.current.id,"Commercial").count
    @multi_prop_count = RealEstateProperty.property_client_ids(Client.current_client_id,User.current.id,"Multifamily").count
    @properties =  properties.order("created_at DESC").paginate(:per_page=>25,:page=>params[:page]) if properties.present?
  end

  def new
    @property = RealEstateProperty.new
    @property.build_address
  end

  def create
		#~ user_id = current_user.id
		@property = RealEstateProperty.create(params[:real_estate_property])
		client_id = current_user.client_id
    @property.update_attributes(:user_id => @user_id, :client_id => client_id)
    if params[:real_estate_property][:property_name].present? && params[:real_estate_property][:address_attributes][:province].present?
      create_property_folders(@user_id,client_id,@property)

      property_name_from_property_type_id(@property.property_type_id,@property.id)

      redirect_to  client_admin_properties_path(@user_id,:sort => params[:sort],:add_property=>"true")
    else
      @errors = @property.errors
      render "new"
    end
	end

  def edit
    #~ @property = RealEstateProperty.find_by_id(params[:id])
  end

  # create method to copy the default folders from template table to folder table
   def create_template_folder_for_property(property_name_for_template,real_estate_property_id_for_template)

     @template_property_folder=Template.where("property_type_name = ? AND client_id = ? AND is_editable = ?",property_name_for_template,current_user.client_id,true)
     if @template_property_folder.first == nil

     else
      @latest_property_folder=Folder.where("real_estate_property_id = ?",real_estate_property_id_for_template)

      @template_property_folder.each do |t|
=begin
        @latest_property_folder.each do |f|
         if t.folder_name == f.name
         else
=end

=begin
          temp_name=Template.where("id = ? ",t.first.parent_id)
           folder_name_temp=Folder.where("name = ? AND real_estate_property_id = ?",temp_name.first.folder_name,real_estate_property_id_for_template)
           @folder_create=Folder.new
           @folder_create.name=t.folder_name
           @folder_create.parent_id=folder_name_temp.id
           @folder_create.client_id=t.client_id
           @folder_create.description=t..description
           @folder_create.is_editable=true
=end
     @folder_create=Folder.new
     temp_name=Template.where("id = ? ",t.parent_id)
     folder_name_temp=Folder.where("name = ? AND real_estate_property_id = ?",temp_name.first.folder_name,real_estate_property_id_for_template)
     @folder_create.name=t.folder_name
     @folder_create.parent_id=folder_name_temp.first.id
     @folder_create.client_id=t.client_id
     @folder_create.description=t.description
     @folder_create.real_estate_property_id=real_estate_property_id_for_template
     @folder_create.is_master=true
     @folder_create.is_deleted=false
     @folder_create.is_deselected=false
     @folder_create.user_id=current_user.id
     @folder_create.is_editable=false
     @folder_create.portfolio_id=folder_name_temp.first.portfolio_id
     @folder_create.template_folder_id=t.id
     @folder_id=@folder_create.save

=begin
         end
     end
      end
=end
=begin
        @template_collab=TemplateFolderCollab.where("template_folder_id = ?",t.id)
        @template_collab.each do |f|
          @user=User.where("id = ?",345)
          @user.each do |u|
       # @collaboration=CollaboratorsController.new
        puts("*******************************")
        puts("*******************************")
        #puts(f.shared_to)
        puts(u.email)
        puts(u.email)
        puts(u.email)
        puts("*******************************")
        puts(@collaboration.inspect)
        puts("*******************************")
        @collaboration.share_folder1()
        puts("****************************")
        puts("****************************")
        puts("method finished")
        puts("****************************")
        puts("****************************")
=end
        share_folder_template (@folder_id.id,t.id,real_estate_property_id_for_template,t.folder_name)
      end
      #end
      end
      end

  def update
		#~ user_id = current_user.id
		#~ @property = RealEstateProperty.find_by_id(params[:id])
    @property.update_attributes(params[:real_estate_property])
    if params[:real_estate_property][:property_name].present? && params[:real_estate_property][:address_attributes][:province].present?
      @property.no_validation_needed = 'true'
      @property.save

      add_or_update_property_image if @property
      @folder = Folder.find_by_parent_id_and_is_master_and_real_estate_property_id_and_is_deleted(0,0,@property.id,0) if @property
      @folder.update_attributes(:name =>@property.property_name) if !@folder.nil? && @property
     #call own method


      redirect_to  client_admin_properties_path(@user_id,:sort => params[:sort],:edit_property=>"true")
    else
      @errors = @property.errors
      render "edit"
    end
  end

  def property_name_from_property_type_id(property_type_id_for_property_type,real_estate_prop)
    puts("*******************************")
    puts("*******************************")
    puts("*******************************")
    puts("i an in")
    puts("i an in")
    puts("i an in")
    @property_for_template=PropertyType.where("id = ?",property_type_id_for_property_type)
     create_template_folder_for_property(@property_for_template.first.name,real_estate_prop)

  end


  def share_folder_template(folder_id,template_id,real_estate_id,template_name)


    @template_collab=TemplateFolderCollab.where("template_folder_id = ?",template_id)
    if @template_collab.first == nil

    else

    @folder=Folder.where("name=? AND real_estate_property_id=?",template_name,real_estate_id)
    if @template_collab.first == nil

    else
    puts("*******************************")
    puts("*******************************")
    puts("*******************************")

    puts("i an in")
    puts("i an in")
    @template_collab.each do |t|
    @shared_template=SharedFolder.new
    @shared_template.user_id=t.shared_to
    @shared_template.folder_id=@folder.first.id
    @shared_template.sharer_id=current_user.id
    @shared_template.client_id=current_user.client_id

    @shared_template.real_estate_property_id=real_estate_id
    #@shared_template.is_portfolio_folder=false
    @shared_template.save
    end
    end
    end
  end
=begin

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
=end

  def destroy
    #~ user_id = current_user.id
		property = RealEstateProperty.find_by_id(params[:id])
    if params[:delete_image] != "true"
      shared_folders = SharedFolder.find_all_by_real_estate_property_id(property.id) if property
      if property && property.destroy
        shared_folders && shared_folders.each {|r| r.destroy}
        redirect_to client_admin_properties_path(@user_id,:sort => params[:sort])
      end
    elsif property && params[:delete_image] == "true"
      property.portfolio_image.destroy if property.portfolio_image
      redirect_to :controller=>"client_admin/#{@user_id}/properties/#{property.id}",:action=>"edit", :sort=>params[:sort],:delete_picture=>"true"
    end

	end

  def add_or_update_property_image
    if params[:attachment]
      image = PortfolioImage.find_by_attachable_id_and_attachable_type(@property.id,"RealEstateProperty")
      image != nil ?  image.update_attributes(params[:attachment]) : PortfolioImage.create_portfolio_image(params[:attachment][:uploaded_data],@property.id,nil)
    end
  end

  def other_users
		#~ @property = RealEstateProperty.find_by_id(params[:id])
		@other_users = find_user_names(@property)
	end

  def find_real_property
    @property = RealEstateProperty.find_by_id(params[:id])
  end

  def find_user
  @user_id = current_user.id
 end

end
