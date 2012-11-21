class ClientAdmin::PropertyController < ApplicationController
	before_filter :user_required
	 layout "client_admin"

  def index

  end
end
