pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The launcher's catalog. Pinned ids come from Home Manager; everything
// else is what the desktop database advertises. Launch counts persist in
// the shell's state dir so the recent section survives restarts.
//
// Every list handed to the drawer is an array of rows:
//   { entry, section, positions }
// `positions` are the matched character indices of entry.name (empty
// when the match came from another field).
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Resolved through `all` rather than DesktopEntries.byId so the list
    // re-evaluates once the database has actually been scanned.
    readonly property var pinned: {
        const list = [];
        for (const id of Theme.pinned) {
            const entry = all.find(e => e.id === id);
            if (entry)
                list.push(entry);
        }
        return list;
    }

    readonly property int recentLimit: 6

    // id -> { count, last }
    property var history: ({})

    function uses(entry) {
        const record = history[entry.id];
        return record ? record.count : 0;
    }

    // Idle drawer: pinned cells, then the most launched non-pinned entries,
    // then the rest of the catalog alphabetically.
    function idle() {
        const rows = pinned.map(entry => ({
                    entry: entry,
                    section: "pinned",
                    positions: []
                }));
        const rest = all.filter(entry => pinned.indexOf(entry) === -1);
        const recent = rest.filter(entry => uses(entry) > 0).sort((a, b) => uses(b) - uses(a) || history[b.id].last - history[a.id].last).slice(0, recentLimit);
        for (const entry of recent)
            rows.push({
                entry: entry,
                section: "recent",
                positions: []
            });
        for (const entry of rest)
            if (recent.indexOf(entry) === -1)
                rows.push({
                    entry: entry,
                    section: "all",
                    positions: []
                });
        return rows;
    }

    function search(query) {
        const q = query.toLowerCase();
        const rows = [];
        for (const entry of all) {
            const hit = rank(q, entry);
            if (hit)
                rows.push({
                    entry: entry,
                    section: "match",
                    positions: hit.positions,
                    score: hit.score + Math.min(uses(entry), 20) + (pinned.indexOf(entry) === -1 ? 0 : 30)
                });
        }
        return rows.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
    }

    function boundary(text, i) {
        return i === 0 || /[\s\-_.(\/]/.test(text[i - 1]);
    }

    // Name prefix beats a word start beats a substring beats a scattered
    // subsequence; other fields only count when the name says nothing.
    function rank(q, entry) {
        const name = entry.name.toLowerCase();
        const at = name.indexOf(q);
        if (at !== -1) {
            const positions = [];
            for (let i = 0; i < q.length; i++)
                positions.push(at + i);
            return {
                score: (at === 0 ? 1000 : boundary(name, at) ? 800 : 600) - at,
                positions: positions
            };
        }

        const positions = [];
        let score = 400;
        let prev = -2;
        for (let i = 0, j = 0; i < name.length && j < q.length; i++) {
            if (name[i] !== q[j])
                continue;
            if (i === prev + 1)
                score += 15;
            else if (boundary(name, i))
                score += 10;
            else
                score -= Math.min(i - prev - 1, 10);
            positions.push(i);
            prev = i;
            j++;
        }
        if (positions.length === q.length)
            return {
                score: score - name.length / 4,
                positions: positions
            };

        const fields = [entry.genericName, entry.keywords.join(" "), entry.comment, entry.id];
        for (let i = 0; i < fields.length; i++)
            if (fields[i].toLowerCase().indexOf(q) !== -1)
                return {
                    score: 200 - i * 30,
                    positions: []
                };
        return null;
    }

    // Apps run as their own transient units: the shell's cgroup gets killed
    // on every restart or shell switch and must not take windows with it.
    // The unit name carries the entry id so a failure can be traced back
    // (CrashService) and so system-failure-watcher can tell apps from
    // services.
    readonly property string unitPrefix: "app-sgiath-"

    function unitId(entry) {
        return entry.id.replace(/[^A-Za-z0-9._-]/g, "_");
    }

    // { id, entry } for a unit this launcher started, null for anything
    // else; `entry` is null when the id no longer resolves.
    function entryForUnit(unit) {
        if (!unit.startsWith(unitPrefix) || !unit.endsWith(".service"))
            return null;
        const id = unit.slice(unitPrefix.length, unit.lastIndexOf("-"));
        return {
            id: id,
            entry: all.find(e => unitId(e) === id) || null
        };
    }

    function launch(entry, action) {
        const record = history[entry.id] || {
            count: 0
        };
        const next = Object.assign({}, history);
        next[entry.id] = {
            count: record.count + 1,
            last: Date.now()
        };
        history = next;
        store.setText(JSON.stringify(next));

        const unit = unitPrefix + unitId(entry) + "-" + Date.now();
        const argv = ["systemd-run", "--user", "--collect", "--quiet", "--slice=app.slice", "--unit=" + unit];
        if (entry.workingDirectory !== "")
            argv.push("--working-directory=" + entry.workingDirectory);
        argv.push("--");
        if (entry.runInTerminal)
            argv.push(Theme.terminal);
        Quickshell.execDetached(argv.concat(action ? action.command : entry.command));
    }

    FileView {
        id: store

        path: Quickshell.statePath("launcher.json")
        printErrors: false
        onLoaded: {
            try {
                root.history = JSON.parse(text());
            } catch (e) {
                root.history = {};
            }
        }
    }
}
