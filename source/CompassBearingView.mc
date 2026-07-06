import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.WatchUi;

//! Proof point: reads Toybox.Sensor's compass heading and renders the
//! current true-north bearing as degrees + a 16-point cardinal label.
//! Requires the "Sensor" permission (see manifest.xml).
class CompassBearingView extends WatchUi.View {

    private var _headingRadians as Float?;

    private const DIRECTIONS = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
    ];

    function initialize() {
        View.initialize();
        _headingRadians = null;
    }

    function onShow() as Void {
        Sensor.enableSensorEvents(method(:onSensor));
    }

    function onHide() as Void {
        Sensor.enableSensorEvents(null);
    }

    function onSensor(info as Sensor.Info) as Void {
        _headingRadians = info.heading;
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var centerY = dc.getHeight() / 2;
        var bearingText = "---°";
        var cardinalText = "no heading";

        if (_headingRadians != null) {
            var degrees = (_headingRadians * 180.0 / Math.PI).toNumber() % 360;
            if (degrees < 0) {
                degrees += 360;
            }
            bearingText = degrees.format("%03d") + "°";
            cardinalText = DIRECTIONS[((degrees + 11.25) / 22.5).toNumber() % 16];
        }

        dc.drawText(
            width / 2,
            centerY - 20,
            Graphics.FONT_NUMBER_MEDIUM,
            bearingText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            width / 2,
            centerY + 30,
            Graphics.FONT_MEDIUM,
            cardinalText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            width / 2,
            dc.getHeight() - 10,
            Graphics.FONT_XTINY,
            "Compass Bearing",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
