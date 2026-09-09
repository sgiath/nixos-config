import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Right-edge readout of subscription usage on the widest screen only; the
// data is global, duplicating it per monitor would say nothing new.
//
// At rest it is a rail-width strip mirroring the left rail; hovering it
// widens the strip to the full panel. The window itself is always full
// width so growing is a repaint, not a layer-surface resize; the exclusive
// zone stays rail-sized and only the drawn strip takes input, everything
// else in the window falls through to whatever sits beneath it.
PanelWindow {
    id: panel

    property bool expanded: false

    function widest(screens) {
        let best = null;
        for (let i = 0; i < screens.length; i++)
            if (!best || screens[i].width > best.width)
                best = screens[i];
        return best;
    }

    screen: widest(Theme.screens)
    color: "transparent"
    implicitWidth: Theme.panelWidth
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.railWidth
    WlrLayershell.namespace: "sgiath-panel"

    mask: Region {
        item: surface
    }

    anchors {
        top: true
        right: true
        bottom: true
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Brushing past the edge must not pop the panel; a deliberate stop does.
    Timer {
        id: openDelay

        interval: 180
        onTriggered: panel.expanded = true
    }

    Rectangle {
        id: surface

        width: panel.expanded ? Theme.panelWidth : Theme.railWidth
        color: Theme.panel
        clip: true

        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }

        Behavior on width {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    openDelay.restart();
                } else {
                    openDelay.stop();
                    panel.expanded = false;
                }
            }
        }

        Rectangle {
            width: 1
            color: Theme.line

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
        }

        Compact {
            now: clock.date.getTime()
            width: Theme.railWidth
            opacity: panel.expanded ? 0 : 1
            visible: opacity > 0

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        Expanded {
            now: clock.date.getTime()
            width: Theme.panelWidth
            opacity: panel.expanded ? 1 : 0
            visible: opacity > 0

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }
}
