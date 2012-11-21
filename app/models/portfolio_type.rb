class PortfolioType < ActiveRecord::Base
	has_many :master_folders, :dependent=>:destroy
	has_many :master_filenames, :dependent=>:destroy
	has_many :portfolios, :dependent=>:destroy
  validates_presence_of :name
  validates_length_of :name,:within => 3..40
  validates_uniqueness_of :name, :message =>"Portfolio type already exists"
	def self.find_portfolio_type(name)
		PortfolioType.find_by_name(name).id
	end
  def self.collect_all_name_and_id
    PortfolioType.all.collect {|p| [ p.name, p.id ] }
  end
  def self.find_and_save_portfolio_type(params)
    @portfolio_type = PortfolioType.find_by_id(params[:id])
    @portfolio_type.update_attributes(:variance_percentage => (params[:variance_percentage].empty? ? 0 : params[:variance_percentage]),:variance_amount => (params[:variance_amount].empty? ? 0 : params[:variance_amount]),:and_or => (!params[:variance_and_or] ? 'and' : params[:variance_and_or]),:cap_exp_variance => (params[:cap_exp_variance].empty? ? 0 : params[:cap_exp_variance]))
  end
end