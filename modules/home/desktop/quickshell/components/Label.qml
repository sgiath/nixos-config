import QtQuick
import qs.config

// Tracked uppercase monospace caption; the readout voice of every panel.
Text {
    property bool dim: false

    color: dim ? Theme.muted : Theme.subtext
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSizeSmall
    font.letterSpacing: Theme.letterSpacing
    font.capitalization: Font.AllUppercase
}
