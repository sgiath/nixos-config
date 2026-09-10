import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config

// Themed icon of a desktop entry; entries without one get their initial in
// a hairline box so the column never has holes.
Item {
    id: root

    required property DesktopEntry entry
    property color ink: Theme.accent

    readonly property string source: Quickshell.iconPath(entry.icon, true)

    IconImage {
        anchors.fill: parent
        source: root.source
        visible: root.source !== ""
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.source === ""
        color: "transparent"
        border.width: 1
        border.color: root.ink

        Text {
            text: root.entry.name.charAt(0).toUpperCase()
            color: root.ink
            font.family: Theme.fontFamily
            font.pointSize: root.height * 0.45
            font.bold: true
            anchors.centerIn: parent
        }
    }
}
