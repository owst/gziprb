# frozen_string_literal: true
require_rel 'deflate'

module Deflate
  NON_LAST_BLOCK_BIT = 0
  LAST_BLOCK_BIT = 1

  COMPRESSION_TYPES = [
    NO_COMPRESSION = '00',
    FIXED_HUFFMAN_COMPRESSION = '01',
    DYNAMIC_HUFFMAN_COMPRESSION = '10',
    RESERVED = '11',
  ].freeze

  STOP_CODE = 256

  LZ77_WINDOW_SIZE = 2 ** 15
  LZ77_MAXIMUM_LENGTH = 258

  DYNAMIC_TREE_CODE_LENGTH_CODE_LENGTH_INDICES =
    [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15].freeze
  FIXED_HUFFMAN_COUNT_LENGTHS = [[144, 8], [112, 9], [24, 7], [8, 8]].freeze

  class << self
    # Distance codes 0-31 are represented by (fixed-length) 5-bit codes, with possible additional
    # bits as shown in the table shown in Paragraph 3.2.5, above. Note that distance codes 30-31
    # will never actually occur in the compressed data.
    def fixed_dist_encoding
      encoding_for_code_count_lengths([[32, 5]])
    end

    def fixed_dist_tree
      Huffman::TreeBuilder.from_encoding(fixed_dist_encoding)
    end

    def fixed_len_lit_encoding
      encoding_for_code_count_lengths(FIXED_HUFFMAN_COUNT_LENGTHS)
    end

    def fixed_len_lit_tree
      Huffman::TreeBuilder.from_encoding(fixed_len_lit_encoding)
    end

    def encoding_for_code_count_lengths(count_lengths)
      huffman_encoding_for_codes(DeflateHuffman.generate_codes_from_count_lengths(count_lengths))
    end

    def huffman_encoding_for_codes(codes)
      # Zero length codes are ignored (and replaced with a nil code), so remove them from the
      # output. N.B. we need to preserve the correct position of the non-nil elements so can't
      # remove the nil elements before the each_with_index.
      codes.each_with_index.reject { |e, _| e.nil? }.map(&:reverse).to_h
    end

    private

    # Create a pair of classes that encapsulate reading/writing lengths and distances; a reader
    # takes a base code, and optionally reads extra bits to add to a corresponding base value, a
    # writer takes a value and converts it into a code and optional extra bits.
    def define_code_reader_and_writer(bases:, extra_bits:, code_range:, value_range:)
      extra_bits.freeze
      bases.freeze

      args = {
        bases: bases,
        extra_bits: extra_bits,
        code_range: code_range,
      }

      [define_code_reader(**args), define_code_writer(**args, value_range: value_range)]
    end

    def define_code_reader(bases:, extra_bits:, code_range:)
      Struct.new(:number_reader) do
        define_method(:next) do |code|
          raise "Unexpected code #{code} in #{self.class}" unless code_range.include?(code)

          index = code - code_range.min
          bits_to_read = extra_bits[index]

          bases[index] + (bits_to_read.positive? ? number_reader.call(bits_to_read) : 0)
        end
      end
    end

    def define_code_writer(bases:, extra_bits:, code_range:, value_range:)
      Class.new do
        define_method(:to_code) do |value|
          raise "Unexpected value #{value} in #{self.class}" unless value_range.include?(value)

          _, _, index = last_entry_with_base_less_or_equal_to(value)

          index + code_range.min
        end

        define_method(:write) do |value, huffman_encoding, on_code, output_number|
          on_code.call(huffman_encoding.fetch(to_code(value)))
          base, extra, _index = last_entry_with_base_less_or_equal_to(value)
          output_number.call(extra, value - base) if extra.positive?
        end

        private

        define_method(:last_entry_with_base_less_or_equal_to) do |value|
          @reversed_entries ||= bases.zip(extra_bits).each_with_index.to_a.map(&:flatten).reverse

          @reversed_entries.bsearch { |(base, _, _)| base <= value }
        end
      end
    end
  end

  REPEAT_PREVIOUS_CODE_LENGTH = 16
  ZEROS_CODE_LENGTH_3_TO_10 = 17
  ZEROS_CODE_LENGTH_11_TO_138 = 18

  # Length codes and extra bits.
  #
  #         Extra               Extra               Extra
  #     Code Bits Length(s) Code Bits Lengths   Code Bits Length(s)
  #     ---- ---- ------     ---- ---- -------   ---- ---- -------
  #      257   0     3       267   1   15,16     277   4   67-82
  #      258   0     4       268   1   17,18     278   4   83-98
  #      259   0     5       269   2   19-22     279   4   99-114
  #      260   0     6       270   2   23-26     280   4  115-130
  #      261   0     7       271   2   27-30     281   5  131-162
  #      262   0     8       272   2   31-34     282   5  163-194
  #      263   0     9       273   3   35-42     283   5  195-226
  #      264   0    10       274   3   43-50     284   5  227-257
  #      265   1  11,12      275   3   51-58     285   0    258
  #      266   1  13,14      276   3   59-66
  LENGTH_READER, LENGTH_WRITER = define_code_reader_and_writer(
    bases: [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99,
            115, 131, 163, 195, 227, 258],
    extra_bits: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
                 5, 0],
    code_range: (257..285),
    value_range: (3..258)
  )

  # Distance codes and extra bits
  #
  #      Extra           Extra               Extra
  #  Code Bits Dist  Code Bits   Dist     Code Bits Distance
  #  ---- ---- ----  ---- ----  ------    ---- ---- --------
  #    0   0    1     10   4     33-48    20    9   1025-1536
  #    1   0    2     11   4     49-64    21    9   1537-2048
  #    2   0    3     12   5     65-96    22   10   2049-3072
  #    3   0    4     13   5     97-128   23   10   3073-4096
  #    4   1   5,6    14   6    129-192   24   11   4097-6144
  #    5   1   7,8    15   6    193-256   25   11   6145-8192
  #    6   2   9-12   16   7    257-384   26   12  8193-12288
  #    7   2  13-16   17   7    385-512   27   12 12289-16384
  #    8   3  17-24   18   8    513-768   28   13 16385-24576
  #    9   3  25-32   19   8   769-1024   29   13 24577-32768
  DISTANCE_READER, DISTANCE_WRITER = define_code_reader_and_writer(
    bases: [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025,
            1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577],
    extra_bits: [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11,
                 11, 12, 12, 13, 13],
    code_range: (0..29),
    value_range: (1..32768)
  )

  # 0 - 15: Represent code lengths of 0 - 15
  # 16: Copy the previous code length 3 - 6 times.
  #     The next 2 bits indicate repeat length
  #           (0 = 3, ... , 3 = 6)
  #        Example:  Codes 8, 16 (+2 bits 11),
  #                  16 (+2 bits 10) will expand to
  #                  12 code lengths of 8 (1 + 6 + 5)
  # 17: Repeat a code length of 0 for 3 - 10 times.
  #     (3 bits of length)
  # 18: Repeat a code length of 0 for 11 - 138 times
  #     (7 bits of length)
  class DynamicHuffmanCodeLengthWriter
    class << self
      def write(value, count, huffman_encoding, on_code, output_number)
        on_code.call(huffman_encoding.fetch(value))

        return if value < 16

        bits, offset = case value
                       when 16
                         [2, 3]
                       when 17
                         [3, 3]
                       when 18
                         [7, 11]
                       end

        output_number.call(bits, count - offset)
      end

      def codes_and_extra_values_from_length_runs(runs)
        to_codes_and_extra_values_from_groups(to_groups_from_runs(runs))
      end

      private

      def to_codes_and_extra_values_from_groups(code_length_groups)
        code_length_groups.flat_map do |value, count|
          if count == 1
            [[value, nil]]
          elsif value.zero?
            if count <= 10
              [[17, count]]
            else
              [[18, count]]
            end
          else
            [[value, nil], [16, count - 1]]
          end
        end
      end

      # Breaks runs of elements into groups that are valid by the above encoding. We break up
      # large groups into smaller groups, and too-small groups into single element groups.
      def to_groups_from_runs(runs)
        runs.flat_map do |value, count|
          min, max = value.zero? ? [3, 138] : [4, 6]

          [].tap do |groups|
            while count > max
              groups << [value, max]
              count -= max
            end

            if count < min
              count.times { groups << [value, 1] }
            else
              groups << [value, count]
            end
          end
        end
      end
    end
  end

  class DynamicHuffmanCodeLengthReader
    def initialize(code_length_code_reader, number_reader)
      @code_length_code_reader = code_length_code_reader
      @number_reader = number_reader

      @previous_code_length = nil
    end

    def next_code_lengths
      read_next_code_lengths.tap do |code_lengths|
        @previous_code_length = code_lengths.last
      end
    end

    private

    def read_next_code_lengths
      code_length = @code_length_code_reader.call

      if code_length.between?(0, 15)
        [code_length]
      elsif code_length == REPEAT_PREVIOUS_CODE_LENGTH
        raise 'No previous code_length to repeat!' unless @previous_code_length

        repeat(@previous_code_length, bits: 2, offset: 3)
      elsif code_length == ZEROS_CODE_LENGTH_3_TO_10
        repeat(0, bits: 3, offset: 3)
      elsif code_length == ZEROS_CODE_LENGTH_11_TO_138
        repeat(0, bits: 7, offset: 11)
      end
    end

    def repeat(what, bits:, offset:)
      Array.new(@number_reader.call(bits) + offset, what)
    end
  end
end
