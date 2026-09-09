import QtQuick
import qs.config
import qs.components

// Rail-width digest, styled after the rail: title on top, one cell per
// account with its headline ring, provider and countdown, sync state
// pinned to the bottom where the rail keeps its clock.
Item {
    id: root

    required property double now

    Column {
        id: head

        spacing: Theme.spacing

        anchors {
            top: parent.top
            topMargin: Theme.padding * 2
            left: parent.left
            leftMargin: 1
            right: parent.right
        }

        Label {
            text: "usage"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            width: parent.width - 2 * Theme.padding
            height: 1
            color: Theme.line
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: head
        cursorShape: Qt.PointingHandCursor
        onClicked: UsageService.refresh()
    }

    Item {
        clip: true

        anchors {
            top: head.bottom
            topMargin: Theme.padding * 2
            bottom: foot.top
            bottomMargin: Theme.padding
            left: parent.left
            leftMargin: 1
            right: parent.right
        }

        Column {
            spacing: Theme.spacing
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: UsageService.accounts

                Rectangle {
                    id: cell

                    required property var modelData

                    readonly property color tone: Theme.load(modelData.worst)

                    width: Theme.railWidth - 2 * Theme.padding - 1
                    height: body.implicitHeight + Theme.padding * 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.line

                    Column {
                        id: body

                        spacing: 4
                        anchors.centerIn: parent

                        Gauge {
                            width: 48
                            height: 48
                            fraction: cell.modelData.worst
                            color: cell.tone
                            anchors.horizontalCenter: parent.horizontalCenter

                            Label {
                                text: Math.round(cell.modelData.worst * 100) + "%"
                                color: cell.tone
                                font.letterSpacing: 0
                                anchors.centerIn: parent
                            }
                        }

                        Label {
                            text: cell.modelData.provider.split(" ")[0]
                            width: cell.width - Theme.padding
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.letterSpacing: 0
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Label {
                            text: cell.modelData.worstResetsAt ? "T-" + UsageService.formatReset(cell.modelData.worstResetsAt, root.now) : ""
                            visible: text !== ""
                            dim: true
                            font.letterSpacing: 0
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    Label {
        id: foot

        text: UsageService.busy ? "··" : UsageService.error !== "" ? "sync failed" : UsageService.generatedAt ? Qt.formatDateTime(new Date(UsageService.generatedAt), "HH:mm") : "--:--"
        color: UsageService.error !== "" && !UsageService.busy ? Theme.urgent : Theme.muted
        width: parent.width - 2 * Theme.padding - 1
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter

        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.padding * 2
            horizontalCenter: parent.horizontalCenter
        }
    }
}
