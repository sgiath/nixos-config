-- Timing from Claude Code and Codex OpenTelemetry (database `otel`, written
-- by the collector since telemetry was enabled; earlier sessions have none).
--
-- Claude's enhanced tracing gives one llm_request span per API call, keyed
-- by the same request_id as the transcript, and tool spans split into time
-- blocked on a permission decision and actual execution. Codex logs carry
-- time to first token per completed response (no response id: matched to a
-- request by session and identical token counts) and measured tool time per
-- call, keyed like the rollout's call ids.

CREATE VIEW agents.claude_request_timing AS
SELECT
    SpanAttributes['request_id'] AS request_id,
    ResourceAttributes['host.name'] AS host,
    Timestamp AS ts,
    toFloat64OrNull(SpanAttributes['duration_ms']) AS duration_ms,
    toFloat64OrNull(SpanAttributes['ttft_ms']) AS ttft_ms,
    toUInt32OrZero(SpanAttributes['attempt']) AS attempt,
    SpanAttributes['success'] = 'true' AS success,
    SpanAttributes['speed'] AS speed,
    SpanAttributes['query_source'] AS query_source
FROM otel.otel_traces
WHERE SpanName = 'claude_code.llm_request' AND SpanAttributes['request_id'] != '';

CREATE VIEW agents.codex_response_timing AS
SELECT
    LogAttributes['conversation.id'] AS session_id,
    Timestamp AS ts,
    toUInt64OrZero(LogAttributes['input_token_count']) AS input_tokens,
    toUInt64OrZero(LogAttributes['output_token_count']) AS output_tokens,
    toFloat64OrNull(LogAttributes['ttft_ms']) AS ttft_ms
FROM otel.otel_logs
WHERE LogAttributes['event.name'] = 'codex.sse_event' AND LogAttributes['event.kind'] = 'response.completed';

-- One row per tool call that telemetry saw. execution_ms is the tool itself;
-- blocked_ms is the wait for a permission decision (Claude only).
CREATE VIEW agents.tool_timing AS
WITH
    tools AS
    (
        SELECT SpanId, SpanAttributes['tool_use_id'] AS call_id, SpanAttributes['tool_name'] AS name
        FROM otel.otel_traces
        WHERE SpanName = 'claude_code.tool'
    ),
    children AS
    (
        SELECT
            ParentSpanId,
            sumIf(Duration, SpanName = 'claude_code.tool.execution') / 1e6 AS execution_ms,
            sumIf(Duration, SpanName = 'claude_code.tool.blocked_on_user') / 1e6 AS blocked_ms,
            anyIf(SpanAttributes['decision'], SpanName = 'claude_code.tool.blocked_on_user') AS decision,
            anyIf(SpanAttributes['source'], SpanName = 'claude_code.tool.blocked_on_user') AS decision_source,
            anyIf(SpanAttributes['success'] = 'true', SpanName = 'claude_code.tool.execution') AS success
        FROM otel.otel_traces
        WHERE SpanName IN ('claude_code.tool.execution', 'claude_code.tool.blocked_on_user')
        GROUP BY ParentSpanId
    )
SELECT
    'claude' AS tool,
    tools.call_id AS call_id,
    tools.name AS name,
    toNullable(children.execution_ms) AS execution_ms,
    toNullable(children.blocked_ms) AS blocked_ms,
    children.decision AS decision,
    children.decision_source AS decision_source,
    toNullable(children.success) AS success
FROM tools
INNER JOIN children ON children.ParentSpanId = tools.SpanId
UNION ALL
SELECT
    'codex' AS tool,
    LogAttributes['call_id'] AS call_id,
    any(LogAttributes['tool_name']) AS name,
    toNullable(toFloat64(max(toFloat64OrZero(LogAttributes['duration_ms'])))) AS execution_ms,
    CAST(NULL AS Nullable(Float64)) AS blocked_ms,
    '' AS decision,
    '' AS decision_source,
    toNullable(max(LogAttributes['success'] = 'true')) AS success
FROM otel.otel_logs
WHERE LogAttributes['event.name'] = 'codex.tool_result' AND LogAttributes['call_id'] != ''
GROUP BY call_id;
