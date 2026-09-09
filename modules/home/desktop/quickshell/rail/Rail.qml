import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// One vertical rail on the left edge of every screen: output id on top,
// workspaces below it, clock pinned to the bottom. Variants tracks hotplug.
Variants {
    model: Theme.screens

    PanelWindow {
        id: rail

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        implicitWidth: Theme.railWidth
        WlrLayershell.namespace: "sgiath-rail"

        anchors {
            top: true
            left: true
            bottom: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.panel

            Rectangle {
                width: 1
                color: Theme.line

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
            }

            Column {
                id: head

                spacing: Theme.spacing

                anchors {
                    top: parent.top
                    topMargin: Theme.padding * 2
                    left: parent.left
                    right: parent.right
                    rightMargin: 1
                }

                Label {
                    text: rail.screen.name
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: parent.width - 2 * Theme.padding
                    height: 1
                    color: Theme.line
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Workspaces {
                screen: rail.screen

                anchors {
                    top: head.bottom
                    topMargin: Theme.padding * 2
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Clock {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: Theme.padding * 2
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
