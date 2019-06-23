class RegdocDefine
  attr_reader :name, :value
  attr_accessor :documentation

  def initialize(name, value)
    @name = name
    @value = value
    @documentation = []
  end
end
