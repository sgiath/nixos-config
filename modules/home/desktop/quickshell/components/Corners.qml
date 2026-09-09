import QtQuick
import qs.config

// Four L-shaped registration marks; frames a region without boxing it in.
Item {
    id: root

    property color color: Theme.line
    property int length: 8

    Repeater {
        model: 4

        Item {
            id: mark

            required property int index

            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index >= 2

            x: atRight ? root.width - root.length : 0
            y: atBottom ? root.height - root.length : 0
            width: root.length
            height: root.length

            Rectangle {
                width: mark.width
                height: 1
                y: mark.atBottom ? mark.height - 1 : 0
                color: root.color
            }

            Rectangle {
                width: 1
                height: mark.height
                x: mark.atRight ? mark.width - 1 : 0
                color: root.color
            }
        }
    }
}
