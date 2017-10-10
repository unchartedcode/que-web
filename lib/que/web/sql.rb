Que::Web::SQL = {
  dashboard_stats: <<-SQL.freeze,
    SELECT count(*)                    AS total,
           count(locks.job_id)         AS running,
           coalesce(sum((error_count > 0 AND locks.job_id IS NULL)::int), 0) AS failing,
           coalesce(sum((error_count = 0 AND locks.job_id IS NULL)::int), 0) AS scheduled,
           ( select count(*) from que_history ) as finished,
           ( select count(*) from que_scheduler ) as schedules
    FROM que_jobs
    LEFT JOIN (
      SELECT (classid::bigint << 32) + objid::bigint AS job_id
      FROM pg_locks
      WHERE locktype = 'advisory'
    ) locks USING (job_id)
    WHERE
      job_class ILIKE ($1)
  SQL
  failing_jobs: <<-SQL.freeze,
    SELECT que_jobs.*
    FROM que_jobs
    LEFT JOIN (
      SELECT (classid::bigint << 32) + objid::bigint AS job_id
      FROM pg_locks
      WHERE locktype = 'advisory'
    ) locks USING (job_id)
    WHERE locks.job_id IS NULL AND error_count > 0 AND job_class ILIKE ($3)
    ORDER BY run_at
    LIMIT $1::int
    OFFSET $2::int
  SQL
  scheduled_jobs: <<-SQL.freeze,
    SELECT que_jobs.*
    FROM que_jobs
    LEFT JOIN (
      SELECT (classid::bigint << 32) + objid::bigint AS job_id
      FROM pg_locks
      WHERE locktype = 'advisory'
    ) locks USING (job_id)
    WHERE locks.job_id IS NULL AND error_count = 0 AND job_class ILIKE ($3)
    ORDER BY run_at
    LIMIT $1::int
    OFFSET $2::int
  SQL
  delete_job: <<-SQL.freeze,
    DELETE
    FROM que_jobs
    WHERE job_id = $1::bigint
    AND pg_try_advisory_lock($1::bigint)
    RETURNING job_id
  SQL
  reschedule_job: <<-SQL.freeze,
    UPDATE que_jobs
    SET run_at = $2::timestamptz
    WHERE job_id = $1::bigint
    AND pg_try_advisory_lock($1::bigint)
    RETURNING job_id
  SQL
  reschedule_scheduled_job: <<-SQL.freeze,
    WITH upsert AS (
      UPDATE que_jobs
      SET run_at = $2::timestamptz
      WHERE data->'scheduler'->>'name' = $1::text
      AND pg_try_advisory_lock(que_jobs.job_id)
      RETURNING job_id
    )
    INSERT INTO que_jobs (queue, priority, run_at, job_class, args, data)
    SELECT '' as queue
         , 100 as priority
         , $2::timestamptz as run_at
         , que_scheduler.job_class
         , que_scheduler.args
         , jsonb_build_object('scheduler', jsonb_build_object('name', que_scheduler.name))
    FROM que_scheduler
    WHERE name = $1
    AND NOT EXISTS (SELECT * FROM upsert)
    RETURNING job_id
  SQL
  fetch_job: <<-SQL.freeze,
    SELECT *
    FROM que_jobs
    WHERE job_id = $1::bigint
    LIMIT 1
  SQL
  finished_jobs: <<-SQL.freeze,
    SELECT que_history.*
    FROM que_history
    WHERE job_class ILIKE ($3)
    ORDER BY run_at DESC
    LIMIT $1::int
    OFFSET $2::int
  SQL
  fetch_finished_job: <<-SQL.freeze,
    SELECT *
    FROM que_history
    WHERE job_id = $1::bigint
    LIMIT 1
  SQL
  reschedule_finished_job: <<-SQL.freeze,
    INSERT INTO que_jobs (queue, priority, run_at, job_class, args, data)
    SELECT queue, priority, $2::timestamptz, job_class, args, data
    FROM que_history
    WHERE job_id = $1::bigint
    RETURNING job_id
  SQL
  schedules: <<-SQL.freeze,
    SELECT que_scheduler.*
    FROM que_scheduler
    WHERE job_class ILIKE ($3) or name ILIKE ($3)
    ORDER BY name
    LIMIT $1::int
    OFFSET $2::int
  SQL
  fetch_schedule: <<-SQL.freeze,
    SELECT *
    FROM que_scheduler
    WHERE name = $1::text
    LIMIT 1
  SQL
  modify_schedule: <<-SQL.freeze,
    UPDATE que_scheduler
    SET enabled = $2::boolean
    WHERE name = $1::text
    RETURNING name
  SQL
}.freeze
