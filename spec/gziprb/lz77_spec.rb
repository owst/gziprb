# frozen_string_literal: true
require 'spec_helper'
require 'lz77_spec_helpers'
require 'stringio'

describe LZ77 do
  include LZ77SpecHelpers

  let(:max_prefix_length) { 100 }
  let(:window_size) { 200 }

  let(:constructor_args) { { window_size: window_size, max_prefix_length: max_prefix_length } }

  let(:decompressor) { LZ77::Decompress.new(**constructor_args) }
  let(:compressor) { LZ77::Compress.new(**constructor_args) }

  def decompress(input)
    decompress_to_string(decompressor, input)
  end

  def compress(input)
    compress_to_a(compressor, input)
  end

  shared_examples 'compress/decompress correctly' do
    it 'decompresses correctly' do
      expect(decompress(compressed)).to eq decompressed
    end

    it 'compresses correctly' do
      expect(compress(decompressed)).to eq compressed
    end

    it 'decompress . compress == id' do
      expect(decompress(compress(decompressed))).to eq decompressed
    end

    it 'compress . decompress == id' do
      expect(compress(decompress(compressed))).to eq compressed
    end
  end

  context 'a simple example' do
    let(:compressed) { to_elements('a', 'a', 'b', [3, 2], 'c', [4, 1], 'd') }
    let(:decompressed) { 'aababacccccd' }

    include_examples 'compress/decompress correctly'
  end

  context 'example from http://bit.ly/290IzZs' do
    let(:compressed) { to_elements('B', 'l', 'a', 'h', ' ', 'b', [18, 5], '!') }
    let(:decompressed) { 'Blah blah blah blah blah!' }

    include_examples 'compress/decompress correctly'
  end

  context 'example from https://en.wikipedia.org/wiki/LZ77_and_LZ78#Example' do
    let(:compressed) { to_elements('a', 'a', 'c', [4, 3], 'b', [3, 3], 'a', [3, 9]) }
    let(:decompressed) { 'aacaacabcabaaac' }

    include_examples 'compress/decompress correctly'
  end

  context 'a large example' do
    let(:max_prefix_length) { 30 }
    let(:window_size) { 2**16 }
    let(:decompressed_size) { window_size * 4 }

    context 'with multiple repeated substrings' do
      let(:decompressed) do
        s = ''.dup

        chars = ('a'..'z').to_a
        i = 0

        decompressed_size.times do
          s << chars[i]
          i += 1
          i = 0 if i == chars.size
        end

        s
      end

      it 'decompress . compress == id' do
        expect(decompress(compress(decompressed))).to eq decompressed
      end
    end

    context 'with a single repeated character' do
      let(:decompressed) { 'A' * decompressed_size }

      it 'decompress . compress == id' do
        expect(decompress(compress(decompressed))).to eq decompressed
      end
    end

    context 'with a random input' do
      seed = Random.rand(0..2**16)
      random = Random.new(seed)

      context "with seed #{seed}" do
        let(:decompressed) { random_bytearray(random, decompressed_size).join }

        it 'decompress . compress == id' do
          expect(decompress(compress(decompressed))).to eq decompressed
        end
      end
    end
  end
end
