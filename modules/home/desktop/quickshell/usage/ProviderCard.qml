import QtQuick
import qs.config
import qs.components

// One account: ordinal, provider, owner, headline gauge, then a meter per limit.
Item {
    id: root

    required property var account
    required property int ordinal
    required property double now

    implicitHeight: body.implicitHeight + Theme.padding * 5

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.line
        anchors.bottom: parent.bottom
    }

    Column {
        id: body

        spacing: Theme.padding

        anchors {
            top: parent.top
            topMargin: Theme.padding * 2.5
            left: parent.left
            right: parent.right
        }

        Item {
            width: parent.width
            height: gauge.height

            Label {
                id: ordinalLabel

                text: (root.ordinal < 10 ? "0" : "") + root.ordinal
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: name

                text: root.account.provider
                color: Theme.text
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase

                anchors {
                    left: ordinalLabel.right
                    leftMargin: Theme.padding * 1.5
                    verticalCenter: parent.verticalCenter
                }
            }

            Label {
                text: root.account.owner
                dim: true
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
                font.capitalization: Font.MixedCase

                anchors {
                    left: name.right
                    leftMargin: Theme.padding * 1.5
                    right: gauge.left
                    rightMargin: Theme.padding * 1.5
                    verticalCenter: parent.verticalCenter
                }
            }

            Gauge {
                id: gauge

                width: 26
                height: 26
                fraction: root.account.worst
                color: Theme.load(root.account.worst)
                anchors.right: parent.right
            }
        }

        Repeater {
            model: root.account.limits

            LimitRow {
                required property var modelData

                limit: modelData
                now: root.now
                width: body.width
            }
        }
    }
}
