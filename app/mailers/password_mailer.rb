class PasswordMailer < ActionMailer::Base
 # default :from => "from@example.com"
   def forgot_password(password)
    setup_password_email(password.user)
    @subject << 'You have requested to change your password'
    @url = "#{APP_CONFIG[:site_url]}/change_password/#{password.reset_code}"
  end

  def reset_password(user)
    setup_password_email(user)
    @subject << 'Your password has been reset.'
    @url_login = "#{APP_CONFIG[:site_url]}/login"
  end

  protected
  def setup_password_email(user)
    @recipients = "#{user.email}"
    @name_or_email = user.name? ? user.name : user.email
    @from = APP_CONFIG[:admin_email]
    @forgotmail = "#{APP_CONFIG[:site_url]}"
    @subject = "[#{APP_CONFIG[:site_name]}] "
    @sent_on = Time.now
    @content_type="text/html"
    @user = user
  end
end
