class GcSaveDoubleInNew
  def initialize(path)
    data = [1, 2, 3]
    @x = data
  end

  def step
    @x.length
  end
end

o = GcSaveDoubleInNew.new("a")
puts o.step
