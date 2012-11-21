class Group < ActiveRecord::Base
  has_many :categories
  #~ def self.find_group_for_insurance
    #~ @group_collection = Group.find(:all)
    #~ @group_sub_collection = []
    #~ @group_collection.each do |group|
      #~ @group_sub_collection << group.categories # group sub collection
    #~ end
    #~ return @group_sub_collection.flatten
  #~ end
end
