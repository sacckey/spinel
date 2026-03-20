# Test safe navigation operator &.

s = "hello"
puts s&.length    # 5
puts s&.upcase    # HELLO

arr = Array.new
arr.push(10)
arr.push(20)
puts arr&.length  # 2

# Chain
puts "world"&.upcase&.length  # 5

puts "done"
