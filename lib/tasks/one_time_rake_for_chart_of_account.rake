namespace :create_chart_of_accounts do
  desc 'creating chart_of_accounts'
  task :chart_of_account => :environment do
    users = User.find(:all, :conditions=>['email in (?)', ['swigamp@gmail.com','wresamp@gmail.com','griffinpm.amp@gmail.com','kwilliams.amp@gmail.com']])
    acc_mapping = {'swigamp@gmail.com' => 'MRI, SWIG', 'wresamp@gmail.com' => 'Real Page','griffinpm.amp@gmail.com' => 'Griffin_YARDI','kwilliams.amp@gmail.com' => ['AMP Excel','MRI, SWIG','Real Page'] }
    acc_name_mapping = {'swigamp@gmail.com' => 'swig_amp_chart_of_account', 'wresamp@gmail.com' => 'wres_amp_chart_of_account','griffinpm.amp@gmail.com' => 'griffin_amp_chart_of_account','kwilliams.amp@gmail.com' => 'kwilliams_amp_chart_of_account' }
    # If swigamp was already runned please comment the above code and enable the below code
    #        users = User.find(:all, :conditions=>['email in (?)', ['wresamp@gmail.com','GriffinAdmin_95@thesamp.com','kwilliams.amp@gmail.com']])
    #        acc_mapping = {'wresamp@gmail.com' => 'Real Page','GriffinAdmin_95@thesamp.com' => 'Griffin_YARDI','kwilliams.amp@gmail.com' => ['AMP Excel','MRI, SWIG','Real Page'] }
    #        acc_name_mapping = {'wresamp@gmail.com' => 'wres_amp_chart_of_account','GriffinAdmin_95@thesamp.com' => 'griffin_amp_chart_of_account','kwilliams.amp@gmail.com' => 'kwilliams_amp_chart_of_account' }
    kwilliams_acc_name = {1 => 'amp_kwilliams_chart_of_account', 2 =>'mri_swig_kwilliams_chart_of_account', 4 => 'yardi_kwilliams_chart_of_account'}
    User.transaction do
      Client.transaction do
        PortfolioImage.transaction do
          ChartOfAccount.transaction do
            users.each do |user|
              user.role_ids = [2,4]
              user.save(:validate => false)
              client = Client.find_by_id(user.client_id)
              acc_sys = AccountingSystemType.where('type_name in (?)',acc_mapping[user.email])
              client.update_attributes(:accounting_system_type_ids => acc_sys.map(&:id),:email => user.email, :name => user.try(:company_name))
              portfolio_image = PortfolioImage.create(:filename => "amp-logo.png", :content_type => "image/png", :attachable_id => client.id,:attachable_type => "Client", :height => 35, :width => 104, :size => "3036", :user_id => user.id)
              client.update_attributes(:portfolio_image_id => portfolio_image.id)
              portfolios = Portfolio.where('user_id = ? and client_id = ? and name NOT IN (?)',user.id,client.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"])
              if user.email.eql?('kwilliams.amp@gmail.com')
                acc_sys.map(&:id).each do |id|
                  chart_of_account = ChartOfAccount.create(:name => kwilliams_acc_name[id], :accounting_system_type_id => id, :client_id => client.id)
                end
                real_properties = RealEstateProperty.where('user_id = ? and client_id = ? and accounting_system_type_id is NOT NULL',user.id,client.id)
                real_properties.each do |real_props|
                  chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,real_props.accounting_system_type_id)
                  real_props.chart_of_account_id = chart_of_account.id
                  real_props.save(:validate => false)
                end
                portfolios.each do |portfolio|
                  chart_of_account_id = portfolio.real_estate_properties.first.chart_of_account_id
                  portfolio.update_attributes(:chart_of_account_id => chart_of_account_id)
                end
              else
                chart_of_account = ChartOfAccount.create(:name => acc_name_mapping[user.email], :accounting_system_type_id => acc_sys.map(&:id).first, :client_id => client.id)
                real_properties = RealEstateProperty.where(:user_id => user.id, :client_id => client.id)
                real_properties.each do |real_props|
                  real_props.chart_of_account_id = chart_of_account.id
                  real_props.save(:validate => false)
                end
                portfolios.each do |portfolio|
                  portfolio.update_attributes(:chart_of_account_id => chart_of_account.id)
                end
              end
            end if users.present?
          end
        end
      end
    end
  end

  desc "common rake for update and create chart of accounts"
  task :common_rake_for_update_and_create_chart_of_accounts => :environment do
#    begin
      RealEstateProperty.update_chart_of_account_id_as_nil_for_system_created_properties_and_portfolios
      RealEstateProperty.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id
      RealEstateProperty.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id_client_5
      RealEstateProperty.create_chart_of_accounts_for_metro
      RealEstateProperty.create_chart_of_accounts_for_external
      RealEstateProperty.create_chart_of_accounts_for_nas
      Portfolio.update_chart_of_account_in_all_the_portfolios
      Portfolio.update_wres_users
      RealEstateProperty.update_swig_users
      RealEstateProperty.update_kwilliams_users
      RealEstateProperty.update_shared_properties_of_client_admin
#    rescue => e
#      puts "Exception had been raised with message: #{e.message}"
#    end
  end

end