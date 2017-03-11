# frozen_string_literal: true
module Deflate
  module Deflate
    METHODS = %i(fixed dynamic none).freeze

    class << self
      def deflate(input, method_override = nil, &on_compressed_byte)
        return to_enum(__method__, input, method_override) unless block_given?

        if method_override && !METHODS.include?(method_override)
          raise(
            ArgumentError,
            "Unknown method #{method_override.inspect}, expected one of #{METHODS.inspect}"
          )
        end

        do_deflate(
          method_override,
          Enumerators::BufferedEnumerator.new(input),
          DeflateOutputBuffer.new(&on_compressed_byte)
        )
      end

      private

      def do_deflate(method_override, buffered_input_enumerator, output_buffer)
        block_builder = BlockBuilder.new(method_override, buffered_input_enumerator, output_buffer)
        lz77 =
          LZ77::Compress.new(window_size: LZ77_WINDOW_SIZE, max_prefix_length: LZ77_MAXIMUM_LENGTH)

        Enumerators::CountingCrc32Enumerator.yield_enumerator_and_return_summary(
          buffered_input_enumerator.enumerator
        ) do |counting_crc_enumerator|
          lz77_element_enumerator = lz77.compress(counting_crc_enumerator)

          loop do # Loop until the lz77_element_enumerator raises StopIteration.
            element = lz77_element_enumerator.next
            block_builder.emit(input_exhausted: false) if block_builder.emit_before_tally?(element)
            block_builder.tally(element)
          end

          block_builder.emit(input_exhausted: true)

          output_buffer.finalize
        end
      end
    end
  end
end
