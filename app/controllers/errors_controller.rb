class ErrorsController < ApplicationController
	ERRORS = [
    :internal_server_error,
    :not_found,
    :unprocessable_entity
  ].freeze

  ERRORS.each do |e|
    define_method e do
      respond_to do |format|
        current_uri = request.env['PATH_INFO'].include?"client_admin"
        ExceptionNotifier.deliver_exception_notification($exception_global, self, request)
        format.html { redirect_to page_error_url(:current_uri => current_uri)}
        format.any { head e }
      end
    end
  end
end
