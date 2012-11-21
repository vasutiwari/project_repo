class Event < ActiveRecord::Base
	has_many :event_resources,:dependent=>:destroy
	
  def self.create_new_event(action,user_id,shared_user_id,resources,person_type,folder_name,description2,other_info=nil)	
		if description2 != nil
			if description2.class == Array
				if action == "mapped_secondary_file" || action == "create_secondary_file"
					a  = " #{description2[0]} for the #{description2[1]}"
					folder_name = "#{folder_name}"
				elsif action == "collaborators" || action == "de_collaborators"
					a  = " in the task #{description2[0]} for the #{description2[1]}"
				elsif action == "task_commented" || action == "task_del_commented" || action == "task_up_commented" || action == "task_rep_commented"
					folder_name = "#{folder_name}"
				else
					a = "from #{description2[0]} to #{description2[2]}"
				end
			else
				a = description2
			end
		else
			a = nil
		end
		e = self.create(:user_id => user_id,:shared_user_id =>shared_user_id,:action_type => action,:description => folder_name,:performer => person_type,:description2=>a,:client_id=>Client.current_client_id)
		for each_res in resources
			EventResource.create(:event_id => e.id ,:resource => each_res)
		end	
	end	
	
  def self.create_new_event_multiple(action,user_id,shared_user_id,resources,person_type,other_info=nil)	
		e = self.create(:user_id => user_id,:shared_user_id =>shared_user_id,:action_type => action,:description => other_info,:performer => person_type,:client_id=>Client.current_client_id)
		for each_res in resources
			EventResource.create(:event_id => e.id ,:resource => each_res)
		end	
	end		
end