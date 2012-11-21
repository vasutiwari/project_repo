# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require "authenticated_system.rb"
require "role_requirement_system.rb"
require "include_helpers.rb"
require "custom_pagination.rb"
class ApplicationController < ActionController::Base
  WillPaginate::ViewHelpers.pagination_options[:previous_label] = "Previous"
  WillPaginate::ViewHelpers.pagination_options[:next_label] = "Next"
  include SimpleCaptcha::ControllerHelpers
  #  before_filter :get_ip
  #  before_filter :subdomain_change_database
  before_filter :set_current_user, :set_current_client, :set_current_client_id

  # Included for exception notifier
  include ExceptionNotifiable
  # AuthenticatedSystem must be included for RoleRequirement, and is provided by installing acts_as_authenticates and running 'script/generate authenticated account user'.
  include AuthenticatedSystem
  # You can move this into a different controller, if you wish.  This module gives you the require_role helpers, and others.
  include RoleRequirementSystem

  include ActionView::Helpers::RawOutputHelper
  #~ include SslRequirement

  helper :all # include all helpers, all the time
  #protect_from_forgery # See ActionController::RequestForgeryProtection for details
  # add the settings for documents table field of state flag
  #@state_settings = {:root_files=>1 , :new_versionables=>2 }
  include IncludeHelpers
  # IncludeHelpers is lib which contains needed helper files. If you want to add more helper files, go to this lib file and add.
  #to use simple captcha
  include SimpleCaptcha::ControllerHelpers
  @@collection_exp_comments = Hash.new
  cattr_accessor :collection_exp_comments
  helper_method :clear_comments_var
  #filter_parameter_logging "password", "password_confirmation"

  #~ if Rails.env != "development"
  #~ rescue_from Exception, :with => :page_problem
  #~ #rescue_from Exception, :with => :page_problem_with_loader
  #~ rescue_from ActiveRecord::RecordNotFound, :with => :page_problem
  #~ rescue_from ActionController::RoutingError, :with => :page_problem
  #~ rescue_from ActionController::MethodNotAllowed, :with => :page_problem
  #~ rescue_from ActionController::UnknownAction, :with => :page_problem
  #~ #rescue_from ActionController::UnknownAction, :with => :page_problem_with_loader
  #~ end
  #~ def page_problem(exception)
  #~ ExceptionNotifier.deliver_exception_notification(exception, self, request)
  #~ redirect_to page_error_url
  #~ end
  #~ def page_problem_with_loader(exception)
  #~ ExceptionNotifier.deliver_exception_notification(exception, self, request)
  #~ redirect_to :controller => :home, :action => :page_error_for_loader
  #~ end
  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
  def admin_login_required
    set_flash_and_session('Admin') if !(current_user && current_user.has_role?('Admin'))
  end

  def client_admin_login_required
    set_flash_and_session('Client Admin') if !(current_user && current_user.has_role?('Client Admin'))
  end

  def login_required
    !(current_user && (current_user.has_role?('Asset Manager'))) ? set_flash_and_session() : session[:role] = 'Asset Manager'
  end

  def find_asset_manager
    set_flash_and_session('Asset Manager') if !(current_user && current_user.has_role?('Asset Manager'))
  end

  def shared_user_login_required
    !(current_user && (current_user.has_role?('Shared User'))) ? set_flash_and_session() :  session[:role] = 'Shared User'
  end

  def user_required
    set_flash_and_session() if !(current_user && (current_user.has_role?('Asset Manager') || current_user.has_role?('Shared User') || is_leasing_agent || current_user.has_role?('Admin')  || current_user.has_role?('Server Admin')  || current_user.has_role?('Client Admin')))
  end

  def admin_required
    set_flash_and_session() if !(current_user && (current_user.has_role?('Client Admin') || current_user.has_role?('Server Admin')))
  end

  def assign_asset_manager_role(u)
    asset_manager_role =  Role.find_by_name('Asset Manager')
    u.roles << asset_manager_role
  end

  def client_admin_role(u)
    client_admin_role =  Role.find_by_name('Client Admin')
    u.roles << client_admin_role
  end

  def set_flash_and_session(type=nil)
    type == 'Admin' ? flash[:error] = FLASH_MESSAGES['application']['701'] : (type == 'Asset Manager' ? flash[:error] = FLASH_MESSAGES['application']['702'] : flash[:error] = FLASH_MESSAGES['application']['703'])
    session[:return_to] = request.request_uri
    redirect_to login_path
  end



  #  def subdomain_change_database
  #    # 'SOME_PREFIX_' + is optional, but would make DBs easier to delineate
  #    logger.info $ip
  #    if $ip == "swig"
  #      ActiveRecord::Base.establish_connection(website_connection($ip + "_amp2dev_production" ))
  #    else
  #      ActiveRecord::Base.establish_connection(website_connection("amp2dev_production" ))
  #    end
  #  end
  #
  #
  #
  #  def website_connection(subdomain)
  #    default_connection.dup.update(:database => subdomain)
  #  end
  #
  #  # Regular database.yml configuration hash
  #  def default_connection
  #    @default_config ||= ActiveRecord::Base.connection.instance_variable_get("@config").dup
  #  end
  #
  #
  #
  #
  #  def get_ip
  #
  #    request.subdomain.split(".").each do |x|
  #      if ((x == "http://swig") || (x =="swig") || (x =="http://www.swig") )
  #        @a = 1
  #        break
  #      else
  #        @a=0
  #      end
  #    end
  #    if @a == 1
  #      $ip ="swig"
  #    else
  #      $ip =""
  #    end
  #  end

  private

  def set_current_user
    User.current= current_user
  end

  def set_current_client
    Client.current= current_client
  end

  def set_current_client_id
    Client.current_id = current_client_id
  end

  def clear_comments_var
    ApplicationController.collection_exp_comments[current_user.id] = Hash.new
  end
end
