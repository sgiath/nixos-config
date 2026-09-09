import QtQuick
import qs.config

// Reticle-style ring: hairline track with quarter ticks, butt-capped arc.
Canvas {
    id: root

    property real fraction: 0
    property color color: Theme.text
    property int stroke: 2

    onFractionChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const cx = width / 2;
        const cy = height / 2;
        const r = Math.min(cx, cy) - stroke;
        const tau = Math.PI * 2;
        const start = -Math.PI / 2;

        ctx.reset();
        ctx.lineCap = "butt";

        ctx.lineWidth = 1;
        ctx.strokeStyle = Theme.line;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, tau);
        ctx.stroke();

        for (let i = 0; i < 4; i++) {
            const a = start + i * tau / 4;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(a) * (r - stroke - 2), cy + Math.sin(a) * (r - stroke - 2));
            ctx.lineTo(cx + Math.cos(a) * (r - stroke - 5), cy + Math.sin(a) * (r - stroke - 5));
            ctx.stroke();
        }

        const f = Math.min(1, Math.max(0, fraction));
        if (f > 0) {
            ctx.lineWidth = stroke;
            ctx.strokeStyle = color;
            ctx.beginPath();
            ctx.arc(cx, cy, r, start, start + tau * f);
            ctx.stroke();
        }
    }
}
