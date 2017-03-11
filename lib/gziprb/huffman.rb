# frozen_string_literal: true
module Huffman
  module TreeBuilder
    class << self
      # Creates a Tree from a mapping of literal to codes. Does not check for uniqueness of either
      # codes or literals.
      def from_encoding(encoding)
        Tree.empty.tap do |tree|
          encoding.each do |lit, code|
            insert_code(tree, code, lit)
          end
        end
      end

      private

      def insert_code(tree, code, lit)
        return lit if code.empty?

        bit = code.slice!(0).to_i

        if bit.zero?
          tree.l = insert_code(tree.l || Tree.empty, code, lit)
        else
          tree.r = insert_code(tree.r || Tree.empty, code, lit)
        end

        tree
      end
    end
  end

  class Decompressor
    def self.decompress_single_literal(tree, input_buffer)
      tree = tree.next(input_buffer.read_bit) while tree.is_a?(Tree)

      tree
    end
  end
end
