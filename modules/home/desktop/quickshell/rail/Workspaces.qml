import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// Regular workspaces of this rail's monitor, stacked top to bottom; special
// workspaces have negative ids. Each cell shows the id (what the keybinding
// targets) and, for named workspaces, the name (what lives there).
// Focused: solid accent block. Active but not focused (this monitor's
// visible workspace while another monitor holds focus): accent outline.
// Everything else: hairline cell.
Column {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    spacing: Theme.spacing

    Repeater {
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(ws => ws.monitor === root.monitor && ws.id > 0).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            id: cell

            required property HyprlandWorkspace modelData

            readonly property bool lit: modelData.focused || modelData.urgent
            readonly property bool named: modelData.name !== String(modelData.id)

            width: Theme.railWidth - 2 * Theme.padding - 1
            height: 46
            color: modelData.urgent ? Theme.urgent : modelData.focused ? Theme.accent : "transparent"
            border.width: 1
            border.color: modelData.active ? Theme.accent : Theme.line

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    text: cell.modelData.id
                    color: cell.lit ? Theme.background : cell.modelData.active ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.bold: cell.lit
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Label {
                    text: cell.modelData.name
                    visible: cell.named
                    color: cell.lit ? Theme.background : Theme.muted
                    width: cell.width - 2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.letterSpacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: cell.modelData.activate()
            }
        }
    }
}
