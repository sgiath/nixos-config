-- OpenCode sessions lost from opencode.db, recovered from oh-my-opencode's
-- hook copy in ~/.claude/transcripts (tool 'opencode-hooks', one ses_*.jsonl
-- per session: typed prompts, tool calls and their results).
--
-- OpenCode's database was replaced between 2026-06-21 and 06-23; every
-- session before that survives only here. The copy has no models, usage or
-- assistant text, so these sessions add tool calls, commands and prompt counts
-- but no requests. Sessions still in opencode.db are skipped. Results repeat
-- their call's input, so a call is paired with the next result of the same
-- tool and input in its session.

CREATE VIEW agents.opencode_hook_lines AS
SELECT
    host,
    extract(source, '(ses_[A-Za-z0-9]+)\\.jsonl$') AS session_id,
    toUInt64(key) AS line,
    JSONExtractString(record, 'type') AS type,
    parseDateTime64BestEffort(JSONExtractString(record, 'timestamp'), 3, 'UTC') AS at,
    JSONExtractString(record, 'tool_name') AS name,
    JSONExtractRaw(record, 'tool_input') AS input,
    record
FROM archive.raw
WHERE tool = 'opencode-hooks'
    AND extract(source, '(ses_[A-Za-z0-9]+)\\.jsonl$') NOT IN (SELECT session_id FROM agents.opencode_sessions);

CREATE VIEW agents.opencode_hook_tool_calls AS
WITH
    calls AS
    (
        SELECT
            host,
            session_id,
            line,
            at,
            name,
            input,
            row_number() OVER (PARTITION BY session_id, name, input ORDER BY line) AS nth
        FROM agents.opencode_hook_lines
        WHERE type = 'tool_use'
    ),
    results AS
    (
        SELECT
            session_id,
            name,
            input,
            at,
            JSONExtract(record, 'tool_output', 'exit', 'Nullable(Int32)') AS exit_code,
            length(JSONExtractRaw(record, 'tool_output')) AS output_bytes,
            row_number() OVER (PARTITION BY session_id, name, input ORDER BY line) AS nth
        FROM agents.opencode_hook_lines
        WHERE type = 'tool_result'
    )
SELECT
    'opencode' AS tool,
    calls.host AS host,
    calls.session_id AS session_id,
    '' AS request_id,
    concat(calls.session_id, ':', toString(calls.line)) AS call_id,
    calls.at AS ts,
    calls.name AS name,
    calls.input AS input,
    if(results.exit_code IS NULL, NULL, toUInt8(results.exit_code != 0)) AS is_error,
    if(results.session_id = '', NULL, toUInt64(results.output_bytes)) AS output_bytes,
    if(results.session_id = '', NULL, toFloat64(dateDiff('millisecond', calls.at, results.at))) AS duration_ms
FROM calls
LEFT JOIN results
    ON calls.session_id = results.session_id AND calls.name = results.name
    AND calls.input = results.input AND calls.nth = results.nth;

CREATE VIEW agents.opencode_recovered_sessions AS
SELECT
    session_id,
    any(host) AS host,
    min(at) AS started,
    max(at) AS ended,
    countIf(type = 'user') AS prompts,
    countIf(type = 'tool_use') AS tool_calls
FROM agents.opencode_hook_lines
GROUP BY session_id;
