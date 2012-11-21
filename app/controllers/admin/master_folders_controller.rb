class Admin::MasterFoldersController < ApplicationController
	layout 'admin'
	before_filter :admin_login_required
	before_filter :find_portfolio_type,:only=>['edit','new_file_creation','new_file_name_creation','new_folder_creation']
	before_filter :find_portfolio_folder,:only =>['edit','new_folder_creation']
	
	def edit				
		@portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:id],0])
	end
	
	def index
	end
	
	def new_file_creation			
		@portfolio_folder = MasterFolder.find(params[:folder_id])
		render :layout => false
	end
	
	def new_file_name_creation		
		@portfolio_file = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:id],0])
		render :layout => false
	end
	
	def new_folder_creation	
		render :layout => false
	end
	
	def new_master_folder
		@prev_folder =  MasterFolder.find(:first,:conditions => ["name=? and parent_id=? and portfolio_type_id=?",params[:folder_name],params[:parent_id],params[:portfolio_type_id]])
		@portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",params[:parent_id]])
		@parent_record = MasterFolder.find_by_id(params[:parent_id])
		@new_folder = MasterFolder.create(:name =>params[:folder_name],:parent_id => params[:parent_id],:portfolio_type_id => params[:portfolio_type_id]) if @prev_folder.nil?
		@portfolio_type = PortfolioType.find(params[:portfolio_type_id])
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],params[:parent_id]])
		@portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],params[:parent_id]])
		responds_to_parent do
			render :action => 'new_master_folder.rjs'
    end
	end
	
	def folder_delete
		@port_folder = MasterFolder.find(params[:id])
		@parent_id = @port_folder.parent_id
		@port_folder.destroy
		@portfolio_type = PortfolioType.find(params[:portfolio_type_id])
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],@parent_id])
		@portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",@parent_id])
		@portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],@parent_id])
		@parent_record = MasterFolder.find_by_id(@parent_id)
	end
	
	def file_delete
		@portfolio_file = MasterFilename.find(params[:id])
		@parent_id_tmp = @portfolio_file.master_folder_id
		@portfolio_file.destroy		
		@portfolio_type = PortfolioType.find(params[:portfolio_type_id])
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],@parent_id_tmp])
		@portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",@parent_id_tmp])
		@portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],@parent_id_tmp])
		@parent_record = MasterFolder.find_by_id(@parent_id_tmp)
	end
	
	def master_file_delete
		@portfolio_file = MasterFile.find(params[:id])
		parent_id = @portfolio_file.master_folder_id
		@portfolio_file.destroy		
		@portfolio_type = PortfolioType.find(params[:portfolio_type_id])
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],parent_id])
		@portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],parent_id])
		@portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",parent_id])
		@parent_record = MasterFolder.find_by_id(parent_id)
	end
	
	def change_master_due_date
		#Defined in rjs template file
	end
	
	def change_due_date
		f = MasterFilename.find(params[:id])
		if !params[:value].blank? && params[:value].to_i >= 1
			f.update_attributes(:due_days=>params[:value])
			render :update do |page|
				page.call("do_date_update","#{params[:id]}","#{f.due_days}")
			end
		else
			render :update do |page|
        page.call("do_date_update","#{params[:id]}","#{f.due_days}")
			end
		end			
	end
	
  def change_master_file_name
		#argument 1 is passed for files & 0 is passed for filenames in do_file_update function
    #Defined in rjs template
  end
	
  def change_master_folder_name
   #Defined in rjs template
  end
	
	def show_folder_content
		@portfolio_type = PortfolioType.find(params[:portfolio_type_id])		
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],params[:id]])
		@portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",params[:id]])
    @portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],params[:id]])
		@parent_record = MasterFolder.find_by_id(params[:id])
	end
	
	def new_file_upload
		@file_upload = MasterFile.new(params[:master_excel_template])
		if !@file_upload.temp_path.blank?
			if params[:master_excel_template]
				@file_upload.update_attributes(:master_folder_id => params[:master_folder_id] , :due_days => params[:due_days])
			end
      #redirect_to edit_admin_master_folder_path(params[:portfolio_type_id])
      @portfolio_type = PortfolioType.find(params[:portfolio_type_id])
      @portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:portfolio_type_id],params[:master_folder_id]])
      @portfolio_filename = MasterFilename.find(:all, :conditions => ["portfolio_type_id = ? and master_folder_id = ?",params[:portfolio_type_id],params[:parent_id]])
      @portfolio_files = MasterFile.find(:all, :conditions => ["master_folder_id = ?",params[:master_folder_id]])
      @parent_record = MasterFolder.find_by_id(params[:parent_id])
      responds_to_parent do
        render :action => 'new_file_upload.rjs'
      end
		else #!@file_upload.temp_path.blank?
			responds_to_parent do
				render :update do |page|
					page.replace_html 'error_display', FLASH_MESSAGES['masterfolder']['5002']
				end
			end			
    end
	end
	
  def download_master_file
		f = MasterFile.find(params[:id])
		send_file "#{RAILS_ROOT}/public"+f.public_filename
  end	
	
	def master_recursive_function(folder_id,zipfile,location)
    folders = MasterFolder.find(:all,:conditions=> ["parent_id = ?",folder_id])
    documents = MasterFile.find(:all,:conditions=> ["master_folder_id = ?",folder_id])
		folders.each do |f|
			zipfile.mkdir("#{location}/#{f.name}")
			master_recursive_function(f.id,zipfile,"#{location}/#{f.name}")
		end
		documents.each do |doc|
			zipfile.add("#{location}/#{doc.filename}","#{RAILS_ROOT}/public#{doc.public_filename}")
		end
	end
	
  def download_master_folder(folder_id,zipfile)
		@folder = MasterFolder.find_by_id(folder_id,true)
		zipfile.mkdir("#{@folder.name}")
		master_recursive_function(folder_id,zipfile,"#{@folder.name}")
	end
	
  def folder_download
    folder = MasterFolder.find(:first,:conditions=> ["id = ?",params[:id]])
		folder_name = folder.name
    if File.exists? "#{RAILS_ROOT}/public/#{folder_name}.zip"
      File.delete("#{RAILS_ROOT}/public/#{folder_name}.zip")
    end
    Zip::ZipFile.open("#{RAILS_ROOT}/public/#{folder_name}.zip", Zip::ZipFile::CREATE) { |zipfile|
      download_master_folder(folder.id,zipfile)
    }
    send_file "#{RAILS_ROOT}/public/#{folder_name}.zip"
  end

	def master_folder_dragndrop
    drop = params[:drop_ele].split("-")
    drag = params[:drag_ele].split("-")
		already_folder , already_file = MasterFolder.find_and_update_attributes(drop,drag)
    render :update do |page|
      if already_file.nil? and already_folder.nil?
				drop_element = MasterFolder.find_by_id(drop[1])
				page.hide params[:drag_ele]	
        if params[:fdr_de] == "folder"				
					name = "#{drop_element.name} [#{no_of_files_of_folder(drop_element.id, true)}]"
					page["folder_name_a_id#{drop[1]}"].innerHTML=name if page["folder_name_a_id#{drop[1]}"]
				end
        page.alert("Successfully moved")
      else
        page.alert("Already '#{folder.name}' folder available there") if  !already_folder.nil?
        page.alert("Already '#{document.name}' file available there") if  !already_file.nil?
      end
    end
	end	
	
	def find_portfolio_type
		@portfolio_type = PortfolioType.find(params[:id])
	end
	
	def find_portfolio_folder
		@portfolio_folder = MasterFolder.find(:all, :conditions => ["portfolio_type_id = ? and parent_id = ?",params[:id],0])
	end
end