import QtQuick
import Quickshell
import qs.config
import qs.components

// One of the primary targets: a workspace-style cell big enough to hit
// without aiming, launched by the digit in its corner. Current: solid
// accent block, like the focused workspace on the rail.
Rectangle {
    id: root

    required property DesktopEntry entry
    required property int ordinal
    required property bool current

    signal hovered
    signal clicked

    readonly property color ink: current ? Theme.background : Theme.text
    readonly property color inkDim: current ? Qt.alpha(Theme.background, 0.7) : Theme.muted

    implicitHeight: 84
    color: current ? Theme.accent : "transparent"
    border.width: 1
    border.color: current ? Theme.accent : Theme.line

    Label {
        text: (root.ordinal < 10 ? "0" : "") + root.ordinal
        color: root.current ? root.ink : Theme.accent

        anchors {
            top: parent.top
            left: parent.left
            margins: Theme.padding * 1.5
        }
    }

    AppIcon {
        id: icon

        entry: root.entry
        ink: root.ink
        width: 40
        height: 40

        anchors {
            left: parent.left
            leftMargin: 52
            verticalCenter: parent.verticalCenter
        }
    }

    Column {
        spacing: 2

        anchors {
            left: icon.right
            leftMargin: Theme.padding * 2.5
            right: parent.right
            rightMargin: Theme.padding * 2
            verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.entry.name
            color: root.ink
            width: parent.width
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeLarge
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }

        Label {
            text: root.entry.genericName || root.entry.comment
            color: root.inkDim
            width: parent.width
            elide: Text.ElideRight
        }
    }

    Label {
        text: root.entry.actions.length > 0 ? root.entry.actions.length + " actions" : ""
        color: root.inkDim

        anchors {
            bottom: parent.bottom
            right: parent.right
            margins: Theme.padding * 1.5
        }
    }

    HoverHandler {
        onHoveredChanged: if (hovered)
            root.hovered()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
