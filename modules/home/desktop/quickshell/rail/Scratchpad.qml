pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Special workspace currently shown on a monitor. HyprlandMonitor has no
// typed property for it and Quickshell does not re-read monitors when one
// is shown or hidden, so refresh on the events that can change it; the
// initial monitor read already carries it.
Singleton {
    // Name without the "special:" prefix, as toggle_special takes it;
    // empty when nothing is shown.
    function shown(monitor: HyprlandMonitor): string {
        const name = monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
        return name.replace(/^special:/, "");
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (["activespecial", "moveworkspacev2", "destroyworkspacev2"].includes(event.name))
                Hyprland.refreshMonitors();
        }
    }
}
