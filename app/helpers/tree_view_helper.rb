module TreeViewHelper
 def find_move_to_folder_members
    @members  = SharedFolder.find(:all,:conditions=>["folder_id = ?",@moved_folder.id])
 end

def update_page_from_move_to
  responds_to_parent do
      render :update do |page|
        page.call 'close_control_model'
        update_partials(page)
        if(params[:action] == "move_folder" && !(current_user.has_role?("Shared User") && session[:role] == 'Shared User'))
          page << "jQuery('#'+#{@portfolio_old}+'_li').removeClass('activeimagecol').addClass('deactiveimagecol'); jQuery('#'+#{@portfolio_old}+'_li').css('cursor', 'pointer');jQuery('#'+#{@moved_portfolio_old}+'_li').removeClass('deactiveimagecol').addClass('activeimagecol');"
        end
        page.call "flash_writter", "#{@msg}"
      end
    end
end

def remove_sharing_for_sub_folders_and_docs(folder_id, loop_starts)
    folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
    @folder_s = [ ] if (@folder_s.nil? || @folder_s.empty? || loop_starts)
    @doc_s = [ ] if (@doc_s.nil? || @doc_s.empty? || loop_starts)
    @doc_names = [ ] if (@doc_names.nil? || @doc_names.empty? || loop_starts)
    folders.each do |f|
      remove_sharing_for_sub_folders_and_docs(f.id, false)
      shared_folders = f.shared_folders.collect{|s| s if s.user_id != current_user.id}
      unless shared_folders.empty? || shared_folders == [nil]
        f.shared_folders.collect{|sf| sf.destroy if sf != nil}
      end
      @folder_s << f
    documents = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted=false",folder_id])
    documents.each do |d|
      sd = d.shared_documents.destroy_all
      @doc_s << sd if sd != nil
    end
  end
end
end
