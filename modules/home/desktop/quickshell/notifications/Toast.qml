import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.components

// One notification: urgency bar on the left, app icon, sender and time on
// top, summary and body below, actions as text buttons at the bottom.
// Clicking the card fires the default action when there is one and
// dismisses otherwise; hovering holds the expiry timer.
Rectangle {
    id: root

    required property Notification notification

    readonly property color ink: NotificationService.color(notification)
    readonly property int timeout: NotificationService.timeout(notification)
    readonly property date at: new Date()

    // A "default" action is the spec's click-through; it is not a button.
    readonly property var buttons: {
        const list = [];
        for (let i = 0; i < notification.actions.length; i++)
            if (notification.actions[i].identifier !== "default")
                list.push(notification.actions[i]);
        return list;
    }

    readonly property var defaultAction: {
        for (let i = 0; i < notification.actions.length; i++)
            if (notification.actions[i].identifier === "default")
                return notification.actions[i];
        return null;
    }

    readonly property var entry: notification.desktopEntry !== "" ? DesktopEntries.heuristicLookup(notification.desktopEntry) : null

    readonly property string icon: {
        if (notification.image !== "")
            return notification.image;
        const own = Quickshell.iconPath(notification.appIcon, true);
        if (own !== "")
            return own;
        return entry ? Quickshell.iconPath(entry.icon, true) : "";
    }

    readonly property string sender: notification.appName !== "" ? notification.appName : entry ? entry.name : "notification"

    // Grows to whatever is the last visible row.
    implicitHeight: (actions.visible ? actions.y + actions.height : body.y + body.height) + Theme.padding * 2
    color: Theme.panel
    opacity: 0

    Component.onCompleted: opacity = 1

    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    Timer {
        interval: root.timeout
        running: root.timeout > 0 && !hover.hovered
        onTriggered: root.notification.expire()
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.LeftButton && root.defaultAction)
                root.defaultAction.invoke();
            else
                root.notification.dismiss();
        }
    }

    Rectangle {
        width: 1
        color: root.ink

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
    }

    Corners {
        color: root.ink

        anchors {
            fill: parent
            margins: Theme.padding
            leftMargin: Theme.padding + 1
        }
    }

    Item {
        id: badge

        width: 32
        height: 32

        anchors {
            top: parent.top
            left: parent.left
            margins: Theme.padding * 2
            leftMargin: Theme.padding * 2 + 1
        }

        IconImage {
            anchors.fill: parent
            source: root.icon
            visible: root.icon !== ""
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            visible: root.icon === ""
            color: "transparent"
            border.width: 1
            border.color: root.ink

            Text {
                text: root.sender.charAt(0).toUpperCase()
                color: root.ink
                font.family: Theme.fontFamily
                font.pointSize: badge.height * 0.45
                font.bold: true
                anchors.centerIn: parent
            }
        }
    }

    Label {
        id: app

        text: root.sender
        elide: Text.ElideRight

        anchors {
            top: badge.top
            left: badge.right
            leftMargin: Theme.padding * 1.5
            right: time.left
            rightMargin: Theme.padding
        }
    }

    Label {
        id: time

        text: Qt.formatTime(root.at, "hh:mm")
        dim: true

        anchors {
            top: badge.top
            right: parent.right
            rightMargin: Theme.padding * 2
        }
    }

    Text {
        id: summary

        text: root.notification.summary
        color: Theme.text
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.bold: true

        anchors {
            top: app.bottom
            topMargin: Theme.padding / 2
            left: app.left
            right: time.right
        }
    }

    Text {
        id: body

        text: root.notification.body
        visible: text !== ""
        height: visible ? implicitHeight : 0
        color: Theme.subtext
        textFormat: Text.StyledText
        elide: Text.ElideRight
        maximumLineCount: 6
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeSmall
        onLinkActivated: link => Qt.openUrlExternally(link)

        anchors {
            top: summary.bottom
            topMargin: visible ? Theme.padding / 2 : 0
            left: app.left
            right: time.right
        }
    }

    Row {
        id: actions

        spacing: Theme.padding * 2
        visible: root.buttons.length > 0

        anchors {
            top: body.bottom
            topMargin: visible ? Theme.padding : 0
            left: app.left
        }

        Repeater {
            model: root.buttons

            Label {
                required property NotificationAction modelData

                text: modelData.text
                color: tap.pressed ? Theme.text : root.ink

                TapHandler {
                    id: tap

                    onTapped: modelData.invoke()
                }
            }
        }
    }
}
