import QtQuick
import qs.config
import qs.components

// Full readout: header with sync state, one ProviderCard per account,
// error footer. Laid out for Theme.panelWidth; the window shows it only
// while hovered.
Item {
    id: root

    required property double now

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
        }

        Text {
            id: title

            text: "USAGE"
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
            text: "subscription capacity"
            dim: true

            anchors {
                top: title.bottom
                left: title.left
            }
        }

        Label {
            text: UsageService.busy ? "sync ··" : UsageService.error !== "" ? "sync failed" : "sync"
            color: UsageService.error !== "" && !UsageService.busy ? Theme.urgent : Theme.muted

            anchors {
                top: parent.top
                right: parent.right
                margins: Theme.padding * 1.5
            }
        }

        Text {
            text: UsageService.generatedAt ? Qt.formatDateTime(new Date(UsageService.generatedAt), "HH:mm:ss") : "--:--:--"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize

            anchors {
                bottom: parent.bottom
                right: parent.right
                margins: Theme.padding * 1.5
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: UsageService.refresh()
        }
    }

    Flickable {
        clip: true
        contentHeight: cards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        anchors {
            top: header.bottom
            topMargin: Theme.padding
            bottom: footer.top
            left: parent.left
            leftMargin: Theme.padding * 2 + 1
            right: parent.right
            rightMargin: Theme.padding * 2
        }

        Column {
            id: cards

            width: parent.width

            Repeater {
                model: UsageService.accounts

                ProviderCard {
                    required property var modelData
                    required property int index

                    account: modelData
                    ordinal: index + 1
                    now: root.now
                    width: cards.width
                }
            }
        }
    }

    Label {
        id: footer

        text: UsageService.error
        visible: text !== ""
        color: Theme.urgent
        elide: Text.ElideRight
        height: visible ? implicitHeight + Theme.padding * 2 : 0
        verticalAlignment: Text.AlignVCenter

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Theme.padding * 2
        }
    }
}
