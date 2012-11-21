class CommentsController < ApplicationController

  # this is the method used to [ add / edit / update / delete ] comments.
  # @notice is used to display the flash notifications
  # info and comm are used for sending mail notifications.
  # => params[:exp_cmt_for]  is only for explanations comment
  before_filter :user_required

  def comment_view
    @comment_id_to_delete = nil
    @event_id_to_delete = nil
    init_loader = {'puretask'=>'Task.find_by_id params[:id]','task'=>'Task.find_by_id params[:id]','folder'=>'Folder.find_by_id params[:id]', 'document'=>'Document.find_by_id params[:id]','summary'=>'Folder.find_by_id params[:id]'}
    event_name  = {'puretask'=>'@item.task_type.task_name','task'=>"@item.document.filename", 'folder'=>'@item.name', 'document' => '@item.filename', 'explanation'=>'explanation comment','summary'=>'@item.name'}
    unless params[:exp_cmt_for]
      @item = eval(init_loader[params[:type]])
      else
      if (params[:exp_cmt_for] == 'cap_exp')
        @item = CapitalExpenditureExplanation.find_by_id(params[:id])
        exp_item = @item.property_capital_improvement.tenant_name.strip
      else
        @item = IncomeCashFlowExplanation.find_by_id(params[:id])
        exp_item = @item.income_and_cash_flow_detail.title.strip
      end
    end
    info = @notice = ""
    comm = []
    fl_name = params[:exp_cmt_for] ? "Explanation comments" : eval(event_name[params[:type]])
    if params[:save] && !params[:save].nil?
      add_comment(comm,fl_name)
      info ="Added"
    elsif params[:delete] && !params[:delete].nil?
      delete_comment(comm,fl_name)
      info = "Deleted "
    elsif params[:update] && !params[:update].nil?
      update_comment(comm,fl_name)
       info = "Updated "
    elsif params[:reply] && !params[:reply].nil?
      reply_comment(comm,fl_name)
      info = "Replied "
      end
    unless info.empty?
      list_collaborators = Array.new
      if @item.class == Document
        @item.shared_documents.each do
          |itr| list_collaborators = list_collaborators | [itr.user_id,itr.sharer_id]
        end
      elsif @item.class == Folder
        @item.shared_folders.each do |itr| list_collaborators = list_collaborators | [itr.user_id,itr.sharer_id] end

      elsif @item.class == IncomeCashFlowExplanation
        find_property =  @item.income_and_cash_flow_detail
        property = find_property.resource_id
        @note = RealEstateProperty.find_real_estate_property(property)

      elsif @item.class == CapitalExpenditureExplanation
      find_property =  @item.property_capital_improvement
        property = find_property.real_estate_property_id
        @note = RealEstateProperty.find_real_estate_property(property)


        if remote_property(@note.accounting_system_type_id)
        shared_users = SharedFolder.find_by_real_estate_property_id(@note.id)
        @note.user.shared_folders.each do |itr| shared_users = shared_users | [itr.user_id,itr.sharer_id]   end
        info = info
        else
        @item.document.shared_documents.each do |itr| list_collaborators = list_collaborators | [itr.user_id,itr.sharer_id] end
        info = info + "__#{@item.document.filename}"
        end
      end
      list_collaborators.compact!
      list_collaborators.each do |collab|
        next if collab == current_user.id
        user = User.find_by_id(collab);
        unless (params[:exp_cmt_for] || params[:comment_place])
          if params[:type] == "summary"
            UserMailer.delay.summary_comments_notification(comm,info,user,current_user,fl_name,@item.portfolio_id,@item.real_estate_property_id)
          else
            UserMailer.delay.comments_notification(comm, info, user, current_user, fl_name,params)
          end
        end
      end
      if params[:comment_place] == "inside task"
        if params[:exp_cmt_for]
          collect_comments(info,comm,exp_item)
        else
          collect_comments(info,comm)
        end
      end
    end
  end

 #added to collect task comments recently added
  def collect_comments(info,comm,exp_item=nil)
    comment_for = @note.user.id
    if comment_for
      if params[:exp_cmt_for] == "cap_exp"
      if session[:capital_explanation_comments].blank?
        session[:capital_explanation_comments] = {}
          session[:capital_explanation_comments].store(comment_for,{exp_item=>["#{info.split('__').first} - '#{comm[0].strip}'"]})
        elsif !session[:capital_explanation_comments].blank? && session[:capital_explanation_comments].has_key?(comment_for)
          if session[:capital_explanation_comments][comment_for][exp_item].blank?
            session[:capital_explanation_comments][comment_for].store(exp_item,["#{info.split('__').first} - '#{comm[0].strip}'"])
          else
            session[:capital_explanation_comments][comment_for][exp_item] << "#{info.split('__').first} - '#{comm[0].strip}'"
          end
        else
        session[:capital_explanation_comments].store(comment_for,{exp_item=>["#{info.split('__').first} - '#{comm[0].strip}'"]})
        end
        elsif params[:exp_cmt_for] == "cash_flow"
        if session[:cashflow_explanation_comments].blank?
          session[:cashflow_explanation_comments] = {}
          session[:cashflow_explanation_comments].store(comment_for,{exp_item=>["#{info.split('__').first} - '#{comm[0].strip}'"]})
        elsif !session[:cashflow_explanation_comments].blank? && session[:cashflow_explanation_comments].has_key?(comment_for)
          if session[:cashflow_explanation_comments][comment_for][exp_item].blank?
            session[:cashflow_explanation_comments][comment_for].store(exp_item,["#{info.split('__').first} - '#{comm[0].strip}'"])
          else
            session[:cashflow_explanation_comments][comment_for][exp_item] << "#{info.split('__').first} - '#{comm[0].strip}'"
          end
        else
        session[:cashflow_explanation_comments].store(comment_for,{exp_item=>["#{info.split('__').first} - '#{comm[0].strip}'"]})
        end
        else
        if session[:comments].blank?
          session[:comments] = {}
          session[:comments].store(comment_for, ["#{info.split('__').first} - '#{comm[0].strip}'"])
        elsif !session[:comments].blank? && session[:comments].has_key?(comment_for)
          session[:comments][comment_for] << "#{info.split('__').first} - '#{comm[0].strip}'"
        elsif !session[:comments].blank? && !session[:comments].has_key?(comment_for)
          session[:comments].store(comment_for,["#{info.split('__').first} - '#{comm[0].strip}'"])
        end
    end
    end
  end

 def add_comment(comm,fl_name)
    if params[:type] == "summary"
      @new_cmt = []
        new_cmt1 = Comment.new(:comment=> params[:comment], :user_id=>current_user.id, :is_reply => false,:commentable_type =>params[:type],:commentable_id=>@item.id)
        new_cmt1.save
        @new_cmt << new_cmt1
      else
        comment = Comment.new(:comment=> params[:comment], :user_id=>current_user.id, :is_reply => false)
        @new_cmt = @item.add_comment comment
        @comment_id_to_delete = comment.id
      end
    #info = params[:exp_cmt_for] ? "added the following variance explanation comment to " : "added the following comment to "
      @notice = FLASH_MESSAGES['comments']['803']
      comm  << params[:comment]
      comm << "Added comment:"
        Event.create_new_event("commented",current_user.id,nil,[@item],current_user.user_role(current_user.id),fl_name,nil)
        @event_id_to_delete = Event.find(:first,:order=>"created_at desc",:select =>"id").id rescue nil
    end

    def delete_comment(comm,fl_name)
       del_com = Comment.find params[:comment_id]
      del_com.destroy
      Comment.delete_all "parent_id =#{params[:comment_id]}"
      #info = params[:exp_cmt_for] ? "deleted the following variance explanation comment to " : "deleted the following comment to "
      @notice = FLASH_MESSAGES['comments']['801']
      comm << del_com.comment # to know the comment which is deleted.
      comm << "Deleted comment:"
        Event.create_new_event("del_comment",current_user.id,nil,[@item],current_user.user_role(current_user.id),fl_name,nil)
    end

    def update_comment(comm,fl_name)
      com = Comment.find params[:comment_id]
      com.comment = params[:comment]
      com.save
      @updated_comment = com
      #info = params[:exp_cmt_for] ? "updated the following variance explanation comment to " :"updated the following comment to "
      @notice = FLASH_MESSAGES['comments']['804']
      comm << com.comment
      comm << "Updated comment:"
        Event.create_new_event("up_comment",current_user.id,nil,[@item],current_user.user_role(current_user.id),fl_name,nil)
  end

  def reply_comment(comm,fl_name)
    @item.add_comment Comment.new :comment=> params[:comment], :user_id=>current_user.id, :is_reply => true, :parent_id=>params[:comment_id]
      #info = params[:exp_cmt_for] ? "replied the following variance explanation comment to " : "replied the following comment to "
      @notice = FLASH_MESSAGES['comments']['802']
      comm << params[:comment]
      comm << "Replied comment"
        Event.create_new_event("rep_comment",current_user.id,nil,[@item],current_user.user_role(current_user.id),fl_name,nil)
   end
end
