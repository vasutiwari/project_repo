class Admin::PropertyManagementSystemsController < ApplicationController
     layout 'admin'
     before_filter :admin_login_required
     before_filter :find_property_system,:only =>['edit','update','destroy']

     #added for  property management systems add,edit,detete,list

     def index
          @property_management_systems =  PropertyManagementSystem.paginate(:all,:page => params[:page], :per_page =>10,:order=>"created_at desc")
     end

     def new
          @property_management_system = PropertyManagementSystem.new
     end

     def create
          @property_management_system = PropertyManagementSystem.new(params[:property_management_system])
          if @property_management_system.valid?
          @property_management_system.save
          flash[:notice] = "Property management system created successfully"
          redirect_to admin_property_management_systems_path
          else
          render :action=>'new'
          end
     end

     def edit
     end

     def update
          @property_management_system.name = params[:property_management_system][:name]
          @property_management_system.short_code = params[:property_management_system][:short_code]
          if @property_management_system.valid?
          @property_management_system.save
           flash[:notice] = "Property management system updated successfully"
          redirect_to admin_property_management_systems_path
          else
          render :action=>'edit'
          end
     end

     def destroy
          @property_management_system.destroy
          flash[:notice]="Property management system deleted successfully"
          redirect_to admin_property_management_systems_path
     end
     def find_property_system
          @property_management_system = PropertyManagementSystem.find_by_id(params[:id])
     end
end