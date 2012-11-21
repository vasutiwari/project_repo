class ClientSetting < ActiveRecord::Base
  serialize :accounting_system_type_ids
  validates_presence_of :extension, :if => :check_separate_mail
  validates_presence_of :separate_email , :if => :check_extension
  validates_format_of   :extension , :with => /^((?:[-a-z0-9]+\.)+[a-z]{2,})$/i , :message => "Extension is not in valid format." , :if => :check_separate_mail
  validates_exclusion_of :extension, :in => %w(gmail.com yahoo.com hotmail.com) , :message => "common extension cannot be used."
  #validates_format_of :extension, :with => //, :message => "Email extension does not include gmail.com", , :if => :check_separate_mail
  validates_uniqueness_of :extension , :message => "extension already available." , :if => :check_separate_mail
  #~ validates_presence_of :client_name, :message =>"Client Name can't be empty" , :if => :check_separate_mail
  #~ validates_length_of :client_name, :within=> 3..100,:too_long=>"Client Name should not contain more than 100 characters", :too_short=>"Must have at least 3 characters"
  #~ validates_format_of :client_name, :with => /^[\w\s]([\w]*[\s]*[\w]*)*[\w\s]$/,  :message => "Client Name can contain alphabets,digits,space & underscore"
  validates_length_of :separate_email,    :within => 6..100 ,:message=>"Email Id must be between 6 to 100 characters" , :if => :check_extension
  validates_format_of :separate_email, :with => /^[^@][\w.-]+@[\w.-]+[.][a-z]{2,4}$/i, :message => "Email is not in valid format." , :if => :check_extension
  validates_uniqueness_of :separate_email,:message=>"This Email Id already taken", :if => :check_extension

  before_save :update_client_id_for_client_setting

  #client id added
  def update_client_id_for_client_setting
    client_id  = Client.current_client_id
    self.client_id = client_id  if client_id.present?
  end

  def self.create_email_extensions(extension,acc_sys_ids,separate_email)
    extension_array = extension.split(",").collect{|value| value.strip}.delete_if{|value| value.empty?}
    mail_array = separate_email.split(",").collect{|value| value.strip}.delete_if{|value| value.empty?}
    email_extension = []

    if extension_array.present?
      extension_array.each do |value|
        email_extension << ClientSetting.new(:extension => value,:accounting_system_type_ids=>acc_sys_ids)
      end
    end

    if mail_array.present?
      mail_array.each do |value|
        email_extension << ClientSetting.new(:separate_email=>value,:accounting_system_type_ids=>acc_sys_ids)
      end
    end
    return email_extension
  end

  def check_separate_mail
    separate_email.blank?
  end

  def check_extension
    extension.blank?
  end
end
