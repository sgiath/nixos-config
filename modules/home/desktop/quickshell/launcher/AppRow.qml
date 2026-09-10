import QtQuick
import Quickshell
import qs.config
import qs.components

// Compact catalog row: ordinal, icon, name with the matched characters lit,
// generic name trailing. The first nine rows carry live digit shortcuts.
Rectangle {
    id: root

    required property DesktopEntry entry
    required property int ordinal
    required property bool current
    required property var positions

    signal hovered
    signal clicked

    readonly property color ink: current ? Theme.background : Theme.text
    readonly property color inkDim: current ? Qt.alpha(Theme.background, 0.7) : Theme.muted
    readonly property bool hot: ordinal < 10

    function html(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Rich text with matched characters in the lit color.
    function marked(name, positions, lit) {
        if (positions.length === 0)
            return html(name);
        let out = "";
        let from = 0;
        for (const at of positions) {
            out += html(name.slice(from, at)) + "<font color=\"" + lit + "\">" + html(name[at]) + "</font>";
            from = at + 1;
        }
        return out + html(name.slice(from));
    }

    implicitHeight: 44
    color: current ? Theme.accent : "transparent"

    Label {
        text: root.hot ? "0" + root.ordinal : ""
        color: root.current ? root.ink : Theme.accent
        width: 28

        anchors {
            left: parent.left
            leftMargin: Theme.padding * 1.5
            verticalCenter: parent.verticalCenter
        }
    }

    AppIcon {
        id: icon

        entry: root.entry
        ink: root.ink
        width: 22
        height: 22

        anchors {
            left: parent.left
            leftMargin: 52
            verticalCenter: parent.verticalCenter
        }
    }

    Text {
        id: name

        text: root.marked(root.entry.name, root.positions, root.current ? Theme.text.toString() : Theme.accent.toString())
        textFormat: Text.StyledText
        color: root.ink
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize

        anchors {
            left: icon.right
            leftMargin: Theme.padding * 2
            right: generic.left
            rightMargin: Theme.padding * 2
            verticalCenter: parent.verticalCenter
        }
    }

    Label {
        id: generic

        text: root.entry.genericName
        color: root.inkDim
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        width: Math.min(implicitWidth, root.width * 0.4)

        anchors {
            right: parent.right
            rightMargin: Theme.padding * 1.5
            verticalCenter: parent.verticalCenter
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
