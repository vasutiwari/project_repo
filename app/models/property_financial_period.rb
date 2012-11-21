class PropertyFinancialPeriod < ActiveRecord::Base
  belongs_to :source, :polymorphic => true

  def self.procedure_call(*args)
    args = args.extract_options!
    ret = ActiveRecord::Base.connection.execute("call propFinancialFindReplace(#{args[:sourceIn]},\"#{args[:sourceTypeIn]}\",\"#{args[:pcbIn]}\")")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!
    ret
  end

end
