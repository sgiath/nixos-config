import QtQuick
import Quickshell
import qs.config
import qs.components

// Spec sheet of the current row: id and categories, description, the exact
// command, and one chip per way to run it. Tab walks the chips; the lit
// chip is what Enter executes.
Item {
    id: root

    // null while nothing matches
    property DesktopEntry entry: null
    // -1 runs the entry itself; otherwise entry.actions[action]
    property int action: -1

    signal pick(int action)

    readonly property var actions: entry ? entry.actions : []
    readonly property string command: entry ? (action >= 0 ? actions[action].execString : entry.execString) : ""

    implicitHeight: 148

    Corners {
        anchors.fill: parent
    }

    Item {
        anchors {
            fill: parent
            margins: Theme.padding * 1.5
        }

        Label {
            id: ident

            text: root.entry ? root.entry.id : "no match"
            color: root.entry ? Theme.accent : Theme.muted
            elide: Text.ElideMiddle
            font.capitalization: Font.MixedCase

            anchors {
                top: parent.top
                left: parent.left
                right: categories.left
                rightMargin: Theme.padding * 2
            }
        }

        Label {
            id: categories

            text: root.entry ? root.entry.categories.slice(0, 3).join(" · ") : ""
            dim: true

            anchors {
                top: parent.top
                right: parent.right
            }
        }

        Text {
            id: comment

            text: root.entry ? root.entry.comment || root.entry.genericName || "" : "nothing in the catalog answers to that"
            color: Theme.subtext
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize

            anchors {
                top: ident.bottom
                topMargin: Theme.padding * 1.5
                left: parent.left
                right: parent.right
            }
        }

        Text {
            text: root.command
            color: Theme.muted
            elide: Text.ElideMiddle
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeSmall

            anchors {
                bottom: chips.top
                bottomMargin: Theme.padding * 1.5
                left: parent.left
                right: parent.right
            }
        }

        Row {
            id: chips

            spacing: Theme.spacing
            visible: root.actions.length > 0

            anchors {
                bottom: parent.bottom
                left: parent.left
            }

            Repeater {
                model: root.actions.length > 0 ? [null].concat(root.actions) : []

                Rectangle {
                    id: chip

                    required property var modelData
                    required property int index

                    readonly property bool lit: index - 1 === root.action

                    width: chipLabel.implicitWidth + Theme.padding * 2
                    height: 24
                    color: lit ? Theme.accent : "transparent"
                    border.width: 1
                    border.color: lit ? Theme.accent : Theme.line

                    Label {
                        id: chipLabel

                        text: chip.modelData ? chip.modelData.name : "open"
                        color: chip.lit ? Theme.background : Theme.subtext
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(chip.index - 1)
                    }
                }
            }
        }
    }
}
