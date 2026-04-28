# Array#+ on a ptr_array used to fall through; the result temp held its
# default 0 because the dispatcher's type-list omitted ptr_array.

class Bar
  def initialize(x); @x = x; end
  attr_accessor :x
end

a = [Bar.new(1)]
b = [Bar.new(2)]
puts (a + b).length
