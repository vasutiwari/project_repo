class EventResource < ActiveRecord::Base
		belongs_to :event
		belongs_to :resource, :polymorphic => true
end
