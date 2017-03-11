# frozen_string_literal: true
require_rel 'element'

module LZ77
  class Compress
    # Conceptually it takes at least 2 bytes to describe a length/distance pair; unless the length
    # is >= 3, it's not worth using a length/distance pair, and the literal bytes should be
    # emitted.
    MINIMUM_LENGTH = 3

    def initialize(window_size:, max_prefix_length:)
      @output_buffer = OutputBuffer.new(window_size)
      @max_prefix_length = max_prefix_length
      @input_buffer = OverwritingRingBuffer.new(max_prefix_length)
    end

    def compress(input)
      return to_enum(__method__, input) unless block_given?

      input_exhausted = false

      loop do
        begin
          @input_buffer << input.next until input_exhausted || @input_buffer.full?
        rescue StopIteration
          input_exhausted = true
        end

        break if @input_buffer.empty?

        element = next_element

        yield element

        @output_buffer.concat(@input_buffer.drop!(element[:length] || 1))
      end
    end

    def next_element
      distance, length = @output_buffer.find_longest_prefix(@input_buffer, @max_prefix_length)

      if distance && length >= MINIMUM_LENGTH
        Element.length_distance(length, distance)
      else
        Element.literal(@input_buffer[0])
      end
    end

    class OutputBuffer
      def initialize(window_size)
        @buffer = OverwritingRingBuffer.new(window_size)
        @char_count = 0
        # Maintain a hash from 3-char substrings to the char_count at their first character, used
        # to quickly find start-points for substring-matches.
        @substring_hash = {}
      end

      def length
        @buffer.length
      end

      def concat(chars)
        lookbehind = [@char_count, 2].min
        to_be_hashed = chars.dup

        # Record the position (the effective @char_count at the match start) of each 3-character
        # string slice that includes any of the added chars.
        (1..lookbehind).each { |o| to_be_hashed.unshift(@buffer[-o]) }

        to_be_hashed.each_cons(3).each_with_index do |slice, i|
          @substring_hash[slice] = [] unless @substring_hash.key?(slice)

          @substring_hash[slice].unshift(@char_count - lookbehind + i)
        end

        @buffer.concat(chars)
        @char_count += chars.size
      end

      def find_longest_prefix(needle, max_prefix_length)
        max = [-1, 0]
        buffer_length = @buffer.length
        needle_length = needle.length

        needle_start_indices(needle, buffer_length) do |i|
          # Heuristic to skip checking this index if we can't beat our max match (if no match at
          # the current max length + 1, we can't beat it)
          next if max && @buffer[i + max[1]] != needle[max[1]]

          match_len = match_length(i, needle, buffer_length, needle_length, max_prefix_length)

          if match_len > max[1]
            max = [buffer_length - i, match_len]
            # No point trying further matches if we've already found one that is the maximum size.
            break if match_len == max_prefix_length
          end
        end

        max unless max[0] == -1
      end

      private

      def match_length(i, needle, buffer_length, needle_length, max_prefix_length)
        match_len = 0

        while match_len < max_prefix_length && match_len < needle_length &&
              i < buffer_length && @buffer[i] == needle[match_len]
          match_len += 1
          i += 1
        end

        if i == buffer_length
          match_len = extend_match_into_needle(needle, match_len, max_prefix_length)
        end

        match_len
      end

      def needle_start_indices(needle, buffer_length)
        # Yield match positions that won't be found by the hash lookup (since they have length < 3
        # till the end of the buffer).
        (1..[buffer_length, 2].min).each do |i|
          yield(buffer_length - i) if @buffer[-i] == needle[0]
        end

        return unless needle.size >= 3

        chars = needle.take(3)

        all_matches = @substring_hash.fetch(chars, [])

        window_cutoff = @char_count - @buffer.max_size
        # Now remove any too-old matches from the hash-entry.
        all_matches.reject! { |i| i < window_cutoff }

        # Convert the char count at the time of match into a current index into the buffer.
        all_matches.each do |match_char_count|
          yield(buffer_length - (@char_count - match_char_count))
        end
      end

      def extend_match_into_needle(needle, match_len, max_prefix_length)
        j = 0

        needle_length = needle.length

        while match_len < max_prefix_length && match_len < needle_length &&
              needle[j] == needle[match_len]
          match_len += 1
          j += 1
        end

        match_len
      end
    end
  end
end
