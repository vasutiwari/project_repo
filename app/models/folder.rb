class Folder < ActiveRecord::Base

  #Validations
  attr_accessor :update_created_at
  has_many :documents,:dependent=>:destroy
  has_many :document_names,:dependent=>:destroy
  has_many :shared_folders,:dependent=>:destroy
  has_many :shared_documents,:dependent=>:destroy
  has_many :event_resources, :as=>:resource,:dependent=>:destroy
  belongs_to :user
  belongs_to :portfolio
  belongs_to :property
  belongs_to :real_estate_property
  before_save :check_folder_name_already_exists
  #~ before_create :set_client_id
  after_save :update_date_for_parents
  before_destroy :update_date_for_parents
  scope :current_user_files,     lambda { { :conditions => ["name = 'my_files' and parent_id = 0 and user_id = ?",User.current.id], :select=>"id" } }
  acts_as_commentable
  def check_folder_name_already_exists
    if self.id.nil?
      folder = Folder.find_by_name(self.name,:conditions=>["parent_id = ? and real_estate_property_id =? and portfolio_id=?",self.parent_id,self.real_estate_property_id,self.portfolio_id])
    else
      folder = Folder.find_by_name(self.name,:conditions=>["parent_id = ? and real_estate_property_id = ? and id!=? and portfolio_id=?",self.parent_id,self.real_estate_property_id,self.id,self.portfolio_id])
    end
    i =1
    while folder !=nil
      first_set =  self.name
      folder_name = "#{first_set}_#{i}"
      if self.id.nil?
        folder = Folder.find_by_name(folder_name.strip,:conditions=>["parent_id = ? and real_estate_property_id = ? and portfolio_id=?",self.parent_id,self.real_estate_property_id,self.portfolio_id])
      else
        folder = Folder.find_by_name(folder_name.strip,:conditions=>["parent_id = ? and real_estate_property_id = ? and id!=? and portfolio_id=?",self.parent_id,self.real_estate_property_id,self.id,self.portfolio_id])
      end
      i += 1
    end
    folder_name =  folder_name.nil? ? self.name : folder_name
    self.name = folder_name
  end

