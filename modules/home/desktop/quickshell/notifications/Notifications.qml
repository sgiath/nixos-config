import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config

// Toast stack in the top-right corner of the widest screen, tucked against
// the usage strip. The window only exists while something is showing and
// only the cards take input, so nothing underneath loses clicks.
PanelWindow {
    id: root

    readonly property var tracked: NotificationService.server.trackedNotifications

    screen: Theme.mainScreen
    visible: toasts.count > 0
    color: "transparent"
    implicitWidth: Theme.panelWidth
    implicitHeight: stack.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sgiath-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: stack
    }

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.padding * 2
        right: Theme.railWidth + Theme.padding
    }

    Column {
        id: stack

        width: parent.width
        spacing: Theme.spacing

        Repeater {
            id: toasts

            model: root.tracked

            Toast {
                required property Notification modelData

                notification: modelData
                width: stack.width
            }
        }
    }
}
