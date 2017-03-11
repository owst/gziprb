# frozen_string_literal: true
Tree = Struct.new(:l, :r) do
  def next(bit)
    bit.zero? ? l : r
  end

  def self.empty
    Tree.new(nil, nil)
  end
end
