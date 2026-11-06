-- One row per upstream execution through CLIProxyAPI (archive.cliproxy).
-- Retries of one client request are separate executions with the same
-- request_id. input_tokens includes cache reads and output_tokens includes
-- reasoning; input_uncached_tokens is the part billed as fresh input.
CREATE VIEW agents.cliproxy_requests AS
SELECT
    host,
    event_id,
    parseDateTime64BestEffort(JSONExtractString(record, 'timestamp'), 9, 'UTC') AS at,
    JSONExtractString(record, 'request_id') AS request_id,
    JSONExtractString(record, 'execution_id') AS execution_id,
    JSONExtractString(record, 'session_id') AS session_id,
    JSONExtractString(record, 'auth_index') AS auth_index,
    -- OAuth logins carry their file name or label. API-key accounts from
    -- the Nix config (Remote LiteLLM, OpenCode Go) are not in the credential
    -- listing; each has one key, so its provider names it.
    coalesce(nullIf(JSONExtractString(record, 'credential'), ''), JSONExtractString(record, 'provider')) AS credential,
    JSONExtractString(record, 'provider') AS provider,
    JSONExtractString(record, 'auth_type') AS auth_type,
    JSONExtractString(record, 'executor_type') AS executor_type,
    -- What the client asked for (remote/..., opencode-go/...) and what ran.
    JSONExtractString(record, 'alias') AS requested_model,
    JSONExtractString(record, 'model') AS model,
    JSONExtractString(record, 'response_model') AS response_model,
    JSONExtractString(record, 'endpoint') AS endpoint,
    JSONExtractString(record, 'user_agent') AS user_agent,
    JSONExtractBool(record, 'stream') AS stream,
    JSONExtractBool(record, 'failed') AS failed,
    toUInt16(JSONExtractUInt(record, 'fail', 'status_code')) AS status_code,
    JSONExtractString(record, 'fail', 'code') AS failure_code,
    JSONExtractUInt(record, 'latency_ms') AS latency_ms,
    JSONExtractUInt(record, 'ttft_ms') AS ttft_ms,
    JSONExtractString(record, 'reasoning_effort') AS reasoning_effort,
    JSONExtractUInt(record, 'tokens', 'input_tokens') AS input_tokens,
    JSONExtractUInt(record, 'token_breakdown', 'input', 'uncached_tokens') AS input_uncached_tokens,
    JSONExtractUInt(record, 'tokens', 'cache_read_tokens') AS cache_read_tokens,
    JSONExtractUInt(record, 'tokens', 'cache_creation_tokens') AS cache_write_tokens,
    JSONExtractUInt(record, 'tokens', 'output_tokens') AS output_tokens,
    JSONExtractUInt(record, 'tokens', 'reasoning_tokens') AS reasoning_tokens,
    JSONExtractUInt(record, 'tokens', 'total_tokens') AS total_tokens
FROM
(
    SELECT host, event_id, argMax(record, ingested_at) AS record
    FROM archive.cliproxy
    GROUP BY host, event_id
);
