import QtQuick
import qs.Theme

// Small rolling-window line graph. docs/02-bar.md asks for threshold lines
// at 50%/80% too — deferred until a metric actually needs highlighting;
// this is deliberately just the line for now.
Canvas {
    id: root
    property var history: []
    property color lineColor: Theme.color.accent

    onHistoryChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (history.length < 2)
            return;

        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        const stepX = width / (history.length - 1);
        for (let i = 0; i < history.length; i++) {
            const x = i * stepX;
            const y = height - history[i] * height;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
