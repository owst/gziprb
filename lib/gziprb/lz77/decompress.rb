# frozen_string_literal: true
module LZ77
  class Decompress
    class InvalidCompressedStream < StandardError; end

    def initialize(window_size:, max_prefix_length:)
      @output_buffer = OverwritingRingBuffer.new(window_size)
      @max_prefix_length = max_prefix_length
    end

    def decompress(input)
      return to_enum(__method__, input) unless block_given?

      buffer_and_yield = ->(elem) do
        @output_buffer << elem
        yield elem
      end

      input.map do |compressed_element|
        if compressed_element.key?(:length)
          distance = compressed_element.fetch(:distance)
          length = compressed_element.fetch(:length)

          raise_if_invalid_stream(distance, length)

          @output_buffer.last(distance).cycle.take(length).each(&buffer_and_yield)
        else
          buffer_and_yield.call(compressed_element.fetch(:literal))
        end
      end
    end

    private

    def raise_if_invalid_stream(distance, length)
      err = if distance > @output_buffer.max_size
              "distance #{distance} > window_size: #{@output_buffer.max_size}"
            elsif distance > @output_buffer.length
              "distance #{distance} > output length produced so far: #{@output_buffer.length}"
            elsif length > @max_prefix_length
              "length #{length} is bigger than max_prefix_length #{@max_prefix_length}"
            end

      raise InvalidCompressedStream, err if err
    end
  end
end
