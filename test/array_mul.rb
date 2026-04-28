# Array#* (repeat). Works uniformly across every typed array kind
# is_array_type() recognises (int / float / str / sym / poly).

# IntArray
ints = [1, 2, 3] * 3
puts ints.length      # 9
puts ints[0]          # 1
puts ints[3]          # 1
puts ints[8]          # 3

# IntArray * 0 → empty
empty = [1, 2, 3] * 0
puts empty.length     # 0

# IntArray * 1 → copy (independent of source)
arr = [1, 2]
copy = arr * 1
arr.push(99)
puts copy.length      # 2

# FloatArray
floats = [1.5, 2.5] * 2
puts floats.length    # 4
puts floats[0]        # 1.5
puts floats[3]        # 2.5

# StrArray
strs = ["a", "b"] * 3
puts strs.length      # 6
puts strs[0]          # a
puts strs[5]          # b

# SymArray
syms = [:x, :y] * 2
puts syms.length      # 4
puts syms[0]          # x
puts syms[3]          # y

# PolyArray (mixed types)
mixed = [1, "two", 3.0] * 2
puts mixed.length     # 6

# Pre-fill an array
zeros = [0] * 5
puts zeros.length     # 5
puts zeros[0]         # 0
puts zeros[4]         # 0

puts "done"
