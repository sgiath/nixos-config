pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polls `sgiath-usage` (desktop/usage-collector) and flattens its reports
// into one entry per account: provider, who it belongs to, its limits, and
// the weekly limit as the account's headline fraction. Fractions are null
// where a provider names a window but not its usage; a provider that failed
// keeps its card with an error.
Singleton {
    id: root

    readonly property int intervalMs: 5 * 60 * 1000

    // Cards appear in this order; providers not listed follow in report order.
    readonly property var providerOrder: ["openai-codex", "anthropic", "xai-oauth", "meta-muse"]

    // Limits that add nothing next to their siblings: the Claude 7-day pool
    // is only interesting through its Fable tier, Spark and the Grok chat and
    // voice products are unused.
    readonly property var hiddenLimits: ["openai-codex:base-model-inference:primary", "xai-oauth:product:grokchat:1w", "xai-oauth:product:grokvoice:1w"]

    property var accounts: []
    property double generatedAt: 0
    property string error: ""
    readonly property bool busy: proc.running

    function refresh() {
        proc.running = true;
    }

    // "42%", or "--" when the provider did not say.
    function formatPercent(fraction) {
        return fraction === null ? "--" : Math.round(fraction * 100) + "%";
    }

    // "2D 04H", "4H 12M", "12M"; "DUE" once the window has already rolled.
    function formatReset(resetsAt, now) {
        const ms = resetsAt - now;
        if (ms <= 0)
            return "DUE";
        const minutes = Math.floor(ms / 60000);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        const pad = n => (n < 10 ? "0" : "") + n;
        if (days > 0)
            return days + "D " + pad(hours % 24) + "H";
        if (hours > 0)
            return hours + "H " + pad(minutes % 60) + "M";
        return minutes + "M";
    }

    function ingest(text) {
        const data = JSON.parse(text);
        const rank = provider => {
            const i = providerOrder.indexOf(provider);
            return i === -1 ? providerOrder.length : i;
        };
        accounts = data.reports.map((report, index) => {
            const limits = report.limits.filter(limit => hiddenLimits.indexOf(limit.id) === -1).map(limit => ({
                        label: limit.label,
                        span: limit.window.durationMs,
                        resetsAt: limit.window.resetsAt,
                        fraction: limit.amount.usedFraction,
                        value: formatPercent(limit.amount.usedFraction),
                        exhausted: limit.status === "exhausted"
                    }));
            // The headline drives the gauge and the compact countdown: the
            // tightest known limit in the account's longest window, so 7 days
            // rather than a 5-hour pool. With nothing known in that window
            // it stays null and keeps the window's countdown.
            const longest = limits.reduce((acc, l) => Math.max(acc, l.span), 0);
            const headline = limits.filter(l => l.span === longest).reduce((acc, l) => !acc || (l.fraction ?? -1) > (acc.fraction ?? -1) ? l : acc, null);
            return {
                rank: rank(report.provider) * data.reports.length + index,
                provider: report.provider.replace(/-/g, " "),
                owner: report.metadata.email || report.metadata.planType || "",
                limits: limits,
                error: report.error || "",
                worst: headline ? headline.fraction : null,
                worstResetsAt: headline ? headline.resetsAt : 0
            };
        }).sort((a, b) => a.rank - b.rank);
        generatedAt = data.generatedAt;
        error = "";
    }

    Process {
        id: proc

        command: ["sgiath-usage"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.ingest(text);
                } catch (e) {
                    root.error = "PARSE " + e.message;
                }
            }
        }

        stderr: StdioCollector {
            id: stderr
        }

        // The collector reports provider failures in its JSON; a non-zero
        // exit is a crash, whose last stderr line names the exception.
        onExited: (code, status) => {
            if (code === 0)
                return;
            const lines = stderr.text.trim().split("\n");
            root.error = lines[lines.length - 1] || "EXIT " + code;
        }
    }

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
