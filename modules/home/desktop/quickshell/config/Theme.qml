pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette, fonts and wallpaper come from Home Manager (modules/home/desktop/quickshell.nix
// renders themes/sgiath.yaml + Stylix fonts into ~/.config/sgiath-shell/theme.json).
// Semantic names live here; the JSON only carries raw base16 slots.
Singleton {
    id: root

    readonly property color background: palette.base00
    readonly property color surface: palette.base01
    readonly property color overlay: palette.base02
    readonly property color muted: palette.base03
    readonly property color subtext: palette.base04
    readonly property color text: palette.base05

    readonly property color red: palette.base08
    readonly property color orange: palette.base09
    readonly property color yellow: palette.base0A
    readonly property color green: palette.base0B
    readonly property color cyan: palette.base0C
    readonly property color blue: palette.base0D
    readonly property color purple: palette.base0E
    readonly property color brown: palette.base0F

    readonly property color accent: brown
    readonly property color urgent: red

    // Meter color by consumed fraction: quiet until it matters.
    function load(fraction) {
        return fraction >= 1 ? red : fraction >= 0.75 ? accent : text;
    }

    // Hairlines and frames; panels sit on a near-opaque background so the
    // blurred wallpaper only bleeds through as depth, never as noise.
    readonly property color line: overlay
    readonly property color panel: Qt.alpha(background, 0.9)

    readonly property string fontFamily: typeface.family
    readonly property int fontSize: typeface.size
    readonly property int fontSizeSmall: Math.max(7, typeface.size - 3)
    readonly property int fontSizeLarge: typeface.size + 6
    readonly property real letterSpacing: 1.5

    // Absolute path of an image or video; empty when no wallpaper is configured.
    readonly property string wallpaper: settings.wallpaper

    // Terminal emulator that hosts Terminal=true desktop entries.
    readonly property string terminal: settings.terminal

    // Desktop entry ids the launcher keeps on top.
    readonly property list<string> pinned: settings.pinned

    // Screens the shell draws on; ignored outputs get nothing, not even a
    // wallpaper, so one fullscreen window can own them edge to edge.
    readonly property var screens: {
        const list = [];
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (settings.ignoredOutputs.indexOf(Quickshell.screens[i].name) === -1)
                list.push(Quickshell.screens[i]);
        return list;
    }

    // Where single-instance surfaces go (notifications, usage panel, crash
    // drawer): the configured output, else the widest screen.
    readonly property var mainScreen: {
        let best = null;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === settings.mainOutput)
                return screens[i];
            if (!best || screens[i].width > best.width)
                best = screens[i];
        }
        return best;
    }

    // Ultrawide layout: everything lives on the vertical edges.
    readonly property int railWidth: 96
    readonly property int panelWidth: 380
    readonly property int launcherWidth: 560
    readonly property int padding: 8
    readonly property int spacing: 6

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/sgiath-shell/theme.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: settings

            property string wallpaper: ""
            property list<string> ignoredOutputs: []
            property string mainOutput: ""

            property string terminal: "xterm"
            property list<string> pinned: []

            property JsonObject colors: JsonObject {
                id: palette

                property string base00: "#000000"
                property string base01: "#121212"
                property string base02: "#585858"
                property string base03: "#888888"
                property string base04: "#c8c8c8"
                property string base05: "#ffffff"
                property string base06: "#ffffff"
                property string base07: "#ffffff"
                property string base08: "#fa7883"
                property string base09: "#ffc387"
                property string base0A: "#ff9470"
                property string base0B: "#98c379"
                property string base0C: "#8af5ff"
                property string base0D: "#6bb8ff"
                property string base0E: "#e799ff"
                property string base0F: "#b3684f"
            }

            property JsonObject font: JsonObject {
                id: typeface

                property string family: "monospace"
                property int size: 12
            }
        }
    }
}
