module UsersHelper

  def if_authorized?(action, resource, &block)
    if authorized?(action, resource)
      yield action, resource
    end
  end

  def link_to_user(user, options={})
    raise "Invalid user" unless user
    options.reverse_merge! :content_method => :login, :title_method => :login, :class => :nickname
    content_text      = options.delete(:content_text)
    content_text    ||= user.send(options.delete(:content_method))
    options[:title] ||= user.send(options.delete(:title_method))
    raw(link_to h(content_text), user_path(user), options)
  end

  def link_to_login_with_IP content_text=nil, options={}
    ip_addr           = request.remote_ip
    content_text    ||= ip_addr
    options.reverse_merge! :title => ip_addr
    if tag = options.delete(:tag)
      raw(content_tag tag, h(content_text), options)
    else
      raw(link_to h(content_text), login_path, options)
    end
  end

  def link_to_current_user(options={})
    if current_user
      raw(link_to_user current_user, options)
    else
      content_text = options.delete(:content_text) || 'not signed in'
      # kill ignored options from link_to_user
      [:content_method, :title_method].each{|opt| options.delete(opt)}
      raw(link_to_login_with_IP content_text, options)
    end
  end

  def link_to_portfolio
    return Portfolio.find_portfolio_collections({:conditions => ['user_id=?', current_user.id],:limit=>5, :order=>"name DESC"})
  end
  def find_all_portfolio(user)
    return Portfolio.find_portfolio_collections({:conditions => ['user_id = ? and portfolio_type_id = 1', user]})
  end

    def find_user_details(email)
    role = Role.find_by_name('Shared User')
    user = User.find_by_email(email)
    if user.nil?
      user = User.new(:email=>email.strip)
      if params[:share] != "true"
        p = user.generate_password
        user.password = p
        user.password_confirmation =p
        user.is_shared_user = true
        user.password_code = User.random_passwordcode
        user.client_id = current_client_id
        user.save
        user.roles << role
        user.save
      end
    elsif user && !user.has_role?("Shared User")
      user.roles << role
      user.save(false)
    end
    return user
  end

  def user_profile_image(user_id)
    image = PortfolioImage.find(:first,:conditions=>['attachable_id = ? and attachable_type = ? and filename !="login_logo"',user_id,"User"])
    return (image.nil? || !FileTest.exists?(image.full_filename)) ? '/images/user.jpeg' : image.public_filename
  end
  
    def user_profile_nav_image(user_id)
    image = PortfolioImage.find(:first,:conditions=>['attachable_id = ? and attachable_type = ? and filename !="login_logo"',user_id,"User"])
    return (image.nil? || !FileTest.exists?(image.full_filename)) ? '/images/user.jpeg' : ((image.public_filename(:client_image_edit).present? && FileTest.exists?(image.public_filename(:client_image_edit))) ? image.public_filename(:client_image_edit) :  image.public_filename)
  end

  def user_default_image(user_id)
    image = PortfolioImage.find(:first,:conditions=>['attachable_id = ? and attachable_type = ? and filename !="login_logo"',user_id,"User"])
    return (image.nil? || !FileTest.exists?(image.full_filename)) ? '/images/userpics.png' : image.public_filename
  end
end
