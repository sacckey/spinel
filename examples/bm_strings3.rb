# Test additional string methods

# ljust / rjust / center
puts "hi".ljust(10)         # "hi        "
puts "hi".rjust(10)         # "        hi"
puts "hi".center(10)        # "    hi    "
puts "hi".ljust(10, "*")    # "hi********"
puts "hi".rjust(10, "0")    # "00000000hi"

# lstrip / rstrip
puts "  hello  ".lstrip     # "hello  "
puts "  hello  ".rstrip     # "  hello"

# tr / delete / squeeze
puts "hello".tr("el", "ip")      # "hippo"
puts "hello world".delete("lo")  # "he wrd"
puts "aaabbbccc".squeeze          # "abc"

# chars / bytes
puts "abc".chars.length     # 3
puts "abc".bytes.length     # 3

# to_f
puts ("3.14".to_f * 100).to_i  # 314

# slice
puts "hello"[1..3]          # "ell"
puts "hello"[0, 2]          # "he"

# hex / oct
puts "ff".hex    # 255
puts "77".oct    # 63

# dup / freeze / frozen?
s = "hello"
puts s.dup       # "hello"
puts s.freeze    # "hello"
puts s.frozen?   # true

# to_s
puts "test".to_s  # "test"

puts "done"
