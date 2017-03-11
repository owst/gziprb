# frozen_string_literal: true
module LZ77SpecHelpers
  def lz77_lit(elem)
    LZ77::Element.literal(elem)
  end

  def lz77_len_dist(l, d)
    LZ77::Element.length_distance(l, d)
  end

  def to_elements(*stream)
    stream.map do |elem|
      if elem.is_a?(Array)
        lz77_len_dist(*elem)
      else
        lz77_lit(elem)
      end
    end
  end

  def compress_to_a(compressor, input)
    compressor.compress(StringIO.new(input).each_char).to_a
  end

  def decompress_to_string(decompressor, input)
    decompressor.decompress(input).to_a.join
  end
end
