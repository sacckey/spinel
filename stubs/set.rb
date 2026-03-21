# Spinel stub: set
#
# Minimal Set implementation using Array.
# Only supports basic operations needed by lrama.
# Note: In Spinel, Set operations are approximated with Array.

class Set
  def initialize(arr)
    @data = arr
    @name = "set"
  end
end
