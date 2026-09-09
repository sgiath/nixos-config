import QtQuick
import qs.config
import qs.components

// Label, reset countdown and value on one line; cell meter underneath.
Column {
    id: root

    required property var limit
    required property double now

    readonly property bool metered: limit.fraction !== null
    readonly property color tone: limit.exhausted ? Theme.red : Theme.load(metered ? limit.fraction : 0)

    spacing: 4

    Item {
        width: parent.width
        height: value.implicitHeight

        Label {
            text: root.limit.label
            elide: Text.ElideRight

            anchors {
                left: parent.left
                right: reset.left
                rightMargin: Theme.padding
                verticalCenter: parent.verticalCenter
            }
        }

        Label {
            id: reset

            text: root.limit.resetsAt ? "T-" + UsageService.formatReset(root.limit.resetsAt, root.now) : ""
            dim: true

            anchors {
                right: value.left
                rightMargin: Theme.padding * 1.5
                verticalCenter: parent.verticalCenter
            }
        }

        Text {
            id: value

            text: root.limit.value
            color: root.tone
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
        }
    }

    SegmentBar {
        width: parent.width
        visible: root.metered
        fraction: root.metered ? root.limit.fraction : 0
        color: root.tone
    }
}