def self.subfolders_docs(folder_id,loop,is_property_sharing,params)
    if loop == true
    @folder_snew = [ ]
    @doc_snew = [ ]
    @doc_namenew = [ ]
    end
    if params[:is_lease_agent] == 'true' && loop
      folder_names = ["Excel Uploads","AMP Files"]
      folders = loop && is_property_sharing ? self.find(:all,:conditions=> ["parent_id = ? and is_master = ? and name not in (?) ",folder_id,true,folder_names]) : self.find(:all,:conditions=> ["parent_id = ?",folder_id])
    else
      folders = loop && is_property_sharing ? self.find(:all,:conditions=> ["parent_id = ? and is_master = ? ",folder_id,true]) : self.find(:all,:conditions=> ["parent_id = ?",folder_id])
    end
    @folder_snew = [ ] if @folder_snew.nil? || @folder_snew.empty?
    @doc_snew = [ ] if @doc_snew.nil? || @doc_snew.empty?
    @doc_namenew = [ ] if @doc_namenew.nil? || @doc_namenew.empty?
    folders.each do |f|
      self.subfolders_docs(f.id,false,false,params)
      @folder_snew << f
    end
    if(is_property_sharing)
      documents = Document.find(:all,:conditions=> ["folder_id = ?",folder_id]) if !loop
    else
      documents = Document.find(:all,:conditions=> ["folder_id = ?",folder_id])
    end
    document_name = DocumentName.find(:all,:conditions=> ["folder_id = ?",folder_id])
    @doc_snew += documents if documents
    @doc_namenew += document_name
    return @folder_snew,@doc_snew,@doc_namenew
  end

  def self.find_mail_path_folder(fol)
    arr =[]
    i = 0
    while !fol.nil?
      tmp_name = "#{fol.name}"
      name = (i == 0) ? "#{fol.name}" :  "#{tmp_name}"
      n = (fol.name == 'my_files' && fol.parent_id == 0) ? name.titlecase : name
      arr << n
      fol =  Folder.find_by_id(fol.parent_id)
      i += 1
    end
    return arr.reverse.join(" > ")
  end

  def self.find_parent_id_and_real_estate_property_id(parent_id,document)
    Folder.find_by_parent_id_and_real_estate_property_id(parent_id,document.real_estate_property_id)
  end

  def self.find_folder(id)
    self.find(:first,:conditions=> ["id = ?",id])
  end

  def self.create_sub_folders_for_portfolio(property_folder,property,name)
    months_12 = [12,11,10,9,8,7,6,5,4,3,2,1]
    folder = Folder.create(:name =>name,:portfolio_id => property_folder.portfolio_id,:real_estate_property_id => property.id,:user_id => property_folder.user_id,:parent_id =>property_folder.id,:is_master =>1)
    folder_excel = Folder.create(:name =>"Sample Templates",:portfolio_id => property_folder.portfolio_id,:real_estate_property_id => property.id,:user_id => property_folder.user_id,:parent_id =>folder.id,:is_master =>1 )
    folder_year = Folder.create(:name =>"#{Date.today.year}",:portfolio_id => property_folder.portfolio_id,:real_estate_property_id => property.id,:user_id => property_folder.user_id,:parent_id =>folder.id,:is_master =>1 )
    months_12.each do |mo|
      Folder.create(:name =>"#{Date::MONTHNAMES[mo].slice(0,3)}",:portfolio_id => property_folder.portfolio_id,:real_estate_property_id => property.id,:user_id => property_folder.user_id,:parent_id =>folder_year.id,:is_master =>1,:created_at => "#{1.second.since(Folder.last.created_at)}")
    end
    return folder_excel
  rescue Exceptio => e
    p "error creating folders:#{e.message}"
  end

  def self.create_sub_folders(property_folder,property,name)
    months_12 = [12,11,10,9,8,7,6,5,4,3,2,1]
    folder = Folder.create(:name =>name,:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>property_folder.id,:is_master =>1)
    folder_excel = Folder.create(:name =>"Sample Templates",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>folder.id,:is_master =>1 )
    folder_year = Folder.create(:name =>"#{Date.today.year}",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>folder.id,:is_master =>1 )
    months_12.each do |mo|
      Folder.create(:name =>"#{Date::MONTHNAMES[mo].slice(0,3)}",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>folder_year.id,:is_master =>1,:created_at => "#{1.second.since(Folder.last.created_at)}")
    end
    return folder_excel
  rescue Exceptio => e
    p "error creating folders:#{e.message}"
    end

  #to check  a folder is portfolio or not
  def is_portfolio?
    self.parent_id == -1 ? true : false
  end

  def self.procedure_call(folder)
    ret = ActiveRecord::Base.connection.execute("call ChkBudgetUploadedInProperty(#{folder})")
    ret = Document.record_to_hash(ret).first
    ActiveRecord::Base.connection.reconnect!
    ret
  end

  def update_date_for_parents
    unless self.update_created_at == false
      folder=(!self.parent_id.blank? && self.parent_id>0) ? Folder.find_by_id(self.parent_id) : nil
      folder.update_attribute('updated_at',Time.now) if folder
    end
  end

  #for lease docs start
  def self.find_lease_folder_by_property_id(propid)
    property_parent = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(propid,0,0)
    property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_name(propid,property_parent.try(:id),"Lease Files")
    return property_folder
  end

  #for lease docs end
  #for suite docs start
  def self.find_suite_folder_by_property_id(propid)
    property_parent = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(propid,0,0)
    property_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_name(propid,property_parent.id,"Floor Plans")
    return property_folder
  end
#for suite docs end

#to set the client_id for folder
#~ def set_client_id
     #~ self.client_id = Client.current_client_id
   #~ end

   def self.folder_of_a_portfolio(portfolio_id)
     self.find_by_portfolio_id(portfolio_id)
   end

#to create records in folder table for existing properties
def self.update_parent_id_for_folder_for_basic_portfolios
  portfolios = Portfolio.where(:is_basic_portfolio => true)
  portfolios.each do |portfolio|
    folder = Folder.find_by_portfolio_id_and_real_estate_property_id(portfolio.try(:id),nil)
      folder.update_attribute(:parent_id,  -1)
  end
end

def self.create_folder_for_portfolio_and_property_mapping
  portfolios = Portfolio.where(:is_basic_portfolio => true)
  portfolios.each do |portfolio|
     real_estate_properties =   portfolio.real_estate_properties
     real_estate_properties.each do |real_estate_property|
      Folder.find_or_create_by_name_and_portfolio_id_and_real_estate_property_id_and_user_id_and_client_id(real_estate_property.property_name,portfolio.id,real_estate_property.id,portfolio.user_id,portfolio.client_id)
    end
  end
end

end
