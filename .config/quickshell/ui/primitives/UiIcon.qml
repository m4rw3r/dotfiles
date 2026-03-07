import QtQuick
import "../../theme"

Canvas {
  id: root

  property string name: "chevron-right"
  property color strokeColor: Theme.textMuted
  property real stroke: 1.75

  implicitWidth: 20
  implicitHeight: 20
  contextType: "2d"
  renderTarget: Canvas.Image
  renderStrategy: Canvas.Immediate

  onNameChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onStrokeChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    const ctx = getContext("2d");
    ctx.reset();
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = stroke;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    const w = width;
    const h = height;

    function roundedRect(x, y, rectWidth, rectHeight, radius) {
      ctx.beginPath();
      ctx.moveTo(x + radius, y);
      ctx.lineTo(x + rectWidth - radius, y);
      ctx.arcTo(x + rectWidth, y, x + rectWidth, y + radius, radius);
      ctx.lineTo(x + rectWidth, y + rectHeight - radius);
      ctx.arcTo(x + rectWidth, y + rectHeight, x + rectWidth - radius, y + rectHeight, radius);
      ctx.lineTo(x + radius, y + rectHeight);
      ctx.arcTo(x, y + rectHeight, x, y + rectHeight - radius, radius);
      ctx.lineTo(x, y + radius);
      ctx.arcTo(x, y, x + radius, y, radius);
    }

    if (name === "chevron-right") {
      ctx.beginPath();
      ctx.moveTo(w * 0.36, h * 0.24);
      ctx.lineTo(w * 0.66, h * 0.5);
      ctx.lineTo(w * 0.36, h * 0.76);
      ctx.stroke();
      return;
    }

    if (name === "chevron-down") {
      ctx.beginPath();
      ctx.moveTo(w * 0.26, h * 0.38);
      ctx.lineTo(w * 0.5, h * 0.68);
      ctx.lineTo(w * 0.74, h * 0.38);
      ctx.stroke();
      return;
    }

    if (name === "check") {
      ctx.beginPath();
      ctx.moveTo(w * 0.22, h * 0.54);
      ctx.lineTo(w * 0.42, h * 0.72);
      ctx.lineTo(w * 0.78, h * 0.28);
      ctx.stroke();
      return;
    }

    if (name === "restart") {
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.54, h * 0.23, Math.PI * 0.12, Math.PI * 1.64, true);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.35, h * 0.18);
      ctx.lineTo(w * 0.58, h * 0.18);
      ctx.lineTo(w * 0.48, h * 0.34);
      ctx.stroke();
      return;
    }

    if (name === "logout") {
      roundedRect(w * 0.18, h * 0.24, w * 0.34, h * 0.52, h * 0.08);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.42, h * 0.5);
      ctx.lineTo(w * 0.8, h * 0.5);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.62, h * 0.32);
      ctx.lineTo(w * 0.8, h * 0.5);
      ctx.lineTo(w * 0.62, h * 0.68);
      ctx.stroke();
      return;
    }

    if (name === "sun") {
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.5, h * 0.17, 0, Math.PI * 2, false);
      ctx.stroke();
      for (let i = 0; i < 8; i += 1) {
        const angle = (Math.PI * 2 * i) / 8;
        const inner = h * 0.3;
        const outer = h * 0.42;
        ctx.beginPath();
        ctx.moveTo(w * 0.5 + Math.cos(angle) * inner, h * 0.5 + Math.sin(angle) * inner);
        ctx.lineTo(w * 0.5 + Math.cos(angle) * outer, h * 0.5 + Math.sin(angle) * outer);
        ctx.stroke();
      }
      return;
    }

    if (name === "lock") {
      roundedRect(w * 0.26, h * 0.44, w * 0.48, h * 0.32, h * 0.06);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.42, h * 0.14, Math.PI, 0, false);
      ctx.stroke();
      return;
    }

    if (name === "battery" || name === "battery-charging") {
      roundedRect(w * 0.18, h * 0.28, w * 0.56, h * 0.44, h * 0.06);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.74, h * 0.42);
      ctx.lineTo(w * 0.82, h * 0.42);
      ctx.lineTo(w * 0.82, h * 0.58);
      ctx.lineTo(w * 0.74, h * 0.58);
      ctx.stroke();

      if (name === "battery-charging") {
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.32);
        ctx.lineTo(w * 0.4, h * 0.5);
        ctx.lineTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.44, h * 0.68);
        ctx.lineTo(w * 0.6, h * 0.46);
        ctx.lineTo(w * 0.5, h * 0.46);
        ctx.closePath();
        ctx.stroke();
      }
      return;
    }

    if (name === "power") {
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.55, h * 0.22, Math.PI * 0.8, Math.PI * 2.2, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.5, h * 0.16);
      ctx.lineTo(w * 0.5, h * 0.42);
      ctx.stroke();
      return;
    }

    if (name === "moon") {
      ctx.beginPath();
      ctx.arc(w * 0.46, h * 0.5, h * 0.2, Math.PI * 0.28, Math.PI * 1.72, false);
      ctx.arc(w * 0.56, h * 0.45, h * 0.18, Math.PI * 1.15, Math.PI * 0.82, true);
      ctx.stroke();
      return;
    }

    if (name === "wifi") {
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.68, h * 0.03, 0, Math.PI * 2, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.6, h * 0.12, Math.PI * 1.18, Math.PI * 1.82, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.6, h * 0.22, Math.PI * 1.18, Math.PI * 1.82, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.6, h * 0.32, Math.PI * 1.18, Math.PI * 1.82, false);
      ctx.stroke();
      return;
    }

    if (name === "bluetooth") {
      ctx.beginPath();
      ctx.moveTo(w * 0.5, h * 0.16);
      ctx.lineTo(w * 0.5, h * 0.84);
      ctx.moveTo(w * 0.5, h * 0.16);
      ctx.lineTo(w * 0.69, h * 0.34);
      ctx.lineTo(w * 0.5, h * 0.5);
      ctx.lineTo(w * 0.69, h * 0.66);
      ctx.lineTo(w * 0.5, h * 0.84);
      ctx.moveTo(w * 0.5, h * 0.5);
      ctx.lineTo(w * 0.29, h * 0.3);
      ctx.moveTo(w * 0.5, h * 0.5);
      ctx.lineTo(w * 0.29, h * 0.7);
      ctx.stroke();
      return;
    }

    if (name === "gauge") {
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.62, h * 0.22, Math.PI, Math.PI * 2, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.5, h * 0.62);
      ctx.lineTo(w * 0.67, h * 0.45);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.5, h * 0.62, h * 0.03, 0, Math.PI * 2, false);
      ctx.stroke();
      return;
    }

    if (name === "keyboard") {
      roundedRect(w * 0.18, h * 0.34, w * 0.64, h * 0.32, h * 0.05);
      ctx.stroke();
      for (let row = 0; row < 2; row += 1) {
        for (let col = 0; col < 5; col += 1) {
          ctx.beginPath();
          ctx.arc(w * (0.28 + col * 0.1), h * (0.44 + row * 0.1), 0.6, 0, Math.PI * 2, false);
          ctx.stroke();
        }
      }
      ctx.beginPath();
      ctx.moveTo(w * 0.34, h * 0.6);
      ctx.lineTo(w * 0.66, h * 0.6);
      ctx.stroke();
      return;
    }

    ctx.beginPath();
    ctx.moveTo(w * 0.18, h * 0.42);
    ctx.lineTo(w * 0.34, h * 0.42);
    ctx.lineTo(w * 0.48, h * 0.3);
    ctx.lineTo(w * 0.48, h * 0.7);
    ctx.lineTo(w * 0.34, h * 0.58);
    ctx.lineTo(w * 0.18, h * 0.58);
    ctx.closePath();
    ctx.stroke();

    if (name === "speaker") {
      ctx.beginPath();
      ctx.arc(w * 0.48, h * 0.5, h * 0.13, -0.9, 0.9, false);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(w * 0.48, h * 0.5, h * 0.24, -0.9, 0.9, false);
      ctx.stroke();
      return;
    }

    if (name === "speaker-muted") {
      ctx.beginPath();
      ctx.moveTo(w * 0.58, h * 0.34);
      ctx.lineTo(w * 0.8, h * 0.66);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.8, h * 0.34);
      ctx.lineTo(w * 0.58, h * 0.66);
      ctx.stroke();
    }
  }
}
