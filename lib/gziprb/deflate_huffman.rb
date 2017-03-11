# frozen_string_literal: true
require 'pqueue'

module DeflateHuffman
  class << self
    def generate_codes_from_count_lengths(count_lengths)
      code_lengths = count_lengths.flat_map { |count, length| Array.new(count, length) }

      codes_from_code_lengths(code_lengths)
    end

    def codes_from_code_lengths(code_lengths)
      # Zero length "codes" are treated specially in the deflate spec as that code not being used,
      # rather than a zero-length code.
      length_counts = count_lengths(code_lengths).reject { |c, _| c.zero? }

      return [] if length_counts.empty?

      next_codes = generate_next_codes(length_counts)

      code_lengths.map do |code_length|
        code = next_codes[code_length]

        next unless code

        next_codes[code_length] += 1

        format("%0#{code_length}b", code)
      end
    end

    # Bit length tree codes are limited to 7 bits since their lengths are stored as 3 bit ints.
    # Len/lit and distance codes are limited to 15 bits since their length is stored using the
    # code-length alphabet, where 15 is the maximum code length as the lookbehind window is 2**15
    # in size, in the worst case, we could require 15 bits for the distance. 16, 17, 18 are used
    # for RLE.
    def canonical_encoding_from_element_counts(element_counts, max_code_length)
      if element_counts.size > 2 ** max_code_length
        raise "Too many elements (#{element_counts.size}) for max_code_length #{max_code_length}"
      end

      non_canonical_encoding = encoding_from_element_counts(element_counts)

      if non_canonical_encoding.empty?
        {}
      else
        # Lexicographical sort making elements with shorter codes appear first and elements with
        # equal-length codes appear in element order.
        code_lens, elems = non_canonical_encoding.map { |e, code| [code.length, e] }.sort.transpose

        overflows = non_canonical_encoding.values.select { |code| code.length > max_code_length }

        unless overflows.empty?
          code_lens, elems = handle_overflowing_codes(max_code_length, code_lens, elems, overflows)
        end

        elems.zip(codes_from_code_lengths(code_lens)).to_h
      end
    end

    private

    def handle_overflowing_codes(max_code_length, code_lens, elems, overflows)
      length_counts = count_lengths(code_lens).reject { |l, _| l > max_code_length }
      (1..max_code_length).each { |i| length_counts[i] = 0 unless length_counts.key?(i) }
      num_overflows = overflows.size

      # For each overflowing subtree, we can immediately add a leaf at that subtree's root. E.g.
      # in (a, (b, (c, d))) with a max depth of 2, we have 2 overflow leaves (c and d, with depth
      # 3) and can add a leaf in place of their subtree. In ((((a, b), c), d), (e, (f, (g, h)))))
      # and max length of 3 we add leaves in place of subtrees (a, b), and (g, h)
      num_empty_leaves = overflows.map { |c| c[0, max_code_length] }.uniq.size
      length_counts[max_code_length] += num_empty_leaves
      num_overflows -= num_empty_leaves

      # Next, we make room in the tree for the `num_overflows` leaves. We do this by repeatedly
      # moving leaves "down" the tree (i.e. lengthening their code by 1), which makes space for 1
      # new leaf, e.g. (a, (b, c)) => ((a, _), (b, c))
      num_overflows.times do |i|
        # Find the first non-leaf level that has nodes that we can move down.
        i = max_code_length - 1
        i -= 1 until length_counts[i].positive?

        length_counts[i] -= 1
        length_counts[i + 1] += 2
      end

      # We must lexicograpically sort again as code-lengths have changed.
      to_lengths(length_counts).zip(elems).sort.transpose
    end

    def to_lengths(length_counts)
      (1..length_counts.keys.max).flat_map do |length|
        Array.new(length_counts.fetch(length, 0), length)
      end
    end

    PQElem = Struct.new(:elem, :count, :max_depth) do
      # Least count then least depth (to minimise tree depth) is highest priority
      def <(other)
        count < other.count || count == other.count && max_depth <= other.max_depth
      end
    end

    def encoding_from_element_counts(element_counts)
      element_counts = element_counts.reject { |_, count| count.zero? }

      elems = element_counts.to_a.map { |elem, count| PQElem.new(elem, count, 1) }

      if elems.empty?
        {}
      elsif elems.size == 1
        { elems.first.elem => '0' }
      else
        tree_to_encoding(build_tree_from_queue(elems))
      end
    end

    def build_tree_from_queue(elems)
      pq = PQueue.new(elems) { |l, r| l < r }

      while pq.size > 1
        l = pq.pop
        r = pq.pop

        new_tree = Tree.new(l.elem, r.elem)

        pq.push(PQElem.new(new_tree, l.count + r.count, [l, r].map(&:max_depth).max + 1))
      end

      pq.pop.elem
    end

    def tree_to_encoding(tree, prefix = '')
      if tree.is_a?(Tree)
        tree_to_encoding(tree.l, prefix + '0').merge(tree_to_encoding(tree.r, prefix + '1'))
      else
        { tree => prefix }
      end
    end

    def generate_next_codes(length_counts)
      (1..length_counts.keys.max).reduce([{}, 0]) { |(next_codes, code), length|
        code = (code + length_counts.fetch(length - 1, 0)) << 1
        next_codes[length] = code

        [next_codes, code]
      }.first
    end

    def count_lengths(code_lengths)
      code_lengths.each_with_object(Hash.new(0)) do |code_length, length_counts|
        length_counts[code_length] += 1
      end
    end
  end
end
