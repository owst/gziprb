# frozen_string_literal: true
module Deflate
  class Inflate
    class << self
      def inflate(input, &on_inflated_byte)
        return to_enum(__method__, input) unless block_given?

        # Pass each inflated byte throught the count/crc32 enumerator.
        Enumerators::CountingCrc32Enumerator.yield_enumerator_and_return_summary(
          inflated_bytes_enumerator(InflateInputBuffer.new(input))
        ) do |counting_crc_enumerator|
          counting_crc_enumerator.each(&on_inflated_byte)
        end
      end

      def inflated_bytes_enumerator(input_buffer)
        # The lz77 window can cross blocks, allowing repeat references to cross block boundaries.
        lz77 = LZ77::Decompress.new(
          window_size: LZ77_WINDOW_SIZE,
          max_prefix_length: LZ77_MAXIMUM_LENGTH
        )

        Enumerator.new do |yielder|
          loop do
            last_block = input_buffer.read_bit == LAST_BLOCK_BIT

            inflate_block(input_buffer.read_bit_string(2), lz77, input_buffer, yielder.method(:<<))

            break if last_block
          end
        end
      end

      private

      # Dispatch to the correct inflation method, depending on the compression method bits.
      def inflate_block(compression_method_bits, lz77, input_buffer, yield_byte)
        case compression_method_bits
        when RESERVED
          raise 'Should not encounter RESERVED block!'
        when NO_COMPRESSION
          inflate_stored_block(lz77, input_buffer, yield_byte)
        when FIXED_HUFFMAN_COMPRESSION
          inflate_fixed_huffman_block(lz77, input_buffer, yield_byte)
        when DYNAMIC_HUFFMAN_COMPRESSION
          inflate_dynamic_huffman_block(lz77, input_buffer, yield_byte)
        end
      end

      def inflate_stored_block(lz77, input_buffer, yield_byte)
        input_buffer.read_to_end_of_current_byte

        size, ones_complement_size = Array.new(2) do
          input_buffer.read_raw_bytes(2).to_a.pack('C*').unpack('v').first
        end

        unless size == ((~ones_complement_size) & 0xFFFF)
          raise ArgumentError, "Corrupt size: #{size} #{ones_complement_size}"
        end

        input_buffer.read_raw_bytes(size) do |byte|
          # We must pass the bytes through the lz77 decompressor as length/distances in later
          # blocks are allowed to refer to previous blocks.
          lz77.decompress([LZ77::Element.literal(byte)], &yield_byte)
        end
      end

      def inflate_fixed_huffman_block(lz77, input_buffer, yield_byte)
        inflate_huffman_block(
          lz77,
          input_buffer,
          ::Deflate.fixed_len_lit_tree,
          ::Deflate.fixed_dist_tree,
          yield_byte
        )
      end

      def inflate_dynamic_huffman_block(lz77, input_buffer, yield_byte)
        num_len_lit = input_buffer.read_number(5) + 257
        num_dist = input_buffer.read_number(5) + 1

        code_lengths = read_dynamic_block_code_lengths(
          input_buffer,
          input_buffer.read_number(4) + 4,
          num_len_lit + num_dist
        )

        inflate_huffman_block(
          lz77,
          input_buffer,
          huffman_tree_from_code_lengths(code_lengths.take(num_len_lit)),
          huffman_tree_from_code_lengths(code_lengths.drop(num_len_lit)),
          yield_byte
        )
      end

      def inflate_huffman_block(lz77, input_buffer, len_lit_tree, dist_tree, yield_byte)
        lz77.decompress(
          lz77_element_enumerator(input_buffer, len_lit_tree, dist_tree),
          &yield_byte
        )
      end

      def lz77_element_enumerator(input_buffer, len_lit_tree, dist_tree)
        read_number = input_buffer.method(:read_number)
        dist_reader = DISTANCE_READER.new(read_number)
        length_reader = LENGTH_READER.new(read_number)

        Enumerator.new do |yielder|
          loop do
            code = Huffman::Decompressor.decompress_single_literal(len_lit_tree, input_buffer)

            break if code == STOP_CODE

            element = if code < STOP_CODE
                        LZ77::Element.literal(code)
                      else
                        length = length_reader.next(code)
                        distance = dist_reader.next(
                          Huffman::Decompressor.decompress_single_literal(dist_tree, input_buffer)
                        )

                        LZ77::Element.length_distance(length, distance)
                      end

            yielder << element
          end
        end
      end

      def read_dynamic_block_code_lengths(input_buffer,
                                          code_length_code_lengths_count,
                                          code_length_count)
        code_length_code_lengths = [0] * 19

        # As per the spec, unspecified code length code lengths are assumed to be 0. We may read
        # fewer than 19 code_length code_lengths, thus leaving them as initialised, as 0. The
        # ordering of lengths is intented to lead to shorter sequences being sent, as common
        # lengths are sent first, and the remaining unused lengths are simply left unspecified.
        Array.new(code_length_code_lengths_count) do |index_index|
          index = DYNAMIC_TREE_CODE_LENGTH_CODE_LENGTH_INDICES[index_index]

          code_length_code_lengths[index] = input_buffer.read_number(3)
        end

        code_length_tree = huffman_tree_from_code_lengths(code_length_code_lengths)

        code_length_reader = DynamicHuffmanCodeLengthReader.new(
          -> { Huffman::Decompressor.decompress_single_literal(code_length_tree, input_buffer) },
          input_buffer.method(:read_number)
        )

        [].tap do |code_lengths|
          until code_lengths.size == code_length_count
            code_lengths.concat(code_length_reader.next_code_lengths)
          end
        end
      end

      def huffman_tree_from_code_lengths(code_lengths)
        Huffman::TreeBuilder.from_encoding(
          ::Deflate.huffman_encoding_for_codes(
            DeflateHuffman.codes_from_code_lengths(code_lengths)
          )
        )
      end
    end
  end
end
