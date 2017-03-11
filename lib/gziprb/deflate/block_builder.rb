# frozen_string_literal: true
require 'ostruct'

module Deflate
  class BlockBuilder
    MAX_STORED_BLOCK_SIZE = (2 ** 16) - 1

    MAX_CODE_LENGTH_CODE_LENGTH = 7
    MAX_LENLIT_OR_DIST_CODE_LENGTH = 15

    def initialize(method_override, input_buffer_enumerator, output_buffer)
      @method_override = method_override
      @input_buffer_enumerator = input_buffer_enumerator
      @output_buffer = output_buffer
      @distance_writer = DISTANCE_WRITER.new
      @length_writer = LENGTH_WRITER.new

      reinitialize
    end

    def tally(element)
      @elements << element
      @byte_count += byte_count_for(element)

      if element.key?(:literal)
        @len_lit_counts[element.fetch(:literal)] += 1
      else
        @len_lit_counts[@length_writer.to_code(element.fetch(:length))] += 1
        @dist_counts[@distance_writer.to_code(element.fetch(:distance))] += 1
      end
    end

    # If we tally this element, it would make the current block's size too large, so we need to
    # emit the block first.
    def emit_before_tally?(element)
      @byte_count + byte_count_for(element) > MAX_STORED_BLOCK_SIZE
    end

    def emit(input_exhausted:)
      @output_buffer.push_bit(input_exhausted ? LAST_BLOCK_BIT : NON_LAST_BLOCK_BIT)

      encoding_data = dynamic_encoding_data

      case most_efficient_encoding_method(encoding_data)
      when :fixed
        output_fixed_block
      when :dynamic
        output_dynamic_block(encoding_data)
      else
        output_stored_block
      end

      reinitialize
    end

    private

    def byte_count_for(element)
      if element.key?(:literal)
        1
      else
        element.fetch(:length)
      end
    end

    def most_efficient_encoding_method(dynamic_encoding_data)
      return @method_override if @method_override

      bit_counts = Hash.new(0)
      bit_counts[:none] = 32 + @byte_count * 8

      write_elements_using_huffman_encodings(
        ::Deflate.fixed_len_lit_encoding,
        ::Deflate.fixed_dist_encoding,
        ->(bit_string) { bit_counts[:fixed] += bit_string.size },
        ->(nbits, _) { bit_counts[:fixed] += nbits }
      )

      bit_counts[:dynamic] = count_dynamic_block_bit_length(dynamic_encoding_data)

      bit_counts.min_by { |_k, v| v }.first
    end

    def count_dynamic_block_bit_length(dynamic_encoding_data)
      # 5 bits for the len/lit code lengths and the dist code lengths and 4 for the number of code
      # length code lengths.
      count = 14

      count += dynamic_encoding_data.code_length_code_lengths.size * 3

      code_counter = ->(bit_string) { count += bit_string.size }
      number_counter = ->(nbits, _) { count += nbits }

      write_code_length_codes(dynamic_encoding_data, code_counter, number_counter)

      write_elements_using_huffman_encodings(
        dynamic_encoding_data.len_lit_encoding,
        dynamic_encoding_data.dist_encoding,
        code_counter,
        number_counter
      )

      count
    end

    def reinitialize
      @byte_count = 0
      @elements = []

      # From the spec:
      # A code length of 0 indicates that the corresponding symbol in the literal/length or
      # distance alphabet will not occur in the block, and should not participate in the Huffman
      # code construction algorithm given earlier. If only one distance code is used, it is
      # encoded using one bit, not zero bits; in this case there is a single code length of one,
      # with one unused code.
      @len_lit_counts = Hash.new(0)
      # Unless using a stored block, we emit the STOP_CODE once, so make sure that it will be
      # assigned a Huffman code.
      @len_lit_counts[STOP_CODE] = 1

      @dist_counts = Hash.new(0)
      # One distance code of zero bits means that there are no distance codes used at all (the
      # data is all literals).
      @dist_counts[0] = 0
    end

    def output_stored_block
      @output_buffer.push_bit_string(NO_COMPRESSION, first_bit: :lsb)
      @output_buffer.zero_pad_current_byte

      [@byte_count, ~@byte_count].each { |x| @output_buffer.push_raw_bytes([x].pack('v').bytes) }

      @output_buffer.push_raw_bytes(@input_buffer_enumerator.buffer.slice!(0, @byte_count))
    end

    def output_fixed_block
      @output_buffer.push_bit_string(FIXED_HUFFMAN_COMPRESSION, first_bit: :lsb)

      write_elements_using_huffman_encodings(
        ::Deflate.fixed_len_lit_encoding,
        ::Deflate.fixed_dist_encoding,
        method(:output_code),
        method(:output_number)
      )

      @input_buffer_enumerator.buffer.slice!(0, @byte_count)
    end

    def output_dynamic_block(dynamic_encoding_data)
      @output_buffer.push_bit_string(DYNAMIC_HUFFMAN_COMPRESSION, first_bit: :lsb)

      output_number(5, @len_lit_counts.size - 257)
      output_number(5, @dist_counts.size - 1)
      output_number(4, dynamic_encoding_data.code_length_code_lengths.size - 4)

      dynamic_encoding_data.code_length_code_lengths.each { |count| output_number(3, count) }

      write_code_length_codes(dynamic_encoding_data, method(:output_code), method(:output_number))

      write_elements_using_huffman_encodings(
        dynamic_encoding_data.len_lit_encoding,
        dynamic_encoding_data.dist_encoding,
        method(:output_code),
        method(:output_number)
      )

      @input_buffer_enumerator.buffer.slice!(0, @byte_count)
    end

    def dynamic_encoding_data
      len_lit_encoding, dist_encoding = build_dynamic_encodings

      code_length_codes = DynamicHuffmanCodeLengthWriter.codes_and_extra_values_from_length_runs(
        code_length_runs(len_lit_encoding, dist_encoding)
      )

      code_length_encoding = build_code_length_encoding(code_length_codes.map(&:first))
      code_length_code_lengths = build_code_length_code_lengths(code_length_encoding)

      OpenStruct.new(
        code_length_code_lengths: code_length_code_lengths,
        code_length_encoding: code_length_encoding,
        code_length_codes: code_length_codes,
        len_lit_encoding: len_lit_encoding,
        dist_encoding: dist_encoding
      ).freeze
    end

    def build_dynamic_encodings
      zero_each_unset_value_below_max_key(@len_lit_counts)
      zero_each_unset_value_below_max_key(@dist_counts)

      [@len_lit_counts, @dist_counts].map do |cs|
        DeflateHuffman.canonical_encoding_from_element_counts(cs, MAX_LENLIT_OR_DIST_CODE_LENGTH)
      end
    end

    def code_length_runs(len_lit_encoding, dist_encoding)
      len_lit_code_lengths = code_lengths_for_counts(@len_lit_counts, len_lit_encoding)
      dist_code_lengths = code_lengths_for_counts(@dist_counts, dist_encoding)

      RunLengthEncoding.rle(len_lit_code_lengths + dist_code_lengths)
    end

    def build_code_length_encoding(code_lengths)
      DeflateHuffman.canonical_encoding_from_element_counts(
        element_counts(code_lengths),
        MAX_CODE_LENGTH_CODE_LENGTH
      )
    end

    def build_code_length_code_lengths(code_length_encoding)
      code_length_code_lengths = DYNAMIC_TREE_CODE_LENGTH_CODE_LENGTH_INDICES.map do |index|
        (code_length_encoding[index] || '').length.tap do |r|
          raise "Invalid code length: #{r}" unless r.between?(0, MAX_CODE_LENGTH_CODE_LENGTH)
        end
      end

      code_length_code_lengths.reverse.drop_while(&:zero?).reverse
    end

    def element_counts(elements)
      elements.group_by(&:itself).map { |elem, group| [elem, group.size] }.to_h
    end

    def code_lengths_for_counts(counts, encoding)
      counts.sort_by(&:first).map do |value, count|
        (count.positive? ? encoding.fetch(value).length : 0).tap do |l|
          unless l.between?(0, MAX_LENLIT_OR_DIST_CODE_LENGTH)
            raise "Invalid code length: #{l} for value #{value}"
          end
        end
      end
    end

    def zero_each_unset_value_below_max_key(hash)
      (0..hash.keys.max).each do |i|
        hash[i] = 0 unless hash.key?(i)
      end
    end

    def write_elements_using_huffman_encodings(len_lit_encoding, dist_encoding, on_code, on_number)
      @elements.each do |element|
        if element.key?(:length)
          length, distance = element.values_at(:length, :distance)
          @length_writer.write(length, len_lit_encoding, on_code, on_number)
          @distance_writer.write(distance, dist_encoding, on_code, on_number)
        else
          on_code.call(len_lit_encoding.fetch(element.fetch(:literal)))
        end
      end

      on_code.call(len_lit_encoding.fetch(STOP_CODE))
    end

    def write_code_length_codes(dynamic_encoding_data, on_code, on_number)
      dynamic_encoding_data.code_length_codes.each do |code, count|
        DynamicHuffmanCodeLengthWriter.write(
          code,
          count,
          dynamic_encoding_data.code_length_encoding,
          on_code,
          on_number
        )
      end
    end

    def output_code(code)
      @output_buffer.push_bit_string(code, first_bit: :msb)
    end

    def output_number(nbits, value)
      @output_buffer.push_bit_string(format("%0#{nbits}b", value), first_bit: :lsb)
    end
  end
end
