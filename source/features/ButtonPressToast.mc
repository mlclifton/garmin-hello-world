import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Proof point: shows a toast naming the physical button that was pressed.
module ButtonPressToast {

    function show(key as Number) as Void {
        var name = nameForKey(key);
        if (name != null) {
            System.println("ButtonPressToast: key=" + key + " recognized as " + name + " -> toast shown");
            WatchUi.showToast(name + " pressed", {});
        } else {
            System.println("ButtonPressToast: key=" + key + " not recognized -> no toast");
        }
    }

    function nameForKey(key as Number) as String? {
        if (key == WatchUi.KEY_UP) {
            return "UP";
        } else if (key == WatchUi.KEY_DOWN) {
            return "DOWN";
        } else if (key == WatchUi.KEY_ENTER) {
            return "ENTER";
        } else if (key == WatchUi.KEY_ESC) {
            return "BACK";
        } else if (key == WatchUi.KEY_MENU) {
            return "MENU";
        } else if (key == WatchUi.KEY_LIGHT) {
            return "LIGHT";
        } else if (key == WatchUi.KEY_START) {
            return "START";
        } else if (key == WatchUi.KEY_LAP) {
            return "LAP";
        } else if (key == WatchUi.KEY_MODE) {
            return "MODE";
        }

        return null;
    }

}
