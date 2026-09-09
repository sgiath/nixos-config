import QtQuick
import qs.config

// Fixed-pitch cell bar: crisp at any width, reads like a meter, not a slider.
Row {
    id: root

    property real fraction: 0
    property color color: Theme.text
    property int cell: 6
    property int gap: 2

    readonly property int cells: Math.max(1, Math.floor((width + gap) / (cell + gap)))
    readonly property int filled: Math.round(Math.min(1, Math.max(0, fraction)) * cells)

    spacing: gap
    height: cell

    Repeater {
        model: root.cells

        Rectangle {
            required property int index

            width: root.cell
            height: root.cell
            color: index < root.filled ? root.color : Theme.overlay
            opacity: index < root.filled ? 1 : 0.4
        }
    }
}
