import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class HelloWorldView extends WatchUi.View {

    const APP_VERSION = "2.2.0";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            "Hello World!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() - 10,
            Graphics.FONT_XTINY,
            "v" + APP_VERSION,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
