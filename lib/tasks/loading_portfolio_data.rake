  namespace :loading_portfolio_data do
    desc "loading  portfolio data  into the property capital improvements and property financial periods  tables"
    task :to_property_capital_improvements_and_property_financial_periods_table => :environment do
      begin
        
        Portfolio.where("name NOT LIKE ?", 'portfolio_created_by_system%').all.each do |portfolio|
          [2010, 2011, 2012].each do |year|
            Portfolio.portfolio_pci(portfolio.id, 0, year)
          end
        end
      rescue => e
        puts "Exception had been raised with message: #{e.message}"
      end
    end
    
    desc "loading portfolio data into the income and cash flow details and property financial periods  tables"
    task :to_income_and_cash_flow_details_and_property_financial_periods_table => :environment do
      begin
        Portfolio.where("name NOT LIKE ?", 'portfolio_created_by_system%').all.each do |portfolio|
          [2010, 2011, 2012].each do |year|
            Portfolio.portfolio_ic(portfolio.id, year)
          end
        end
      rescue => e
        puts "Exception had been raised with message: #{e.message}"
      end
    end
  end