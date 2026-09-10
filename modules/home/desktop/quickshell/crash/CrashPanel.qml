import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.launcher

// Drawer that slides out from behind the usage strip on the widest screen
// whenever a launched app dies: what crashed, how, and the tail of its log.
// `qs -c sgiath ipc call crash toggle` brings the last one back.
//
// It never takes the keyboard on its own; a click into the drawer grants
// focus for Esc and R, and the hints at the bottom double as buttons. The
// window is drawer plus strip wide but only the drawer takes input, so the
// usage panel keeps reacting to hover underneath.
PanelWindow {
    id: root

    property bool open: false
    readonly property var crash: CrashService.latest

    function show() {
        visible = true;
        open = true;
    }

    function close() {
        open = false;
    }

    function toggle() {
        if (open)
            close();
        else if (crash)
            show();
    }

    function relaunch() {
        if (!crash || !crash.entry)
            return;
        Apps.launch(crash.entry, null);
        close();
    }

    Connections {
        target: CrashService

        function onReported(): void {
            root.show();
        }
    }

    IpcHandler {
        target: "crash"

        function toggle(): void {
            root.toggle();
        }
    }

    screen: Theme.mainScreen
    visible: false
    color: "transparent"
    implicitWidth: Theme.launcherWidth + Theme.railWidth
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sgiath-crash"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: drawer
    }

    anchors {
        top: true
        right: true
        bottom: true
    }

    Rectangle {
        id: drawer

        readonly property int shut: root.width

        x: root.open ? 0 : shut
        width: Theme.launcherWidth
        height: parent.height
        color: Theme.panel
        clip: true
        focus: true

        // The slide is the close animation; the window unmaps once it lands.
        onXChanged: if (!root.open && x === shut)
            root.visible = false

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.close();
                break;
            case Qt.Key_R:
                root.relaunch();
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: drawer.forceActiveFocus()
        }

        Rectangle {
            width: 1
            color: Theme.urgent

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
        }

        Item {
            id: header

            height: 72

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.padding * 2
                leftMargin: Theme.padding * 2 + 1
            }

            Corners {
                anchors.fill: parent
                color: Theme.urgent
            }

            Text {
                id: title

                text: "CRASH"
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeLarge
                font.letterSpacing: 6

                anchors {
                    top: parent.top
                    left: parent.left
                    margins: Theme.padding * 1.5
                }
            }

            Label {
                text: root.crash ? CrashService.describe(root.crash) : ""
                dim: true
                font.capitalization: Font.MixedCase

                anchors {
                    top: title.bottom
                    left: title.left
                }
            }

            Label {
                text: root.crash ? Qt.formatTime(new Date(root.crash.at), "hh:mm:ss") : ""
                dim: true

                anchors {
                    top: parent.top
                    right: parent.right
                    margins: Theme.padding * 1.5
                }
            }

            Text {
                text: root.crash ? "last " + CrashService.logLines + " lines" : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize

                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: Theme.padding * 1.5
                }
            }
        }

        // Identity line: icon, name, id and the exact command that died.
        Item {
            id: ident

            height: 64

            anchors {
                top: header.bottom
                topMargin: Theme.padding
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 2 + 1
                rightMargin: Theme.padding * 2
            }

            Loader {
                id: icon

                active: root.crash !== null && root.crash.entry !== null
                width: 36
                height: 36

                anchors {
                    left: parent.left
                    leftMargin: Theme.padding * 1.5
                    verticalCenter: parent.verticalCenter
                }

                sourceComponent: AppIcon {
                    entry: root.crash.entry
                    ink: Theme.urgent
                }
            }

            Text {
                id: name

                text: root.crash ? (root.crash.entry ? root.crash.entry.name : root.crash.id) : ""
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeLarge

                anchors {
                    top: parent.top
                    topMargin: Theme.padding
                    left: parent.left
                    leftMargin: 36 + Theme.padding * 3.5
                    right: parent.right
                }
            }

            Text {
                text: root.crash ? (root.crash.entry ? root.crash.entry.execString : root.crash.unit) : ""
                color: Theme.muted
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeSmall

                anchors {
                    top: name.bottom
                    topMargin: Theme.padding / 2
                    left: name.left
                    right: parent.right
                }
            }
        }

        Rectangle {
            id: rule

            height: 1
            color: Theme.line

            anchors {
                top: ident.bottom
                topMargin: Theme.padding
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 3.5 + 1
                rightMargin: Theme.padding * 3.5
            }
        }

        // The log, scrolled to its end where the verdict is; text is
        // selectable so a line can go straight into a search.
        Flickable {
            id: logView

            contentWidth: width
            contentHeight: log.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            anchors {
                top: rule.bottom
                topMargin: Theme.padding
                bottom: hints.top
                bottomMargin: Theme.padding * 2
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 3.5 + 1
                rightMargin: Theme.padding * 3.5
            }

            TextEdit {
                id: log

                width: logView.width
                text: root.crash ? root.crash.log || "the journal holds nothing for this unit" : ""
                color: Theme.subtext
                readOnly: true
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeSmall

                // Height settles after the text does; land on the verdict.
                onHeightChanged: logView.contentY = Math.max(0, height - logView.height)
            }
        }

        Row {
            id: hints

            spacing: Theme.padding * 3

            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.padding * 2
                left: parent.left
                leftMargin: Theme.padding * 3.5 + 1
            }

            Repeater {
                model: [["esc", "dismiss", () => root.close()], ["r", "relaunch", () => root.relaunch()]]

                Row {
                    id: hint

                    required property var modelData

                    spacing: Theme.padding

                    Label {
                        text: hint.modelData[0]
                        color: Theme.subtext
                        font.capitalization: Font.MixedCase
                    }

                    Label {
                        text: hint.modelData[1]
                        dim: true
                    }

                    TapHandler {
                        onTapped: hint.modelData[2]()
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
