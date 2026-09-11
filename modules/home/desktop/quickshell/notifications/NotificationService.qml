pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Owns org.freedesktop.Notifications for the session. Without an owner,
// Chromium and Electron apps draw their own popup toplevels, which Hyprland
// tiles like any other window; with one, every notification lands in the
// corner stack instead.
Singleton {
    id: root

    // Server default when a client sends expireTimeout -1.
    readonly property int defaultTimeout: 6000

    readonly property NotificationServer server: NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => notification.tracked = true
    }

    // Milliseconds until a notification expires on its own; 0 keeps it until
    // dismissed. Critical ones stay: that is what the urgency is for.
    function timeout(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        if (notification.expireTimeout < 0)
            return defaultTimeout;
        return notification.expireTimeout;
    }

    function color(notification) {
        switch (notification.urgency) {
        case NotificationUrgency.Critical:
            return Theme.urgent;
        case NotificationUrgency.Low:
            return Theme.muted;
        default:
            return Theme.accent;
        }
    }
}
