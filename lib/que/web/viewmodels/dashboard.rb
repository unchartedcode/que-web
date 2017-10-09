module Que::Web::Viewmodels
  class Dashboard < Struct.new(:running, :scheduled, :failing, :finished)
    def initialize(stats)
      members.each do |m|
        self[m] = stats[m.to_s]
      end
    end
  end
end
