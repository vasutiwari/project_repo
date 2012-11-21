class PortfolioImage < ActiveRecord::Base
  has_attachment :storage => :file_system, :size => 1.bytes..160.megabytes, :content_type => [:image], :path_prefix => 'public/portfolio_images',:thumbnails => { :thumb => [172, 83],:client_image_index => [42,42],:client_image_edit => [60,60] }
  belongs_to :attachable, :polymorphic => true
  belongs_to :real_estate_property
  belongs_to :user
  has_many :client_settings
  validates_as_attachment

  def self.create_portfolio_image(data,property_id,image_cat)
      image = PortfolioImage.new
      image.uploaded_data = data
      image.attachable_id = property_id
      image.attachable_type = "RealEstateProperty"
      image.is_property_picture = true if image_cat == 'property_picture'
      image.save
  end

  def self.update_image(id,data,user,logo)
      user_image = logo ?  user.logo_image : PortfolioImage.find(:first, :conditions=>["attachable_id= ? and attachable_type=? and filename != 'logo_image'", id,'User'])
      user_image = PortfolioImage.new if  user_image.nil?
      user_image.uploaded_data = data
      user_image.filename = 'login_logo' if logo
      user_image.attachable_id =  id
      user_image.attachable_type = "User"
      user_image.save
      return user_image
  end


  def self.create_client_portfolio_image(data,portfolio_id)
      image = PortfolioImage.new
      image.uploaded_data = data
      image.attachable_id = portfolio_id
      image.attachable_type = "Portfolio"
      image.is_portfolio_picture = true
      image.save
      return image
  end

  def self.update_client_image(id,data)
    portfolio_image=PortfolioImage.find(:first, :conditions=>["attachable_id= ? and attachable_type=? and is_portfolio_picture = ?", id,'Portfolio',true])
      portfolio_image = PortfolioImage.new if  portfolio_image.nil?
      portfolio_image.uploaded_data = data
      portfolio_image.attachable_id =  id
      portfolio_image.attachable_type = "Portfolio"
      portfolio_image.save
      return portfolio_image
  end

end