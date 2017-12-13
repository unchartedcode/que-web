module Que::Web::Viewmodels
  class Job < Struct.new(
    :args, :error_count, :job_class, :job_id, :last_error,
    :pg_backend_pid, :pg_last_query, :pg_last_query_started_at, :pg_state,
    :pg_state_changed_at, :pg_transaction_started_at, :pg_waiting_on_lock,
    :priority, :queue, :run_at, :data, :status)

    def initialize(job)
      members.each do |m|
        self[m] = job[m.to_s]
      end
    end

    def class_name
      if job_class == 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'
        args['job_class']
      else
        job_class
      end
    end

    def past_due?(relative_to = Time.now)
      run_at < relative_to
    end

    def data
      JSON.parse(super)
    end

    def started_at
      Time.at(data['status']['started_at'])
    end

    def completed_at
      Time.at(data['status']['completed_at'])
    end

    def duration(completed_at = nil)
      if completed_at.nil?
        completed_at = data['status'].try(:[], 'completed_at')
      end

      started_at = data['status'].try(:[], 'started_at')

      if completed_at.nil? || started_at.nil?
        return nil
      end

      completed_at - started_at
    end

    def duration_friendly(completed_at = nil)
      s = duration(completed_at)

      if s.nil?
        return ""
      end

      # d = days, h = hours, m = minutes, s = seconds
      m = (s / 60).floor
      s = s % 60
      h = (m / 60).floor
      m = m % 60
      d = (h / 24).floor
      h = h % 24

      output = "#{s} second#{s == 1 ? '' : 's'}" if (s > 0)
      output = "#{m} minute#{m == 1 ? '' : 's'}, #{s} second#{s == 1 ? '' : 's'}" if (m > 0)
      output = "#{h} hour#{h == 1 ? '' : 's'}, #{m} minute#{m == 1 ? '' : 's'}, #{s} second#{s == 1 ? '' : 's'}" if (h > 0)
      output = "#{d} day#{d == 1 ? '' : 's'}, #{h} hour#{h == 1 ? '' : 's'}, #{m} minute#{m == 1 ? '' : 's'}, #{s} second#{s == 1 ? '' : 's'}" if (d > 0)

      output
    end

    def label
      if status == 'complete'
        return 'success'
      end

      if ['error', 'dead'].include?(status)
        return 'alert'
      end

      ''
    end
  end
end
