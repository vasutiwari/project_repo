class Admin::CollaboratorsController < ApplicationController
  layout "admin"
  before_filter :admin_login_required
  def index
    @collaborators = (Role.find(3).users - Role.find(2).users).paginate(:page => params[:page],:per_page => 10)
  end
  def destroy
    collaborator = User.find(params[:id])
    #~ if collaborator.destroy
      #~ flash[:notice] = "collaborator deleted successfully."
      #~ redirect_to admin_collaborators_path
    #~ else
      #~ flash[:notice] = "collaborator not deleted."
      #~ redirect_to admin_collaborators_path
      #~ end
      collaborator.destroy
      if request.xhr?
     render :update do |page|
#       page.replace_html "/asset_manager/index/"
     page.redirect_to :controller => "admin/collaborators", :action => "index"
     end
   end

  end
end
