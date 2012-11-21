module ClientAdmin::AccountingHelper
def link_to_line_items(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_line_item_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")", :id => "add_line_items")
  end

  def link_to_remove_line_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(image_tag("/images/del_icon.png"), "remove_line_fields(this)")
  end

  def link_to_capital_expenditures(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_capital_expenditures_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")", :id => "add_capital_expenditures")
  end

  def link_to_remove_capital_expenditures(name, f)
    f.hidden_field(:_destroy) + link_to_function(image_tag("/images/del_icon.png"), "remove_capital_expenditures_fields(this)")
  end

end
