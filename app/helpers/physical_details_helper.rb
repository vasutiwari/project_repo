module PhysicalDetailsHelper
  def update_page_after_adding_physical_details(page,view,active_title)
    page << "Control.Modal.close();"
    page.replace_html "head_for_titles", :partial => "/properties/head_for_titles/",:locals =>{:portfolio_collection => @portfolio,:note_collection => @note}
    page.call "active_title","#{active_title}"
    page.replace_html "overview", :partial => "#{view}"
    page.replace_html "#{@property.id}_li",:partial => "properties/property_list",:locals => {:p => @property , :portfolio_collection => @portfolio}
    page.call 'load_completer'
  end

  def property_view
    id = params[:property_id] ? params[:property_id] : params[:id]
    @note = RealEstateProperty.find_real_estate_property(id) if id
    @portfolio = Portfolio.find_by_id(@note.portfolio_id) if @note
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id) if @portfolio
    @property = RealEstateProperty.find_real_estate_property(id) if id
    @address = "#{@property.address.txt.gsub(".",",").strip.to_s},#{@property.city},#{@property.province},#{@property.zip}" if @property !=nil
    @folder = Folder.find_by_portfolio_id_and_real_estate_property_id_and_parent_id_and_is_master(@portfolio.id,@property.id,0,0) if @property && @portfolio
    #~ if params[:from_property_details] == 'true' &&  (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == "true" || params[:users_mail_form_close] == "true" )
      #~ responds_to_parent do
        #~ render :update do |page|
          #~ update_page_after_adding_physical_details(page,'/physical_details/property_view','property_view')
          #~ page.call 'load_map11',@address if @address
        #~ end
      #~ end
    #~ elsif params[:from_property_details] == 'true'
      #~ render :update do |page|
        #~ update_page_after_adding_physical_details(page,'/physical_details/property_view','property_view')
        #~ page.call 'load_map11',@address  if @address
      #~ end
    #~ else
      #~ render :update do |page|
        #~ page.replace_html "head_for_titles", :partial => "/properties/head_for_titles/",:locals=>{:portfolio_collection => @portfolio,:note_collection => @note}
        #~ page.replace_html "overview", :partial => "/physical_details/property_view"
        #~ page.call "active_title","property_view"
        #~ page.call 'load_map11',@address  if @address
      #~ end
    #~ end
  end

end
