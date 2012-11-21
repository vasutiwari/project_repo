class CommPropertyLeaseSuite < ActiveRecord::Base
  belongs_to :lease
  belongs_to :tenant

  before_save :update_client_id_for_comm_prop_lease_suite

  # adding current_client_id before saving to db
  def update_client_id_for_comm_prop_lease_suite
    self.client_id = Client.current_client_id
  end

end
