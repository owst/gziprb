# frozen_string_literal: true
require 'spec_helper'
require 'lz77_spec_helpers'

describe LZ77::Decompress do
  include LZ77SpecHelpers

  let(:window_size) { 100 }
  let(:max_prefix_length) { 50 }

  subject { LZ77::Decompress.new(window_size: window_size, max_prefix_length: max_prefix_length) }

  def decompress(input)
    decompress_to_string(subject, input)
  end

  describe '#decompress' do
    it 'correctly decompresses' do
      expect(decompress(to_elements('a', 'b', [2, 2], 'd'))).to eq 'ababd'
    end

    context 'if an invalid distance is passed in' do
      let(:window_size) { 3 }

      it 'raises if it is bigger than window_size' do
        expect {
          decompress(to_elements('a', 'b', 'c', 'd', [1, 4], 'b'))
        }.to raise_error(/distance 4 > window_size: 3/)
      end

      it 'raises if a distance is bigger than output produced so far' do
        expect {
          decompress(to_elements([1, 3], 'a'))
        }.to raise_error(/distance 3 > output length produced so far/)
      end
    end

    context 'if an invalid length is passed in' do
      let(:max_prefix_length) { 2 }

      it 'raises if a length is bigger than max_prefix_length' do
        expect {
          decompress(to_elements('a', 'b', 'c', [3, 1], 'd'))
        }.to raise_error(/length 3 is bigger than max_prefix_length 2/)
      end
    end

    context 'when the block breaks early' do
      it 'only consumes as much compressed input as is necessary' do
        input = Enumerator.new do |yielder|
          yielder << lz77_lit(1)
          yielder << lz77_lit(2)
          yielder << lz77_len_dist(1, 2)
          raise 'should not be reached'
        end

        yielded = []

        subject.decompress(input.each) do |out|
          yielded << out
          break if yielded.length == 3
        end

        expect(yielded).to eq [1, 2, 1]
      end
    end

    it 'handles repetitions less than the lookbehind' do
      expect(decompress(to_elements('a', 'b', [1, 2], 'c'))).to eq 'abac'
    end

    it 'handles repetitions more than the lookbehind' do
      expect(decompress(to_elements('a', 'b', [5, 2], 'c'))).to eq 'abababac'
    end

    it 'can handle length/distance across invokations of compress' do
      output = []
      subject.decompress([lz77_lit(1), lz77_lit(2), lz77_lit(3)].each) { |out| output << out }
      subject.decompress([lz77_len_dist(3, 3)].each) { |out| output << out }

      expect(output).to eq [1, 2, 3, 1, 2, 3]
    end
  end
end
