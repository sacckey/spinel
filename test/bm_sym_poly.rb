# Mixed-type array triggers poly_array; symbol elements should
# go through sp_box_sym / SP_TAG_SYM dispatch.
arr = [1, "two", :three, 4.0, true]
arr.each { |v| puts v }
