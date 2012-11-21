class Info < ActiveRecord::Base
  has_one :note, :as => :note,    :dependent => :destroy
  belongs_to :tenant

  accepts_nested_attributes_for :note,:reject_if => :all_blank

  INFO_TYPE = [
    ["",nil],
    [ "Gross", "Gross" ],
    [ "Net", "Net" ]
  ]

  INFO_USE = [
    ["",nil],
    [ "Office", "Office" ],
    [ "Retail", "Retail" ],
    [ "Industrial", "Industrial" ],
    [ "Mixed use", "Mixed use" ]
  ]

  INFO_RENEWAL = [
    ["",nil],
    [ "New", "New" ],
    [ "Renewal", "Renewal" ]
  ]

  def self.create_info_amedments(*args)
    args = args.extract_options!
    Info.create(:type => args[:type], :use => args[:use], :lease_msg => args[:lease_msg], :renewal => args[:renewal], :amendments => args[:amendments], :tenant_id => args[:tenant_id])
  end
end
