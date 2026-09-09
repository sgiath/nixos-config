import QtQuick
import Quickshell
import qs.config

// Time above date, one line each; seconds are noise at a glance.
Column {
    id: root

    spacing: 2

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize + 2
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
        text: Qt.formatDateTime(clock.date, "yyyy-MM-dd")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeSmall
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
