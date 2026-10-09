"""Match Whiteboard Dark to the sgiath.dev theme selected in T3 Code."""

import json
import re
import sys
from pathlib import Path

# Source: sgiath.dev/design-language/language/t3code.json.
# Keep alpha suffixes, light mode, and semantic diagram/diff colors intact.
COLORS = {
    "0c0f15": "050505",  # canvas
    "12161e": "0a0a0a",  # chrome, code, and overlays
    "1a1f29": "101012",  # controls and raised surfaces
    "1a1f2a": "1c1c1c",  # canvas grid
    "262c37": "1c1c1c",  # borders
    "39404d": "1c1c1c",  # widget borders
    "eef0f4": "e6e6e9",  # text
    "9199a8": "9d9da6",  # muted text
    "5f6776": "606069",  # faint text
    "343a46": "606069",  # line numbers and placeholders
    "5b7cff": "e25d52",  # accent and focus
    "1a2240": "101012",  # accent surface
}
COLOR = re.compile(
    r"(#|%23)(" + "|".join(COLORS) + r")([0-9a-f]{2})?(?![0-9a-f])",
    re.IGNORECASE,
)


def recolor(text):
    return COLOR.sub(
        lambda match: match[1] + COLORS[match[2].lower()] + (match[3] or ""), text
    )


app = Path(sys.argv[1])
theme = app / "extensions/review-themes/themes/review-dark.json"
styles = list((app / "out/vs/review/canvas/assets").glob("canvas-*.css"))
if len(styles) != 1:
    raise RuntimeError(f"Expected one Whiteboard canvas stylesheet, found {styles}")

for path in [theme, styles[0]]:
    original = path.read_text()
    for anchor in ["#0c0f15", "#5b7cff"]:
        if anchor not in original.lower():
            raise RuntimeError(f"Whiteboard palette changed: missing {anchor} in {path}")
    themed = recolor(original)
    if path == theme:
        colors = json.loads(themed)
        # T3's primary actions have dark text on the coral accent.
        colors["colors"].update(
            {
                "editorGroupHeader.tabsBackground": "#050505",
                "titleBar.activeBackground": "#050505",
                "titleBar.inactiveBackground": "#050505",
                "sideBar.background": "#050505",
                "editorWidget.background": "#141416",
                "editorHoverWidget.background": "#141416",
                "button.background": "#e25d52",
                "button.foreground": "#050505",
                "button.hoverBackground": "#e8756b",
                "textLink.foreground": "#e25d52",
                "textLink.activeForeground": "#e8756b",
                "panelTitle.activeBorder": "#e25d52",
            }
        )
        themed = json.dumps(colors, separators=(",", ":"))
    else:
        # These foregrounds belong to the dark canvas's :scope palette.
        themed = themed.replace("--on-accent:#fff;", "--on-accent:#050505;")
        themed = themed.replace(
            "--text-selection-color:#fff;", "--text-selection-color:#e6e6e9;"
        )
    path.write_text(themed)

print("Applied T3 sgiath.dev colors to Whiteboard Dark and its canvas")
