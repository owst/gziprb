# frozen_string_literal: true
module RunLengthEncoding
  def self.rle(elements)
    grouped, group = elements.reduce([[], []]) do |(runs, current_run), x|
      if current_run.empty? || current_run[0] == x
        [runs, current_run + [x]]
      else
        [runs + [current_run], [x]]
      end
    end

    group.any? ? (grouped + [group]).map { |g| [g.first, g.length] } : []
  end
end
