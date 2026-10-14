-- OpenCode (and the oh-my-opencode plugin, which writes the same store).
--
-- Two generations share most IDs: legacy `message`/`part` rows and v2
-- `session_message` rows with tool calls inline. Each message and tool call is
-- taken once, preferring v2. An assistant message is counted as one request,
-- though a multi-step message can cover several model calls; message wall
-- time includes its tools, so no request duration is given.

CREATE VIEW agents.opencode_rows AS
SELECT
    host,
    splitByChar('#', source)[2] AS table,
    JSONExtractString(record, 'id') AS id,
    JSONExtractString(record, 'session_id') AS session_id,
    JSONExtractString(record, 'message_id') AS message_id,
    JSONExtractString(record, 'type') AS type,
    JSONExtractString(record, 'data') AS data,
    position,
    record
FROM archive.raw
WHERE tool = 'opencode' AND key != 'read';

CREATE VIEW agents.opencode_sessions AS
SELECT
    id AS session_id,
    toUInt8(argMax(JSONExtractString(record, 'parent_id') != '', position)) AS is_subagent,
    argMax(JSONExtractString(record, 'directory'), position) AS cwd
FROM agents.opencode_rows
WHERE table IN ('session', 'session_v2')
GROUP BY id;

CREATE VIEW agents.opencode_requests AS
WITH messages AS
(
    SELECT
        host,
        id,
        session_id,
        table = 'session_message' AS v2,
        position,
        if(v2, JSONExtractString(data, 'model', 'id'), JSONExtractString(data, 'modelID')) AS model,
        JSONExtractInt(data, 'time', 'created') AS created,
        JSONExtractRaw(data, 'tokens') AS tokens,
        JSONExtractString(data, 'finish') AS finish
    FROM agents.opencode_rows
    WHERE (table = 'message' AND JSONExtractString(data, 'role') = 'assistant')
        OR (table = 'session_message' AND type = 'assistant')
)
SELECT
    'opencode' AS tool,
    argMax(m.host, (m.v2, m.position)) AS host,
    '.local/share/opencode' AS account,
    argMax(m.session_id, (m.v2, m.position)) AS session_id,
    m.id AS request_id,
    any(s.is_subagent) AS is_subagent,
    argMax(m.model, (m.v2, m.position)) AS model,
    fromUnixTimestamp64Milli(argMax(m.created, (m.v2, m.position)), 'UTC') AS ts,
    CAST(NULL AS Nullable(Float64)) AS duration_ms,
    CAST(NULL AS Nullable(Float64)) AS ttft_ms,
    argMax(JSONExtractUInt(m.tokens, 'input'), (m.v2, m.position)) AS input_tokens,
    argMax(JSONExtractUInt(m.tokens, 'cache', 'read'), (m.v2, m.position)) AS cache_read_tokens,
    argMax(JSONExtractUInt(m.tokens, 'cache', 'write'), (m.v2, m.position)) AS cache_write_tokens,
    argMax(JSONExtractUInt(m.tokens, 'output'), (m.v2, m.position)) AS output_tokens,
    argMax(JSONExtract(m.tokens, 'reasoning', 'Nullable(UInt64)'), (m.v2, m.position)) AS reasoning_tokens,
    argMax(m.finish, (m.v2, m.position)) AS stop_reason,
    CAST(NULL AS Nullable(UInt32)) AS tool_calls,
    any(s.cwd) AS cwd
FROM messages AS m
LEFT JOIN agents.opencode_sessions AS s ON m.session_id = s.session_id
GROUP BY m.id;

CREATE VIEW agents.opencode_tool_calls AS
WITH calls AS
(
    SELECT
        host,
        session_id,
        message_id AS request_id,
        0 AS v2,
        position,
        JSONExtractString(data, 'callID') AS call_id,
        JSONExtractString(data, 'tool') AS name,
        JSONExtractRaw(data, 'state') AS state,
        JSONExtractInt(state, 'time', 'start') AS started,
        JSONExtractInt(state, 'time', 'end') AS ended,
        length(JSONExtractRaw(state, 'output')) AS output_bytes
    FROM agents.opencode_rows
    WHERE table = 'part' AND JSONExtractString(data, 'type') = 'tool'
    UNION ALL
    SELECT
        host,
        session_id,
        id AS request_id,
        1 AS v2,
        position,
        JSONExtractString(block, 'id') AS call_id,
        JSONExtractString(block, 'name') AS name,
        JSONExtractRaw(block, 'state') AS state,
        JSONExtractInt(block, 'time', 'created') AS started,
        JSONExtractInt(block, 'time', 'completed') AS ended,
        length(JSONExtractRaw(state, 'content')) AS output_bytes
    FROM agents.opencode_rows
    ARRAY JOIN JSONExtractArrayRaw(data, 'content') AS block
    WHERE table = 'session_message' AND type = 'assistant' AND JSONExtractString(block, 'type') = 'tool'
)
SELECT
    'opencode' AS tool,
    argMax(host, (v2, position)) AS host,
    argMax(session_id, (v2, position)) AS session_id,
    argMax(request_id, (v2, position)) AS request_id,
    call_id,
    fromUnixTimestamp64Milli(argMax(started, (v2, position)), 'UTC') AS ts,
    argMax(name, (v2, position)) AS name,
    argMax(JSONExtractRaw(state, 'input'), (v2, position)) AS input,
    toNullable(toUInt8(argMax(JSONExtractString(state, 'status'), (v2, position)) = 'error')) AS is_error,
    toNullable(toUInt64(argMax(output_bytes, (v2, position)))) AS output_bytes,
    if(argMax(ended, (v2, position)) > 0,
        toFloat64(argMax(ended, (v2, position)) - argMax(started, (v2, position))), NULL) AS duration_ms
FROM calls
WHERE call_id != ''
GROUP BY call_id;
