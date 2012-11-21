# Helper Files are included here

module IncludeHelpers
  include ActionView::Helpers::NumberHelper
	include ApplicationHelper
	include PropertiesHelper
	include FoldersHelper
  include DocumentsHelper
  include PerformanceReviewPropertyHelper
  include SwigParsingHelper
  include WresParsingHelper
	include CollaborationHubHelper
	include UsersHelper
	include RealEstatesHelper
  include CollaboratorsHelper
	include PerformanceReviewCalculationsHelper
	include EventsHelper
	include WresPerformanceReviewHelper
  include PhysicalDetailsHelper
  include TreeViewHelper
  include SharedUsersHelper
  include AmpParsingHelper
  include YardiParser
  # Has to be removed and loaded in the appropriate class(*others too)
  include BulkUploadParser
  include LeaseHelper
  include DashboardHelper
  include NavDashboardHelper
  include ClientAdmin::PropertiesHelper
  include Admin::LogosHelper
end
