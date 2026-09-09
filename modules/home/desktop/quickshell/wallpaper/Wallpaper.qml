import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.config

// One background layer per connected screen showing Theme.wallpaper. Video
// files loop muted with the audio track skipped entirely; anything else is
// drawn as a still image. Every screen decodes its own copy of the video:
// a MediaPlayer feeds exactly one VideoOutput and windows do not share
// scene graphs.
Variants {
    model: Theme.screens

    PanelWindow {
        id: window

        required property ShellScreen modelData

        screen: modelData
        color: Theme.background
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "sgiath-wallpaper"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // A single binding picks the component. Splitting "is it set" and
        // "is it a video" into separate properties lets the Loader observe a
        // half-updated pair when the JSON (re)loads and briefly instantiate
        // the wrong component with the wrong source.
        Loader {
            anchors.fill: parent
            sourceComponent: Theme.wallpaper === "" ? null : /\.(mp4|webm|mkv|mov)$/i.test(Theme.wallpaper) ? videoWallpaper : imageWallpaper
        }

        Component {
            id: imageWallpaper

            Image {
                source: "file://" + Theme.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Component {
            id: videoWallpaper

            VideoOutput {
                id: output

                fillMode: VideoOutput.PreserveAspectCrop

                MediaPlayer {
                    source: "file://" + Theme.wallpaper
                    videoOutput: output
                    loops: MediaPlayer.Infinite
                    activeAudioTrack: -1
                    autoPlay: true
                }
            }
        }
    }
}
