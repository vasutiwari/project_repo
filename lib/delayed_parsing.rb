require Rails.root.to_s + '/config/boot'
require Rails.root.to_s + '/config/environment'
require Rails.root.to_s + '/lib/xml_extractor'

class DelayedParsing
  attr_accessor :in_file, :out_file, :doc_id, :opts ,:user
  def initialize(in_file, out_file, doc_id, opts,user)
    self.in_file= in_file
    self.out_file= out_file
    self.doc_id= doc_id
    self.opts= opts
    self.user = user
  end

  def delayed_logger message
    Rails.env=="production" ? (Delayed::Worker.logger.info message) : (puts message)
  end

  def perform
    t_doc=Document.find(self.doc_id)
    delayed_logger "\nDJ InProgress for #{t_doc.filename} at #{Time.current}"
    budget_parser = XmlExtractor.new(:month=>1, :year=>2011, :real_estate_id=> t_doc.real_estate_property_id, :user_id=> t_doc.user_id, :doc_id=>t_doc.id,:current_user=>self.user)
    budget_parser.xls_file = self.in_file
    budget_parser.output_file = self.out_file
    budget_parser.xml_dump
    budget_parser.process!(self.opts,self.user)
    t_doc.update_attribute('parsing_done',true) unless t_doc.parsing_done == false
    delayed_logger "DJ completed for #{t_doc.filename} at #{Time.current} \nPATH: #{t_doc.public_filename}\n"
  end

  def failure
    t_doc=Document.find_by_id(self.doc_id)
    t_doc.update_attribute('parsing_done',false) if t_doc
    delayed_logger "\nDJ Failed for #{t_doc.filename} at #{Time.current}\n"
  end
end
