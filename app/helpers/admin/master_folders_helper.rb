module Admin::MasterFoldersHelper

  def breadcrumb_display_admin(folder)
    arr =[]
    i = 0
    while !folder.nil?
      if folder.parent_id==0 || !folder.parent_id?
        #tmp_name =  "<a href='#' class='bluecolor'><font color='#1F75CC'>#{folder.name}</font></a>"
        tmp_name =  "<font color='#1F75CC'>#{folder.name}</font>"
      else
        #tmp_name = "<a href='#' onclick='#' class='bluecolor'><font color='#1F75CC'>#{folder.name}</font></a>"
        tmp_name = "<font color='#1F75CC'>#{folder.name}</font>"
      end
      name = (i == 0) ? "<font color='#222222'><img alt='' class='sprite s_folder link-img' src='/images/icon_spacer.gif'> #{folder.name}</font>" :  "#{tmp_name}"
      arr << name
      folder =  MasterFolder.find_by_id(folder.parent_id)
      i += 1
    end
    return raw(arr.reverse.join(" <img src='/images/right_arrow.gif' /> "))
  end

end