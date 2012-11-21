class TasksController < ApplicationController
   def check_variance_task
    if params[:performance_review_page] == "wres_leases"
      @performance_review_path = params[:performance_review_path].gsub("and","&")
      @title_explanation = params[:title_explanation]
      @units_explanation = params[:units_explanation].to_f.round
      @sqft_explanation = params[:sqft_explanation].to_f.round
      @text_explanation = params[:text_explanation]
      @var_per_explanation = params[:var_per_explanation].to_f.round(2).abs
      @id_explanation = params[:id_explanation].to_i
      @month_explanation = params[:month_explanation].to_i
      @year_explanation = params[:year_explanation] == 'true' ? true : false
      @user_id_explanation = params[:user_id_explanation].to_i
    else
      @performance_review_path = params[:performance_review_path].gsub("and","&")
      @doc = Document.find_document_by_id(params[:doc_id])
      @title_explanation = params[:title_explanation]
      @budget_explanation = params[:budget_explanation].to_f.round
      @actual_explanation = params[:actual_explanation].to_f.round
      @text_explanation = params[:text_explanation]
      @var_per_explanation = params[:var_per_explanation].to_f.round(2).abs
      @var_amt_explanation = params[:var_amt_explanation].to_f.round
      @id_explanation = params[:id_explanation].to_i
      @month_explanation = params[:month_explanation].to_i
      @year_explanation = params[:year_explanation] == 'true' ? true : false
      @year_value = params[:year_value].to_i if params[:performance_review_page] == "leases"
      @user_id_explanation = params[:user_id_explanation].to_i
    end
    render :layout => false
  end

  # this is to display the added files from add task add files
  def display_added_files
    if params[:from_portfolio_summary] == "true"
      add_secondary_files_in_summary
    else
      if params[:id]
        task_document_ids = (params[:recently_added_files_by_tree].split(',').collect { |id| id.to_i } ).uniq unless params[:recently_added_files_by_tree].blank?
      else
        task_document_ids = (params[:recently_added_files_by_tree].split(',').collect { |id| id.to_i } ).uniq unless params[:recently_added_files_by_tree].blank?
      end
        render :update do |page|
        page.replace_html  'all_uploaded_files_list',raw("<input type='hidden' name='all_already_upload_file' id='all_already_upload_file' value='#{params[:all_already_upload]}'/>")
        page.replace_html  'all_tree_selected_file',raw("<input type='hidden' name='all_tree_structure_file' id='all_tree_structure_file' value='#{params[:all_tree_structure]}'/>")
      end
    end
  end
end
