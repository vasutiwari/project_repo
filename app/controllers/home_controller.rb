class HomeController < ApplicationController
  layout 'user_login',:except=>["get_started","new",'additional_info','page_error','page_error_for_loader','notes','news','paymentconfirm']
  before_filter :user_required, :only => [:news, :paymentconfirm]
  before_filter :change_session_value, :only=>[:news]
  def new
    @contact=Contact.new
  end

  def create
    @contact=Contact.new(params[:contact])
    if @contact.valid? && @contact.errors.empty?
      @contact.save
      UserMailer.delay.contact_us(@contact)
      redirect_to root_path
    else
      render :action=>'new'
    end
  end

  def page_error
    render :layout=>false
  end

  def list_of_charts
    render :layout=>false
  end

  def video_sample
    render :layout=>false
  end

  def video
    render :layout=>false
  end

  def news
    render :layout=>"user"
  end

  def calltest
    render :layout=>false
  end

  def page_error_for_loader
    render :update do |page|
      page.call 'close_control_model'
      page.call "load_completer"
    end
  end

  def transactions
    render :layout=>"user"
  end

  #contact us page
  def get_started
    if params[:email]
      @contact=Contact.create(:email=>params[:email].strip)
      if @contact.save
        render :update do |page|
          page.replace_html "get_started2", :partial => "additional_info"
        end
      else
        render :update do |page|
          msg = @contact && @contact.errors && @contact.errors[:email] ? @contact.errors[:email].to_a[0] : ""
          page.replace_html "error_msg", msg
        end
      end
    end
  end

  #displays addtional information form in	get_started
  def additional_info
    @contact=Contact.find_by_id(params[:id])
    @contact.attributes = {:name=>params[:name],:comment=>params[:comments],:phone_number =>params[:phone] }
    if @contact.save && ( simple_captcha_valid? || params[:field] == "skip" )
      UserMailer.delay.contact_us(@contact)
      render :update do |page|
        page.replace_html "get_started2", :partial => "thanks_page"
        page.call "load_completer"
      end
    else
      render :update do |page|
        page.replace_html "error_msg","Image and text were different"
        page.replace_html "name_error_msg", "Provide a valid name" if !@contact.errors[:name].blank?
        page.replace_html "phone_error_msg", "Provide a valid Phone Number" if !@contact.errors[:phone_number].blank?
        page.call "load_completer"
      end
    end
  end

  #To Add Notes
  def notes
    if params[:content]
      user = User.find_by_id_and_client_id(current_user.id,current_client_id)
      user.content = params[:content] if user
      user.save(:validate => false)
      redirect_to "/notes"
    end
  end

  def rss_site
    redirect_to params[:url]
  end

  #~ def paymentconfirm
  #~ if  params[:payment_status] && params[:payment_status].eql? ("completed")
  #~ logger.info "current_user.inspect--------------"
  #~ logger.info current_user.inspect
  #~ user = User.find_by_id(user.current_user.id)
  #~ @amount = user.amp_users_phone_call
  #~ @amount_already = user.amp_users_phone_call.credit_available
  #~ @amount.credit_available = @amount_already + 10

  #~ @amount.save
  #~ redirect_to "/welcome"
  #~ end

  #~ redirect_to "/welcome"
  #~ end

  def change_session_value
    if (params[:portfolio_id].present? && params[:property_id].present?)
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id]
    elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
      session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
    else
      session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
    end
  end

end
