import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Proof point: draws a simplified compass face (a ring with N/S/E/W at the
//! four cardinal points) plus a radar-style "hand" that sweeps continuously
//! at a fixed rate. The sweep is not driven by the compass sensor — see
//! CompassBearingView for the live-heading counterpart.
class CompassFaceView extends WatchUi.View {

    private const SWEEP_RPM = 10;
    private const SWEEP_PERIOD_MS = 60000 / SWEEP_RPM;
    private const SWEEP_RADIANS_PER_MS = 2 * Math.PI / SWEEP_PERIOD_MS;
    private const SWEEP_REDRAW_MS = 50;

    private var _sweepStartMs as Number = 0;
    private var _sweepTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _sweepStartMs = System.getTimer();
        _sweepTimer = new Timer.Timer();
        _sweepTimer.start(method(:onSweepTick), SWEEP_REDRAW_MS, true);
    }

    function onHide() as Void {
        if (_sweepTimer != null) {
            _sweepTimer.stop();
            _sweepTimer = null;
        }
    }

    function onSweepTick() as Void {
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var shortSide = width < height ? width : height;
        var radius = (shortSide / 2) - 24;

        dc.setPenWidth(2);
        dc.drawCircle(centerX, centerY, radius);

        drawLabel(dc, centerX, centerY - radius, "N");
        drawLabel(dc, centerX, centerY + radius, "S");
        drawLabel(dc, centerX + radius, centerY, "E");
        drawLabel(dc, centerX - radius, centerY, "W");

        drawSweepHand(dc, centerX, centerY, radius);

        dc.drawText(
            centerX,
            height - 10,
            Graphics.FONT_XTINY,
            "Compass Face",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawLabel(dc as Dc, x as Number, y as Number, text as String) as Void {
        dc.drawText(x, y, Graphics.FONT_MEDIUM, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Angle is derived from elapsed wall-clock time rather than incremented
    // per tick, so a delayed/dropped redraw can't slow the sweep down --
    // it'll just jump to catch up to where it should be. The modulo is
    // done on the millisecond count (Monkey C has no float '%') and also
    // keeps the angle bounded instead of growing (and losing precision)
    // for as long as this view stays on screen.
    private function drawSweepHand(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        var phaseMs = (System.getTimer() - _sweepStartMs) % SWEEP_PERIOD_MS;
        var angle = phaseMs * SWEEP_RADIANS_PER_MS;
        var endX = centerX + (radius * Math.sin(angle)).toNumber();
        var endY = centerY - (radius * Math.cos(angle)).toNumber();

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(centerX, centerY, endX, endY);
    }

}
