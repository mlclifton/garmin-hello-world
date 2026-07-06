import Toybox.Lang;
import Toybox.WatchUi;

class HelloWorldDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.requestUpdate();
        return true;
    }

}
