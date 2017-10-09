module Que::Web::Viewmodels
  class Schedule < Struct.new(
    :name, :description, :args, :job_class, :expression, :enabled)

    def initialize(job)
      members.each do |m|
        self[m] = job[m.to_s]
      end
    end
  end
end
