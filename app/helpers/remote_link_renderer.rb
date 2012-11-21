class RemoteLinkRenderer < WillPaginate::ViewHelpers::LinkRenderer

  def link(text, target, attributes = {})
    if target.is_a? Fixnum
      attributes[:rel] = rel_value(target)
      target = url(target)
    end
    attributes["data-remote"] = "true"
    attributes[:href] = target
    tag(:a, text, attributes)
  end

    #~ protected

    #~ def page_number(page)
      #~ unless page == current_page
        #~ tag(:div, link(page, page, :rel => rel_value(page)),:class => "numbercol")
      #~ else
        #~ tag(:div, page, :class => "current",:class => "numbercol")
      #~ end
    #~ end

    #~ def previous_or_next_page(page, text, classname)
      #~ if page
        #~ if classname == "previous_page"
          #~ tag(:div, link(text, page), :class => "#{classname} numbercol")
        #~ elsif classname == "next_page"
           #~ tag(:div, link(text, page), :class => "#{classname} pagenext")
        #~ end
      #~ else
          #~ if classname == "previous_page"
            #~ tag(:div, text, :class => "#{classname} + ' disabled' numbercol")
          #~ elsif classname == "next_page"
             #~ tag(:div, text, :class => "#{classname} + ' disabled' pagenext")
          #~ end
      #~ end
    #~ end

    #~ def html_container(html)
      #~ tag(:div, html, container_attributes)
    #~ end
  end

