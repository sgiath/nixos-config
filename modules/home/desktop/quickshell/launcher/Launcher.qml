import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components

// Full-height drawer that slides out from behind the left rail on the
// monitor holding focus; `desktop-shell launcher` toggles it over IPC.
//
// Built around four targets: the pinned entries sit on top as big cells and
// a bare digit launches them, so the common case is two keystrokes. Typing
// turns the drawer into a ranked search over the whole catalog; the sheet
// at the bottom shows what Enter will run, Tab picks an entry action.
PanelWindow {
    id: root

    property bool open: false
    property string query: ""
    property int action: -1

    readonly property var rows: query === "" ? Apps.idle() : Apps.search(query)
    readonly property var current: list.currentIndex >= 0 && list.currentIndex < rows.length ? rows[list.currentIndex] : null

    function toggle() {
        if (open) {
            close();
            return;
        }
        const focused = Hyprland.focusedMonitor;
        let target = null;
        for (const s of Theme.screens)
            if (focused && s.name === focused.name)
                target = s;
        screen = target || Theme.mainScreen;
        input.text = "";
        list.currentIndex = 0;
        action = -1;
        visible = true;
        open = true;
        input.forceActiveFocus();
    }

    function close() {
        open = false;
    }

    function move(delta) {
        if (rows.length === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + delta));
    }

    function run(index, action) {
        if (index < 0 || index >= rows.length)
            return;
        const entry = rows[index].entry;
        Apps.launch(entry, action >= 0 && action < entry.actions.length ? entry.actions[action] : null);
        close();
    }

    function cycleAction(delta) {
        if (!current)
            return;
        const n = current.entry.actions.length + 1;
        action = ((action + 1 + delta) % n + n) % n - 1;
    }

    onQueryChanged: {
        list.currentIndex = 0;
        action = -1;
    }

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sgiath-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    // Everything right of the rail dims; the rail itself stays crisp so the
    // drawer reads as pulled out from behind it.
    Rectangle {
        x: Theme.railWidth
        width: parent.width - x
        height: parent.height
        color: Theme.background
        opacity: root.open ? 0.45 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: drawer

        readonly property int shut: Theme.railWidth - width

        x: root.open ? Theme.railWidth : shut
        width: Theme.launcherWidth
        height: parent.height
        color: Theme.panel
        clip: true

        // The slide is the close animation; the window unmaps once it lands.
        onXChanged: if (!root.open && x === shut)
            root.visible = false

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            width: 1
            color: Theme.line

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
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
                rightMargin: Theme.padding * 2 + 1
            }

            Corners {
                anchors.fill: parent
            }

            Text {
                id: title

                text: "LAUNCH"
                color: Theme.text
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
                text: Apps.all.length + " applications"
                dim: true

                anchors {
                    top: title.bottom
                    left: title.left
                }
            }

            Label {
                text: root.query === "" ? "catalog" : "matches"
                dim: true

                anchors {
                    top: parent.top
                    right: parent.right
                    margins: Theme.padding * 1.5
                }
            }

            Text {
                text: root.query === "" ? (Apps.pinned.length < 10 ? "0" : "") + Apps.pinned.length + " pinned" : root.rows.length
                color: root.rows.length === 0 ? Theme.urgent : Theme.subtext
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize

                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: Theme.padding * 1.5
                }
            }
        }

        // Command line: slash prompt, tracked input, hairline that turns
        // accent while a query is live.
        Item {
            id: prompt

            height: 44

            anchors {
                top: header.bottom
                topMargin: Theme.padding
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 2
                rightMargin: Theme.padding * 2 + 1
            }

            Text {
                id: slash

                text: "/"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeLarge

                anchors {
                    left: parent.left
                    leftMargin: Theme.padding * 1.5
                    verticalCenter: parent.verticalCenter
                }
            }

            TextInput {
                id: input

                color: Theme.text
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeLarge
                font.letterSpacing: 1
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                clip: true
                focus: true

                onTextChanged: root.query = text.trim()

                anchors {
                    left: slash.right
                    leftMargin: Theme.padding * 2
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.accent

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: input.activeFocus

                        NumberAnimation {
                            to: 0
                            duration: 400
                            easing.type: Easing.InQuad
                        }

                        NumberAnimation {
                            to: 1
                            duration: 400
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Label {
                    text: "type to search, digit to launch"
                    dim: true
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const alt = event.modifiers & Qt.AltModifier;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.close();
                        break;
                    case Qt.Key_Down:
                        root.move(1);
                        break;
                    case Qt.Key_Up:
                        root.move(-1);
                        break;
                    case Qt.Key_PageDown:
                        root.move(8);
                        break;
                    case Qt.Key_PageUp:
                        root.move(-8);
                        break;
                    case Qt.Key_Home:
                        if (ctrl)
                            list.currentIndex = 0;
                        else
                            return;
                        break;
                    case Qt.Key_End:
                        if (ctrl)
                            list.currentIndex = root.rows.length - 1;
                        else
                            return;
                        break;
                    case Qt.Key_Tab:
                        root.cycleAction(1);
                        break;
                    case Qt.Key_Backtab:
                        root.cycleAction(-1);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.run(list.currentIndex, root.action);
                        break;
                    case Qt.Key_J:
                    case Qt.Key_N:
                        if (ctrl)
                            root.move(1);
                        else
                            return;
                        break;
                    case Qt.Key_K:
                    case Qt.Key_P:
                        if (ctrl)
                            root.move(-1);
                        else
                            return;
                        break;
                    default:
                        // Bare digits launch while the line is empty; with a
                        // query they are text unless Alt says otherwise.
                        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && (alt || input.text === ""))
                            root.run(event.key - Qt.Key_1, -1);
                        else
                            return;
                    }
                    event.accepted = true;
                }
            }

            Rectangle {
                height: 1
                color: root.query === "" ? Theme.line : Theme.accent

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
            }
        }

        ListView {
            id: list

            model: root.rows
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            keyNavigationEnabled: false

            anchors {
                top: prompt.bottom
                topMargin: Theme.padding
                bottom: sheet.top
                bottomMargin: Theme.padding * 2
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 2
                rightMargin: Theme.padding * 2 + 1
            }

            section.property: "section"
            section.delegate: Item {
                required property string section

                width: ListView.view.width
                height: 34

                Label {
                    id: heading

                    text: parent.section
                    dim: true

                    anchors {
                        left: parent.left
                        leftMargin: Theme.padding * 1.5
                        verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    height: 1
                    color: Theme.line

                    anchors {
                        left: heading.right
                        leftMargin: Theme.padding * 1.5
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                }
            }

            delegate: Loader {
                id: row

                required property var modelData
                required property int index

                readonly property bool current: ListView.isCurrentItem

                // Height follows the loaded item's implicit height; setting it
                // here would be pushed back into the item and loop.
                width: ListView.view.width
                sourceComponent: modelData.section === "pinned" ? pinnedCell : appRow

                Component {
                    id: pinnedCell

                    // Cells keep a gap between them; catalog rows touch.
                    Item {
                        implicitHeight: cell.implicitHeight + Theme.spacing

                        PinnedCell {
                            id: cell

                            width: parent.width
                            entry: row.modelData.entry
                            ordinal: row.index + 1
                            current: row.current
                            onHovered: list.currentIndex = row.index
                            onClicked: root.run(row.index, -1)
                        }
                    }
                }

                Component {
                    id: appRow

                    AppRow {
                        width: row.width
                        entry: row.modelData.entry
                        ordinal: row.index + 1
                        positions: row.modelData.positions
                        current: row.current
                        onHovered: list.currentIndex = row.index
                        onClicked: root.run(row.index, -1)
                    }
                }
            }
        }

        Detail {
            id: sheet

            entry: root.current ? root.current.entry : null
            action: root.action
            onPick: which => root.run(list.currentIndex, which)

            anchors {
                bottom: hints.top
                bottomMargin: Theme.padding * 2
                left: parent.left
                right: parent.right
                leftMargin: Theme.padding * 2
                rightMargin: Theme.padding * 2 + 1
            }
        }

        Row {
            id: hints

            spacing: Theme.padding * 3

            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.padding * 2
                left: parent.left
                leftMargin: Theme.padding * 3.5
            }

            Repeater {
                model: [["↵", "open"], ["⇥", "action"], ["1-9", "quick"], ["esc", "close"]]

                Row {
                    required property var modelData

                    spacing: Theme.padding

                    Label {
                        text: parent.modelData[0]
                        color: Theme.subtext
                        font.capitalization: Font.MixedCase
                    }

                    Label {
                        text: parent.modelData[1]
                        dim: true
                    }
                }
            }
        }
    }
}
