# `"fmt" % value` (the single-value form of String#%) used to fall
# through to sp_imod, which rejected the format string as a non-int.

puts "%d" % 42
puts "%05d" % 7
puts "%.2f" % 3.14159
puts "%s!" % "hello"
