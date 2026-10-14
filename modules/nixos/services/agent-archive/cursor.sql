-- Cursor (global state.vscdb, key/value rows). One `bubbleId:<composer>:<bubble>`
-- row per message; a conversation (composer) is a sequence of turns. A turn
-- starts with your message (type 1), which carries the turn's requestId and
-- model; each model call then issues tool calls sharing a modelCallId, and
-- the turn's token counts are written on its final reply.
--
-- Requests are therefore one row per model call plus one final reply per
-- turn (keyed by the turn's requestId); the turn's tokens stay on whichever
-- message Cursor wrote them to, usually the final reply. Cursor reports input
-- and output tokens without a cache split. Messages without a createdAt (a
-- few hundred, all undated) are left out.
-- Messages of 2025 conversations before October are gone from this store;
-- only their workspace prompt history survives (archive.raw, ItemTable).

CREATE VIEW agents.cursor_bubbles AS
SELECT
    host,
    splitByChar(':', key)[2] AS composer_id,
    splitByChar(':', key)[3] AS bubble_id,
    JSONExtractInt(value, 'type') AS type,
    parseDateTime64BestEffortOrNull(JSONExtractString(value, 'createdAt'), 3, 'UTC') AS ts,
    JSONExtractString(value, 'requestId') AS request_id,
    JSONExtractString(value, 'modelInfo', 'modelName') AS model,
    JSONExtractUInt(value, 'tokenCount', 'inputTokens') AS input_tokens,
    JSONExtractUInt(value, 'tokenCount', 'outputTokens') AS output_tokens,
    JSONExtractRaw(value, 'toolFormerData') AS tool_data
FROM
(
    SELECT host, key, JSONExtractString(argMax(record, position), 'value') AS value
    FROM archive.raw
    WHERE tool = 'cursor' AND key LIKE 'bubbleId:%'
    GROUP BY host, key
)
WHERE ts IS NOT NULL;

-- Every message joined to the turn it belongs to.
CREATE VIEW agents.cursor_turn_bubbles AS
SELECT
    b.*,
    turns.request_id AS turn_id,
    turns.model AS turn_model
FROM agents.cursor_bubbles AS b
ASOF LEFT JOIN
(
    SELECT composer_id, ts, request_id, model
    FROM agents.cursor_bubbles
    WHERE type = 1 AND request_id != ''
) AS turns ON b.composer_id = turns.composer_id AND b.ts >= turns.ts;

CREATE VIEW agents.cursor_requests AS
SELECT
    'cursor' AS tool,
    any(host) AS host,
    '.config/Cursor' AS account,
    any(composer_id) AS session_id,
    request_id,
    toUInt8(0) AS is_subagent,
    any(model) AS model,
    min(ts) AS ts,
    CAST(NULL AS Nullable(Float64)) AS duration_ms,
    CAST(NULL AS Nullable(Float64)) AS ttft_ms,
    sum(input) AS input_tokens,
    toUInt64(0) AS cache_read_tokens,
    toUInt64(0) AS cache_write_tokens,
    sum(output) AS output_tokens,
    CAST(NULL AS Nullable(UInt64)) AS reasoning_tokens,
    '' AS stop_reason,
    toNullable(toUInt32(sum(calls))) AS tool_calls,
    '' AS cwd
FROM
(
    -- Model calls that issued tools.
    SELECT host, composer_id, JSONExtractString(tool_data, 'modelCallId') AS request_id, turn_model AS model, ts,
        input_tokens AS input, output_tokens AS output, toUInt32(1) AS calls
    FROM agents.cursor_turn_bubbles
    WHERE type = 2 AND JSONExtractString(tool_data, 'modelCallId') != ''
    UNION ALL
    -- The final reply of each turn, with the turn's tokens.
    SELECT host, composer_id, turn_id AS request_id, turn_model AS model, ts,
        input_tokens AS input, output_tokens AS output, toUInt32(0) AS calls
    FROM agents.cursor_turn_bubbles
    WHERE type = 2 AND turn_id != '' AND JSONExtractString(tool_data, 'modelCallId') = ''
)
GROUP BY request_id;

CREATE VIEW agents.cursor_tool_calls AS
SELECT
    'cursor' AS tool,
    host,
    composer_id AS session_id,
    JSONExtractString(tool_data, 'modelCallId') AS request_id,
    coalesce(nullIf(JSONExtractString(tool_data, 'toolCallId'), ''), bubble_id) AS call_id,
    ts,
    JSONExtractString(tool_data, 'name') AS name,
    coalesce(nullIf(JSONExtractString(tool_data, 'rawArgs'), ''), JSONExtractString(tool_data, 'params')) AS input,
    toNullable(toUInt8(JSONExtractString(tool_data, 'status') = 'error')) AS is_error,
    toNullable(toUInt64(length(JSONExtractString(tool_data, 'result')))) AS output_bytes,
    CAST(NULL AS Nullable(Float64)) AS duration_ms
FROM agents.cursor_bubbles
WHERE type = 2 AND JSONExtractString(tool_data, 'name') != '';
