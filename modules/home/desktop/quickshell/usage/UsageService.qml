pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polls `omp usage --json` and flattens its reports into one entry per
// account: provider, who it belongs to, its limits, and the tightest limit
// as the account's headline fraction.
Singleton {
    id: root

    readonly property int intervalMs: 5 * 60 * 1000

    // Cards appear in this order; providers not listed follow in report order.
    readonly property var providerOrder: ["openai-codex", "anthropic", "xai-oauth", "cursor", "opencode-go"]

    // Limits that add nothing next to their siblings: the Claude 7-day pool
    // is only interesting through its Fable tier, Spark and the Grok chat and
    // voice products are unused.
    readonly property var hiddenLimits: ["anthropic:7d", "openai-codex:spark:primary", "openai-codex:spark:secondary", "xai-oauth:product:grokchat:1w", "xai-oauth:product:grokvoice:1w"]

    property var accounts: []
    property double generatedAt: 0
    property string error: ""
    readonly property bool busy: proc.running

    function refresh() {
        proc.running = true;
    }

    // Fraction of the window consumed; null when the limit has no ceiling.
    function fraction(amount) {
        if (amount.usedFraction !== undefined)
            return amount.usedFraction;
        if (amount.limit)
            return amount.used / amount.limit;
        return null;
    }

    function formatAmount(amount) {
        switch (amount.unit) {
        case "percent":
            return Math.round(amount.used) + "%";
        case "usd":
            return "$" + amount.used.toFixed(2) + (amount.limit ? " / $" + amount.limit : "");
        default:
            return amount.used + " " + amount.unit.toUpperCase();
        }
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
                        window: limit.window ? limit.window.label : "",
                        resetsAt: limit.window && limit.window.resetsAt ? limit.window.resetsAt : 0,
                        fraction: fraction(limit.amount),
                        value: formatAmount(limit.amount),
                        exhausted: limit.status === "exhausted"
                    }));
            // The tightest limit is the account's headline: its fraction
            // drives the gauge, its window the compact countdown.
            const headline = limits.reduce((acc, l) => (l.fraction ?? 0) > (acc ? acc.fraction ?? 0 : -1) ? l : acc, null);
            return {
                rank: rank(report.provider) * data.reports.length + index,
                provider: report.provider.replace(/-/g, " "),
                owner: (report.metadata || {}).email || (report.metadata || {}).planType || "",
                limits: limits,
                worst: headline ? headline.fraction ?? 0 : 0,
                worstResetsAt: headline ? headline.resetsAt : 0
            };
        }).sort((a, b) => a.rank - b.rank);
        generatedAt = data.generatedAt;
        error = "";
    }

    Process {
        id: proc

        command: ["omp", "--profile", "default", "usage", "--json"]
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

        // Non-zero exit: last stderr line is the most specific message omp
        // gives; stderr noise on a successful run is not an error.
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
