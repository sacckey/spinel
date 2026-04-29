# Issue #61 stage 3: a regex literal stored in a constant must
# dispatch through the engine when used as a receiver. Before this,
# `RX = /pat/; RX.match?(s)` and `s =~ RX` fell through to the
# "0" / "(-1)" fallbacks because `find_regexp_index` only resolved
# direct `RegularExpressionNode` nodes, not `ConstantReadNode`s
# pointing at one.

RX = /[₀₁₂₃₄₅₆₇₈₉ₐₑₒₓₔ]+/

# `regex.match?(str)` — the issue's exact reproducer.
puts RX.match?("₁₂")
puts RX.match?("abc")

# `str =~ regex` via constant — operand on the right.
if "₁₂" =~ RX
  puts "lhs match"
else
  puts "lhs miss"
end

# `regex =~ str` via constant — operand on the left.
if RX =~ "₁₂"
  puts "rhs match"
else
  puts "rhs miss"
end

# `regex.match(str)` returns position-ish (truthy) on success.
m = RX.match("₁₂")
puts m ? "match ok" : "match fail"
