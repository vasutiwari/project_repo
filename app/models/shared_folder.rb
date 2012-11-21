class SharedFolder < ActiveRecord::Base
  belongs_to :user
  belongs_to :folder
  before_save :set_client_id_in_shared_folder
#To find all the shared folders for the user with the client_id(property)
   scope :property_client_ids, (lambda do |client_id,user_id|
    {:conditions => ['client_id = ? and user_id = ? and is_property_folder = ?', client_id,user_id,1]}
  end)

  #To find all the shared folders for the user with out client_id(portfolio)
   scope :portfolios_with_out_client_id, (lambda do |user_id|
    {:conditions => ['user_id = ? and is_portfolio_folder = ?',user_id,1]}
  end)

  def set_client_id_in_shared_folder
     shared_client_id =  self.try(:user).try(:client).try(:id)
     self.client_id = shared_client_id ? shared_client_id : Client.current_client_id
  end

    scope :by_portfolio_id, (lambda do |portfolio_id|
    {:conditions => ['is_portfolio_folder=? AND portfolio_id=?', true,portfolio_id]}
  end)

#To find all the shared folders for the user with the client_id(property)
   scope :portfolio_client_ids, (lambda do |client_id,user_id|
    {:conditions => ['client_id = ? and user_id = ? and is_portfolio_folder = ?', client_id,user_id,1]}
  end)

  #To find all the shared folders for the user with the client_id(with out client id)(properties)
   scope :shared_folder_properties_with_out_client_id, (lambda do |user_id|
    {:select=>[:id,:user_id,:is_property_folder,:real_estate_property_id],:conditions => ['user_id = ? AND is_property_folder = ?',user_id,1]}
  end)

end
