# frozen_string_literal: true
require 'spec_helper'
require 'set'
require 'date'

describe Deflate do
  def bytes_to_utf8(bytes)
    bytes.pack('C*').force_encoding(Encoding::UTF_8)
  end

  def inflate_to_utf8(input)
    bytes_to_utf8(Deflate::Inflate.inflate(input).to_a)
  end

  def compress(compression_method, input)
    Deflate::Deflate.deflate(StringIO.new(input).each_byte, compression_method).to_a
  end

  describe 'Deflate#deflate/Inflate#inflate' do
    (Deflate::Deflate::METHODS + [nil]).each do |compression_method|
      context "with compression method #{compression_method.inspect}" do
        it 'is an inverse for an empty string' do
          input = ''

          compressed = compress(compression_method, input)
          expect(inflate_to_utf8(StringIO.new(compressed.pack('C*')))).to eq input
        end

        it 'is an inverse for a simple string' do
          input = 'Blah blah blah blah blah!'

          compressed = compress(compression_method, input)
          expect(inflate_to_utf8(StringIO.new(compressed.pack('C*')))).to eq input
        end

        it 'is an inverse for a simple short block with no repetitions' do
          input = bytes_to_utf8((1..10).to_a)

          compressed = compress(compression_method, input)
          expect(inflate_to_utf8(StringIO.new(compressed.pack('C*')))).to eq input
        end

        let(:max_byte_count) { Deflate::BlockBuilder::MAX_STORED_BLOCK_SIZE }

        it 'is an inverse for a simple single block of the maximum size' do
          input = ('a'..'z').to_a.lazy.cycle.take(max_byte_count).force.join

          compressed = compress(compression_method, input)
          expect(inflate_to_utf8(StringIO.new(compressed.pack('C*')))).to eq input
        end

        context 'for a random block of maximum size' do
          seed = Random.rand(0..2**16)

          context "with seed #{seed}" do
            it 'is an inverse' do
              random = Random.new(seed)

              input = random_bytearray(random, max_byte_count).join.force_encoding(Encoding::UTF_8)

              compressed = compress(compression_method, input)
              roundtripped = inflate_to_utf8(StringIO.new(compressed.pack('C*')))
              expect(roundtripped).to eq(input), "wrong random block inverse using seed #{seed}"
            end
          end
        end

        it 'is an inverse for two simple blocks' do
          input = ('a'..'z').to_a.lazy.cycle.take(max_byte_count * 2).force.join

          compressed = compress(compression_method, input)

          expect(inflate_to_utf8(StringIO.new(compressed.pack('C*')))).to eq input
        end
      end
    end
  end

  describe 'Deflate.deflate' do
    it 'should compress a simple example well with fixed compression method' do
      expect(compress(:fixed, 'X' * 100).size).to eq 5
    end
  end

  describe 'Inflate.inflate' do
    it 'inflates a simple example' do
      expect(inflate_to_utf8(StringIO.new("\x4b\x4c\x4c\x4c\xe4\x2\x0"))).to eq "aaaa\n"
    end

    it 'inflates multiple simple stored (uncompressed) blocks' do
      input = [
        0b11111000,
        0x03, 0x00,
        0xFC, 0xFF,
        65, 66, 67,
        0b11111001,
        0x02, 0x00,
        0xFD, 0xFF,
        68, 69
      ]

      expect(inflate_to_utf8(StringIO.new(input.pack('C*')))).to eq 'ABCDE'
    end

    it 'inflates a simple fixed-compression block' do
      input = [
        0b01110011,
        0b01110100,
        0b01110010,
        0b00000110,
        0b00100010,
        0,
      ]

      expect(inflate_to_utf8(StringIO.new(input.pack('C*')))).to eq 'ABCABC'
    end

    it 'inflates a simple fixed-compression block followed by a stored block' do
      input = [
        0b01110010,
        0b01110100,
        0b01110010,
        0b00000110,
        0b00100010,
        0b00000000,
        0b11111100,
        0x03, 0x00,
        0xFC, 0xFF,
        65, 66, 67,
        0b11111001,
        0x02, 0x00,
        0xFD, 0xFF,
        68, 69
      ]

      expect(inflate_to_utf8(StringIO.new(input.pack('C*')))).to eq 'ABCABCABCDE'
    end

    it 'inflates a stored block followed by a fixed block with reference into the stored block' do
      input = [
        0b11111000,
        0x03, 0x00,
        0xFC, 0xFF,
        65, 66, 67,
        0b00000011,
        0b00100001,
        0x0
      ]

      expect(inflate_to_utf8(StringIO.new(input.pack('C*')))).to eq 'ABCABCA'
    end

    it 'inflates a simple dynamic-compression block with literals and length/distance elements' do
      input = [
        0b01100101,
        0b11000000,
        0b10000001,
        0b00000000,
        0b00000000,
        0b00000000,
        0b00000000,
        0b11000011,
        0b00100000,
        0b11010110,
        0b11111100,
        0b00100101,
        0b00001110,
        0b10110000,
        0b00010000,
        0b00000011,
      ]

      expect(inflate_to_utf8(StringIO.new(input.pack('C*')))).to eq('a' * 20)
    end

    context 'test cases from gzip' do
      def expect_inflate_to_utf8_with_trailing_newline(input, expected)
        expect(inflate_to_utf8(StringIO.new(input))).to eq(expected + "\n")
      end

      # These examples were generated in a slightly hacky way, that assumed that the gzip header
      # was a fixed number of bytes (due to no optional fields).
      # We compress with gzip, remove 10 leading bytes (i.e. start at byte 11), remove 8 trailing
      # bytes and transform into a string literal to use in Ruby:
      #   $INPUT | gzip | tail -c +11 | head -c -8 > output_file

      # INPUT=$(yes 'should compress very well' | head -n 25)
      it 'inflates text that should compress very well' do
        input = read_fixture('deflate_example1')
        expected = (['should compress very well'] * 25).join("\n")

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(yes xxxxxx121212xxxx12121A | head -n 10)
      it 'inflates some repeated example text' do
        input = read_fixture('deflate_example2')
        expected = (['xxxxxx121212xxxx12121A'] * 10).join("\n")

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e "puts ('a'..'z').cycle.lazy.with_index(1).map(&:*).take(100).to_a.join")
      # Looks like
      # abbcccdddd...
      it 'inflates text with increasing repeated sequences' do
        input = read_fixture('deflate_example3')
        expected = ('a'..'z').cycle.lazy.with_index(1).map(&:*).take(100).to_a.join

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e "p ('a'..'z').cycle.lazy.with_index(1).map(&:*).take(100).to_a.join")
      # Looks like
      # "abbcccdddd..."
      it 'inflates quoted text with increasing repeated sequences' do
        input = read_fixture('deflate_example4')

        expected = %("#{('a'..'z').cycle.lazy.with_index(1).map(&:*).take(100).to_a.join}")

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e "puts %w(0 1).cycle.lazy.with_index(1).map(&:*).take(100).to_a.join")
      # Looks like
      # 0110001111...
      it 'inflates text with increasing repeated simple sequences' do
        input = read_fixture('deflate_example5')
        expected = %w(0 1).cycle.lazy.with_index(1).map(&:*).take(100).to_a.join

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e 'require "date";
      # puts (Date.new(2016, 1, 1)..Date.new(2016, 12, 31)) \
      #   .select { |d| d.monday? } \
      #   .map { |d| d.strftime("%A %d %B %Y") } \
      #   .join')
      # Looks like
      # Monday 04 January 2016Monday 11 January 2016Monday 18 January 2016Monday 25 January 2016...
      it 'inflates each Monday in 2016' do
        input = read_fixture('deflate_example6')
        expected = (Date.new(2016, 1, 1)..Date.new(2016, 12, 31)).select(&:monday?).map { |d|
          d.strftime('%A %d %B %Y')
        }.join

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e "s = ('a'..'z').map { |c| c * 50 }.join; puts s + s.reverse")
      # Looks like
      # aaaaabbbbbcccccddddd...
      it 'inflates a repeated alphabet' do
        input = read_fixture('deflate_example7')

        s = ('a'..'z').map { |c| c * 50 }.join

        expect_inflate_to_utf8_with_trailing_newline(input, s + s.reverse)
      end

      # INPUT='the quick brown fox jumped over the lazy dog'
      it 'inflates the quick brown fox' do
        input = read_fixture('deflate_example8')
        expected = 'the quick brown fox jumped over the lazy dog'

        expect_inflate_to_utf8_with_trailing_newline(input, expected)
      end

      # INPUT=$(ruby -e 'puts (0..255).to_a.pack("C*")')
      # Looks like
      # \x00\x01\x02\x03...\xff
      it 'inflates 0..255' do
        input = read_fixture('deflate_example9')
        expect_inflate_to_utf8_with_trailing_newline(input, bytes_to_utf8((0..255).to_a))
      end
    end
  end

  describe Deflate::DynamicHuffmanCodeLengthReader do
    (0..15).each do |code|
      context "for code #{code}" do
        it 'is returns a single code' do
          code_length_reader = Deflate::DynamicHuffmanCodeLengthReader.new(
            -> { code },
            proc { raise 'should not be called!' }
          )

          expect(code_length_reader.next_code_lengths).to eq [code]
        end
      end
    end

    context 'for code 16' do
      it 'raises if no previous code' do
        code_length_reader = Deflate::DynamicHuffmanCodeLengthReader.new(
          -> { 16 },
          proc { raise 'should not be called!' }
        )

        expect { code_length_reader.next_code_lengths }.to raise_error(/No previous/)
      end

      (0..3).each do |length|
        it "correctly repeats the previous code having read 2 bits for length #{length}" do
          been_called = false

          code_length_reader = Deflate::DynamicHuffmanCodeLengthReader.new(
            -> { (been_called ? 16 : 10).tap { been_called = true } },
            expected_length_proc(length, 2)
          )

          expect(code_length_reader.next_code_lengths).to eq [10]

          code_lengths = code_length_reader.next_code_lengths
          expect(code_lengths.uniq).to eq [10]
          expect(code_lengths.size).to eq(3 + length)
        end
      end
    end

    def expected_length_proc(length, expected_length_bits)
      ->(n) { n == expected_length_bits ? length : (raise "expected #{expected_length_bits}") }
    end

    def expect_repeated_zeros(code, length, expected_length_bits, size_base)
      code_length_reader = Deflate::DynamicHuffmanCodeLengthReader.new(
        -> { code },
        expected_length_proc(length, expected_length_bits)
      )

      code_lengths = code_length_reader.next_code_lengths
      expect(code_lengths.uniq).to eq [0]
      expect(code_lengths.size).to eq(size_base + length)
    end

    (0..7).each do |length|
      context "for code 17 and length #{length}" do
        it 'returns the correct number of zeros having read 3 bits of length' do
          expect_repeated_zeros(17, length, 3, 3)
        end
      end
    end

    (0..255).each do |length|
      context "for code 18 and length #{length}" do
        it 'returns the correct number of zeros having read 7 bits of length' do
          expect_repeated_zeros(18, length, 7, 11)
        end
      end
    end
  end

  context 'Code readers' do
    def expect_code_read(klass, code, num_bits, result)
      number_reader = ->(n) do
        expect(n).to eq(num_bits)
        0
      end

      expect(klass.new(number_reader).next(code)).to eq result
    end

    describe Deflate::LENGTH_READER do
      it 'raises if the code is outside 257-285' do
        [256, 286].each do |bad_code|
          expect {
            Deflate::LENGTH_READER.new(nil).next(bad_code)
          }.to raise_error(/Unexpected code/)
        end
      end

      it 'is correct for a sample of inputs' do
        [
          [257, 0, 3],
          [264, 0, 10],
          [265, 1, 11],
          [268, 1, 17],
          [269, 2, 19],
          [272, 2, 31],
          [273, 3, 35],
          [276, 3, 59],
          [277, 4, 67],
          [280, 4, 115],
          [281, 5, 131],
          [284, 5, 227],
          [285, 0, 258],
        ].each do |args|
          expect_code_read(Deflate::LENGTH_READER, *args)
        end
      end
    end

    describe Deflate::DISTANCE_READER do
      it 'raises if the code is outside 0-29' do
        [-1, 30].each do |bad_code|
          expect {
            Deflate::DISTANCE_READER.new(nil).next(bad_code)
          }.to raise_error(/Unexpected code/)
        end
      end

      it 'is correct for a sample of inputs' do
        [
          [0, 0, 1],
          [3, 0, 4],
          [4, 1, 5],
          [5, 1, 7],
          [6, 2, 9],
          [7, 2, 13],
          [8, 3, 17],
          [9, 3, 25],
          [10, 4, 33],
          [11, 4, 49],
          [11, 4, 49],
          [12, 5, 65],
          [13, 5, 97],
          [14, 6, 129],
          [15, 6, 193],
          [16, 7, 257],
          [17, 7, 385],
          [18, 8, 513],
          [19, 8, 769],
          [20, 9, 1025],
          [21, 9, 1537],
          [22, 10, 2049],
          [23, 10, 3073],
          [24, 11, 4097],
          [25, 11, 6145],
          [26, 12, 8193],
          [27, 12, 12289],
          [28, 13, 16385],
          [29, 13, 24577],
        ].each do |args|
          expect_code_read(Deflate::DISTANCE_READER, *args)
        end
      end
    end
  end
end
