# Test Array#sort, reduce, min, max, sum

arr = (1..10).to_a
arr.reverse!

# sort
sorted = arr.sort
puts sorted.first  # 1
puts sorted.last   # 10

# min/max/sum
puts arr.min   # 1
puts arr.max   # 10
puts arr.sum   # 55

# reduce
puts arr.reduce(0) { |sum, x| sum + x }   # 55
puts arr.reduce(1) { |prod, x| prod * x } # 3628800

# inject (alias)
puts arr.inject(0) { |s, x| s + x }  # 55
