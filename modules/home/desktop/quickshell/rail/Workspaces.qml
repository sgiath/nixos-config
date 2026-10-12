import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// Regular workspaces of this rail's monitor, stacked top to bottom; special
// workspaces have negative ids. Each cell shows the id (what the keybinding
// targets) and, for named workspaces, the name (what lives there).
// Focused: solid accent block. Active but not focused (this monitor's
// visible workspace while another monitor holds focus, or covered by a
// scratchpad): accent outline. Everything else: hairline cell.
// A shown scratchpad (any special workspace) gets its own cell below the
// regular ones and takes the solid block while its monitor is focused;
// clicking it hides the scratchpad again.
Column {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property string scratchpad: Scratchpad.shown(monitor)
    readonly property bool focused: Hyprland.focusedMonitor === monitor

    spacing: Theme.spacing

    Repeater {
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(ws => ws.monitor === root.monitor && ws.id > 0).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            id: cell

            required property HyprlandWorkspace modelData

            readonly property bool lit: (modelData.focused && !root.scratchpad) || modelData.urgent
            readonly property bool named: modelData.name !== String(modelData.id)

            width: Theme.railWidth - 2 * Theme.padding - 1
            height: 46
            color: modelData.urgent ? Theme.urgent : lit ? Theme.accent : "transparent"
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

    Rectangle {
        visible: root.scratchpad !== ""
        width: Theme.railWidth - 2 * Theme.padding - 1
        height: 1
        color: Theme.line
    }

    Rectangle {
        id: scratch

        visible: root.scratchpad !== ""
        width: Theme.railWidth - 2 * Theme.padding - 1
        height: 46
        color: root.focused ? Theme.accent : "transparent"
        border.width: 1
        border.color: Theme.accent

        Column {
            anchors.centerIn: parent
            spacing: 1

            Label {
                text: "scratch"
                color: root.focused ? Theme.background : Theme.muted
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.scratchpad
                color: root.focused ? Theme.background : Theme.text
                width: scratch.width - 2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.bold: root.focused
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(root.scratchpad)})`)
        }
    }
}
