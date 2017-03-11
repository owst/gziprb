# frozen_string_literal: true
require 'spec_helper'
require 'lz77_spec_helpers'

describe LZ77::Compress do
  include LZ77SpecHelpers

  describe '#compress' do
    let(:window_size) { 100 }
    let(:max_prefix_length) { 50 }

    subject { LZ77::Compress.new(window_size: window_size, max_prefix_length: max_prefix_length) }

    def compress(input)
      compress_to_a(subject, input)
    end

    it 'handles empty input' do
      expect(compress('')).to be_empty
    end

    it 'correctly compresses' do
      expect(compress('abcdabcdXXXXX')).to eq to_elements('a', 'b', 'c', 'd', [4, 4], 'X', [4, 1])
    end

    it 'handles simple repetitions of the same character' do
      expect(compress('aaaaaa')).to eq to_elements('a', [5, 1])
    end

    it 'handles repetitions of several characters' do
      expect(compress('abcabcd')).to eq to_elements('a', 'b', 'c', [3, 3], 'd')
    end

    it 'handles alternating characters' do
      expect(compress('ababa')).to eq to_elements('a', 'b', [3, 2])
    end

    it 'handles partial repetitions of several characters' do
      expect(compress('ababac')).to eq to_elements('a', 'b', [3, 2], 'c')
    end

    it 'handles multiple repetitions of several characters' do
      expect(compress('abababc')).to eq to_elements('a', 'b', [4, 2], 'c')
    end

    it 'handles multiple repetitions of several characters' do
      expect(compress('abababcababcccc')).to eq to_elements('a', 'b', [4, 2], 'c', [5, 5], [3, 1])
    end

    context 'with a small window_size' do
      let(:window_size) { 2 }

      it 'does not look further back than window size' do
        expect(compress('aabbaac')).to eq to_elements('a', 'a', 'b', 'b', 'a', 'a', 'c')
      end
    end

    context 'with a small max_prefix_length' do
      let(:max_prefix_length) { 3 }

      it 'only matches prefixes up to that length' do
        expect(compress('aaaaaaaa')).to eq to_elements('a', [3, 1], [3, 1], 'a')
      end
    end

    context 'when the block breaks early' do
      # Prevent too much input being read to fill the buffer.
      let(:max_prefix_length) { 3 }

      it 'only consumes as much decompressed input as is necessary' do
        input = Enumerator.new do |yielder|
          [1, 2, 3, 1, 2, 3, :to_prevent_the_peek_failing].each do |i|
            yielder << i
          end

          raise 'should not be reached'
        end

        yielded = []

        subject.compress(input.each) do |out|
          yielded << out
          break if yielded.length == 4
        end

        expect(yielded).to eq [lz77_lit(1), lz77_lit(2), lz77_lit(3), lz77_len_dist(3, 3)]
      end
    end

    it 'can search for repeatitions across invocations of compress' do
      output = []
      subject.compress([1, 2, 3, 4].each) { |out| output << out }
      subject.compress([1, 2, 3, 4].each) { |out| output << out }

      expect(output).to eq [
        lz77_lit(1),
        lz77_lit(2),
        lz77_lit(3),
        lz77_lit(4),
        lz77_len_dist(4, 4),
      ]
    end
  end

  describe '#find_longest_prefix' do
    def find_longest_prefix(haystack, needle)
      buffer = LZ77::Compress::OutputBuffer.new(100)
      buffer.concat(haystack.chars)
      buffer.find_longest_prefix(needle.chars, 10)
    end

    it 'is null if needle is not present in haystack' do
      expect(find_longest_prefix("\0\0c", 'd')).to be_nil
    end

    it 'is correct if haystack starts with some of needle' do
      expect(find_longest_prefix('abcdef', 'abc')).to eq([6, 3])
    end

    it 'is correct if haystack ends with some of needle' do
      expect(find_longest_prefix('defabc', 'abc')).to eq([3, 3])
    end

    it 'is correct if haystack contains some of needle' do
      expect(find_longest_prefix('xxxabcyyy', 'abc')).to eq([6, 3])
    end

    it 'is correct if haystack has one character more than the needle' do
      expect(find_longest_prefix('aaac', 'aaa')).to eq([4, 3])
    end

    it 'is correct if haystack contains some of needle' do
      expect(find_longest_prefix('aabc', 'abc')).to eq([3, 3])
    end

    it 'is correct if needle is a repetition of haystack' do
      expect(find_longest_prefix('a', 'aaaa')).to eq([1, 4])
    end

    it 'is correct if haystack extends into needle' do
      expect(find_longest_prefix('ab', 'ababa')).to eq([2, 5])
      expect(find_longest_prefix('ab', 'abcaba')).to eq([2, 2])
      expect(find_longest_prefix('ab', 'abacba')).to eq([2, 3])
      expect(find_longest_prefix('aba', 'aaaaaa')).to eq([1, 6])
      expect(find_longest_prefix('abcd', 'abcdabcd')).to eq([4, 8])
    end

    it 'is limited to the maximum prefix size' do
      buffer = LZ77::Compress::OutputBuffer.new(20)
      buffer.concat(['a'])
      expect(buffer.find_longest_prefix('aaaa', 2)).to eq([1, 2])
    end

    it 'is correct if haystack contains needle multiple times' do
      expect(find_longest_prefix('abcababd', 'abab')).to eq([5, 4])
    end

    it 'is correct if haystack contains needle multiple times, longest extending into needle' do
      expect(find_longest_prefix('abcab', 'ababab')).to eq([2, 6])
    end
  end
end
