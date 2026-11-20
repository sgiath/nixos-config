-- Antigravity CLI conversations (~/.gemini/antigravity-cli and T3 Code's copy
-- under ~/.t3/userdata/providers/antigravity), from transcript_full.jsonl: one
-- line per step. A PLANNER_RESPONSE is one model response; its n tool calls
-- run as the n steps right after it (GENERIC, each starting with the
-- step's "Created At"/"Completed At" in whole seconds). Responses record no
-- stop reason or latency. The working directory and nesting come from
-- conversation_summaries. Conversation IDs are UUIDs: like every other
-- tool's session, a conversation is one session wherever it is stored. A
-- copy in another store root (the path before brain/) or on another host,
-- and a transcript rewritten as a new file (another generation), hold the
-- same steps, so each step counts once, from the copy shipped last. The
-- conversation's host, account and summary come from one origin: the copy
-- holding the most steps, then the one shipped last.

CREATE VIEW agents.antigravity_copies AS
SELECT
    extract(source, '/brain/([0-9a-f-]{36})/') AS session_id,
    host,
    extract(source, '^(.*)/brain/') AS root,
    JSONExtractUInt(record, 'step_index') AS step,
    record,
    (ingested_at, host, source, generation) AS version
FROM archive.raw
WHERE tool = 'antigravity' AND source LIKE '%/logs/transcript_full.jsonl';

CREATE VIEW agents.antigravity_origins AS
SELECT session_id, argMax((host, root), (steps, last)) AS origin
FROM
(
    SELECT session_id, host, root, uniqExact(step) AS steps, max(version) AS last
    FROM agents.antigravity_copies
    GROUP BY session_id, host, root
)
GROUP BY session_id;

CREATE VIEW agents.antigravity_lines AS
SELECT
    o.origin.1 AS host,
    o.origin.2 AS root,
    if(root LIKE '.t3/%', '.t3', '.gemini') AS account,
    s.session_id AS session_id,
    s.step AS step,
    JSONExtractString(s.line, 'type') AS type,
    parseDateTime64BestEffort(JSONExtractString(s.line, 'created_at'), 3, 'UTC') AS at,
    s.line AS record
FROM
(
    SELECT session_id, step, argMax(record, version) AS line
    FROM agents.antigravity_copies
    GROUP BY session_id, step
) AS s
INNER JOIN agents.antigravity_origins AS o ON o.session_id = s.session_id;

CREATE VIEW agents.antigravity_requests AS
WITH summaries AS
(
    SELECT host, extract(source, '^(.*)/conversation_summaries\\.db#') AS root, key AS session_id,
        argMax(record, (position, ingested_at)) AS record
    FROM archive.raw
    WHERE tool = 'antigravity' AND source LIKE '%/conversation_summaries.db#conversation_summaries'
    GROUP BY host, root, session_id
)
SELECT
    'antigravity' AS tool,
    l.host AS host,
    l.account AS account,
    l.session_id AS session_id,
    concat(l.session_id, ':', toString(l.step)) AS request_id,
    toUInt8(JSONExtractInt(s.record, 'nesting_depth') > 0) AS is_subagent,
    JSONExtractString(l.record, 'model') AS model,
    l.at AS ts,
    CAST(NULL AS Nullable(Float64)) AS duration_ms,
    CAST(NULL AS Nullable(Float64)) AS ttft_ms,
    JSONExtractUInt(l.record, 'input_tokens') AS input_tokens,
    JSONExtractUInt(l.record, 'cache_read_tokens') AS cache_read_tokens,
    toUInt64(0) AS cache_write_tokens,
    JSONExtractUInt(l.record, 'output_tokens') AS output_tokens,
    CAST(NULL AS Nullable(UInt64)) AS reasoning_tokens,
    '' AS stop_reason,
    toNullable(toUInt32(length(JSONExtractArrayRaw(l.record, 'tool_calls')))) AS tool_calls,
    decodeURLComponent(replaceOne(JSONExtractString(JSONExtractString(s.record, 'workspace_uris'), 1), 'file://', '')) AS cwd
FROM agents.antigravity_lines AS l
LEFT JOIN summaries AS s ON s.host = l.host AND s.root = l.root AND s.session_id = l.session_id
WHERE l.type = 'PLANNER_RESPONSE';

-- A call's id is its result step. A shell command that exits non-zero counts
-- as an error; the step itself still ends DONE. A result not yet DONE or
-- ERROR (RUNNING, a backgrounded command) has no outcome.
CREATE VIEW agents.antigravity_calls AS
WITH
    calls AS
    (
        SELECT
            host,
            session_id,
            step,
            step + n AS result_step,
            at,
            JSONExtractString(call, 'name') AS name,
            JSONExtractRaw(call, 'args') AS input
        FROM agents.antigravity_lines
        ARRAY JOIN
            JSONExtractArrayRaw(record, 'tool_calls') AS call,
            arrayEnumerate(JSONExtractArrayRaw(record, 'tool_calls')) AS n
        WHERE type = 'PLANNER_RESPONSE'
    ),
    results AS
    (
        SELECT
            session_id,
            step,
            JSONExtractString(record, 'status') AS status,
            JSONExtractString(record, 'content') AS content
        FROM agents.antigravity_lines
        WHERE type = 'GENERIC'
    )
SELECT
    'antigravity' AS tool,
    calls.host AS host,
    calls.session_id AS session_id,
    concat(calls.session_id, ':', toString(calls.step)) AS request_id,
    concat(calls.session_id, ':', toString(calls.result_step)) AS call_id,
    calls.name AS name,
    calls.input AS input,
    results.session_id != '' AS has_result,
    if(has_result, parseDateTime64BestEffortOrNull(extract(results.content, '^Created At: (\\S+)'), 3, 'UTC'), NULL) AS started,
    if(has_result, parseDateTime64BestEffortOrNull(extract(results.content, '\\nCompleted At: (\\S+)'), 3, 'UTC'), NULL) AS completed,
    if(has_result AND calls.name = 'run_command',
        toInt32OrNull(extract(results.content, 'Command exited with code (-?\\d+)')), NULL) AS exit_code,
    multiIf(
        results.status = 'ERROR' OR ifNull(exit_code, 0) != 0, toNullable(toUInt8(1)),
        results.status = 'DONE' AND (calls.name != 'run_command' OR exit_code IS NOT NULL), toNullable(toUInt8(0)),
        NULL) AS is_error,
    coalesce(started, calls.at) AS ts,
    toFloat64(dateDiff('millisecond', started, completed)) AS duration_ms
FROM calls
LEFT JOIN results ON results.session_id = calls.session_id AND results.step = calls.result_step;

CREATE VIEW agents.antigravity_tool_calls AS
SELECT
    tool,
    host,
    session_id,
    request_id,
    call_id,
    ts,
    name,
    input,
    is_error,
    CAST(NULL AS Nullable(UInt64)) AS output_bytes,
    duration_ms
FROM agents.antigravity_calls;

CREATE VIEW agents.antigravity_commands AS
SELECT
    tool,
    host,
    session_id,
    request_id,
    call_id,
    ts,
    JSONExtractString(input, 'CommandLine') AS command,
    exit_code,
    duration_ms
FROM agents.antigravity_calls
WHERE name = 'run_command';
