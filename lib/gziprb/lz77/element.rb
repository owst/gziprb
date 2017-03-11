# frozen_string_literal: true
module LZ77
  module Element
    class << self
      def literal(value)
        { literal: value }
      end

      def length_distance(length, distance)
        { length: length, distance: distance }
      end
    end
  end
end
