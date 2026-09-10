pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.launcher

// Watches the journal for launcher units that end badly and keeps the
// latest failure together with the unit's log. Detection rides the same
// systemd messages system-failure-watcher reacts to, so the drawer shows
// exactly the failure an agent gets sent to investigate: the unit verdict
// for the main process, the core dump for anything the app forked.
Singleton {
    id: root

    readonly property string coredump: "fc2e22bc6ee647b6b90729ab34a250b1"
    readonly property string processExit: "98e322203f7a4ed290d09fe03c09fe15"
    readonly property string unitFailed: "d9b373ed55a64feb8242e02dbe79a49c"
    readonly property int logLines: 200

    // { unit, id, entry, result, code, status, at, log }; null until
    // something has crashed.
    property var latest: null

    signal reported

    // unit -> { code, status }; systemd logs the main process exit right
    // before the unit's failure verdict.
    property var exits: ({})

    readonly property var signalNames: ({
            4: "ILL",
            5: "TRAP",
            6: "ABRT",
            7: "BUS",
            8: "FPE",
            9: "KILL",
            11: "SEGV",
            13: "PIPE"
        })

    // "exit-code · status 1", "core-dump · SEGV (11)"
    function describe(crash) {
        if (crash.code === "exited")
            return crash.result + " · status " + crash.status;
        if (crash.code === "")
            return crash.result;
        return crash.result + " · " + (signalNames[crash.status] || "signal") + " (" + crash.status + ")";
    }

    function ingest(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }
        const unit = event.USER_UNIT || event.COREDUMP_USER_UNIT || "";
        const found = Apps.entryForUnit(unit);
        if (!found)
            return;
        const crash = {
            unit: unit,
            id: found.id,
            entry: found.entry,
            at: Number(event.__REALTIME_TIMESTAMP) / 1000,
            log: ""
        };
        switch (event.MESSAGE_ID) {
        case processExit:
            exits[unit] = {
                code: event.EXIT_CODE,
                status: parseInt(event.EXIT_STATUS)
            };
            return;
        case coredump:
            // A main-process dump is followed by the unit verdict, which
            // then replaces this with the same unit and a fuller log.
            crash.result = "core-dump";
            crash.code = "dumped";
            crash.status = parseInt(event.COREDUMP_SIGNAL);
            break;
        default:
            {
                const exit = exits[unit] || {
                    code: "",
                    status: 0
                };
                delete exits[unit];
                // SIGKILL is the user's doing (forcekillactive, kill -9);
                // systemd already counts TERM/INT/HUP/PIPE as clean exits, and
                // an OOM kill reports its own result so it still gets through.
                if (event.UNIT_RESULT === "signal" && exit.status === 9)
                    return;
                crash.result = event.UNIT_RESULT;
                crash.code = exit.code;
                crash.status = exit.status;
            }
        }
        fetch.createObject(root, {
            crash: crash
        });
    }

    Process {
        id: follow

        // Core dumps land in the system journal, so no --user here; the unit
        // prefix is what scopes this to our own launches.
        command: ["journalctl", "--follow", "--lines=0", "--output=json", "MESSAGE_ID=" + root.coredump, "MESSAGE_ID=" + root.processExit, "MESSAGE_ID=" + root.unitFailed]
        running: true

        stdout: SplitParser {
            onRead: data => root.ingest(data)
        }

        onExited: retry.start()
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: follow.running = true
    }

    // One short-lived reader per failure: the unit is already collected,
    // its output and systemd's verdict live on in the journal.
    Component {
        id: fetch

        Process {
            id: reader

            required property var crash

            command: ["journalctl", "--user", "--unit=" + crash.unit, "--lines=" + root.logLines, "--output=cat", "--no-pager"]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    reader.crash.log = text.trim();
                    root.latest = reader.crash;
                    root.reported();
                    reader.destroy();
                }
            }
        }
    }
}
