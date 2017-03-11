# frozen_string_literal: true
require 'spec_helper'

describe DeflateHuffman do
  let(:expected_rfc1951_codes) do
    %w(
      010
      011
      100
      101
      110
      00
      1110
      1111
    )
  end

  describe '.codes_from_code_lengths' do
    it 'is correct for the example in rfc1951' do
      expect(
        DeflateHuffman.codes_from_code_lengths([3, 3, 3, 3, 3, 2, 4, 4])
      ).to eq expected_rfc1951_codes
    end

    context 'with "0 length" codes' do
      it 'is empty if there are only 0 length codes' do
        expect(DeflateHuffman.codes_from_code_lengths([0, 0, 0])).to be_empty
      end

      it 'does not assign codes' do
        expect(DeflateHuffman.codes_from_code_lengths([2, 0, 0, 3, 3])).to eq [
          '00',
          nil,
          nil,
          '010',
          '011',
        ]
      end
    end
  end

  describe '.canonical_encoding_from_element_counts' do
    it 'is correct if there are no elements' do
      expect(DeflateHuffman.canonical_encoding_from_element_counts([[0, 0]], 1)).to be_empty
    end

    it 'is correct if there is only one element' do
      expect(DeflateHuffman.canonical_encoding_from_element_counts([['A', 1]], 1)).to eq('A' => '0')
    end

    it 'is correct for the example from http://michael.dipperstein.com/huffman/' do
      input = ([['A', 5]] + %w(B C D E).map { |c| [c, 1] }).to_h

      expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 3)).to eq(
        'E' => '111',
        'D' => '110',
        'C' => '101',
        'B' => '100',
        'A' => '0'
      )
    end

    context 'when there is no overflow' do
      it 'is correct for a small example' do
        # ((b, c), a)
        input = { 'A' => 3, 'B' => 1, 'C' => 2 }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 2)).to eq(
          'A' => '0',
          'B' => '10',
          'C' => '11'
        )
      end

      it 'is correct for a full example' do
        # (((h, g), (f, e)), ((d, c), (b, a))) i.e. leaves are reversed compared to output
        input = {
          'A' => 17,
          'B' => 16,
          'C' => 15,
          'D' => 14,
          'E' => 13,
          'F' => 12,
          'G' => 11,
          'H' => 10,
        }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 3)).to eq(
          'A' => '000',
          'B' => '001',
          'C' => '010',
          'D' => '011',
          'E' => '100',
          'F' => '101',
          'G' => '110',
          'H' => '111'
        )
      end
    end

    context 'when there is overflow' do
      it 'is correct when there is a single subtree that is too deep' do
        # (((((f, e), d), c), b), a)
        input = {
          'A' => 32,
          'B' => 16,
          'C' => 8,
          'D' => 4,
          'E' => 2,
          'F' => 1,
        }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 4)).to eq(
          'A' => '0',
          'B' => '10',
          'C' => '1100',
          'D' => '1101',
          'E' => '1110',
          'F' => '1111'
        )
      end

      it 'is correct if there are two subtrees that are too deep' do
        # (((a, (b, c)), d), (e, ((f, g), h)))
        input = {
          'B' => 10,
          'C' => 11,
          'A' => 20,
          'D' => 42,
          'F' => 12,
          'G' => 13,
          'H' => 26,
          'E' => 50,
        }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 3)).to eq(
          'A' => '000',
          'B' => '001',
          'C' => '010',
          'D' => '011',
          'E' => '100',
          'F' => '101',
          'G' => '110',
          'H' => '111'
        )
      end

      it 'is correct if not all code lengths are represented' do
        # Example that has no code of length 1 or 6, but does have codes of length 2,3,4,5,7
        input = {
          'A' => 65,
          'B' => 1,
          'C' => 6,
          'D' => 9,
          'E' => 45,
          'F' => 31,
          'G' => 14,
          'H' => 12,
          'I' => 7,
          'J' => 3,
          'K' => 2,
          'L' => 1,
          'M' => 23,
          'N' => 1,
        }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 7)).to eq(
          'A' => '00',
          'B' => '1111100',
          'C' => '11100',
          'D' => '11101',
          'E' => '01',
          'F' => '100',
          'G' => '1100',
          'H' => '1101',
          'I' => '111100',
          'J' => '111101',
          'K' => '1111101',
          'L' => '1111110',
          'M' => '101',
          'N' => '1111111'
        )
      end

      it 'is correct for a small tree' do
        # (a, ((b, c), d))
        input = { 'A' => 5, 'B' => 1, 'C' => 2, 'D' => 4 }

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 2)).to eq(
          'A' => '00',
          'B' => '01',
          'C' => '10',
          'D' => '11'
        )
      end

      it 'is correct for a larger tree' do
        # (g, (f, (e, (d, (c, (b, a))))))
        input = ('A'..'G').each_with_index.map { |c, i| [c, 2 ** i] }.to_h

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 3)).to eq(
          'G' => '00',
          'A' => '010',
          'B' => '011',
          'C' => '100',
          'D' => '101',
          'E' => '110',
          'F' => '111'
        )
      end

      it 'is correct for a long thin tree' do
        # (N, (M, (L, (K, (J, (I, (H, (G, (F, (E, (D, (C, (B, A)))))))))))))
        input = ('A'..'N').each_with_index.map { |c, i| [c, 2 ** i] }.to_h

        expect(DeflateHuffman.canonical_encoding_from_element_counts(input, 4)).to eq(
          'M' => '000',
          'N' => '001',
          'A' => '0100',
          'B' => '0101',
          'C' => '0110',
          'D' => '0111',
          'E' => '1000',
          'F' => '1001',
          'G' => '1010',
          'H' => '1011',
          'I' => '1100',
          'J' => '1101',
          'K' => '1110',
          'L' => '1111'
        )
      end
    end
  end

  describe '.generate_codes_from_count_lengths' do
    it 'is correct for a compressed version of the example in rfc1951' do
      expect(
        DeflateHuffman.generate_codes_from_count_lengths([[5, 3], [1, 2], [2, 4]])
      ).to eq expected_rfc1951_codes
    end
  end
end
