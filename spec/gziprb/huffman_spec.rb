# frozen_string_literal: true
require 'spec_helper'

module Huffman
  describe Huffman::TreeBuilder do
    describe '.from_encoding' do
      it 'is correct when there are no codes' do
        expect(Huffman::TreeBuilder.from_encoding({})).to eq Tree.empty
      end

      it 'is correct when there are codes' do
        expect(
          Huffman::TreeBuilder.from_encoding(
            a: '00'.dup,
            b: '01'.dup,
            c: '100'.dup,
            d: '101'.dup
          )
        ).to eq Tree.new(Tree.new(:a, :b), Tree.new(Tree.new(:c, :d), nil))
      end
    end
  end

  describe Decompressor do
    describe '.decompress_single' do
      let(:tree) { Tree.new(Tree.new('a', 'b'), 'c') }

      def input_buffer(code)
        Object.new.tap do |o|
          o.define_singleton_method(:eof?) do
            code.empty?
          end

          o.define_singleton_method(:read_bit) do
            code.slice!(0).to_i
          end
        end
      end

      {
        '00' => 'a',
        '01' => 'b',
        '1' => 'c',
      }.each do |code, expected|
        it "decompresses #{code} correctly" do
          expect(
            Huffman::Decompressor.decompress_single_literal(tree, input_buffer(code.dup))
          ).to eq(expected)
        end
      end
    end
  end
end
