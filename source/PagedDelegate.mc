import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Base delegate shared by every page: UP/DOWN cycle through pages (looping
//! at the ends). BACK only logs — it deliberately does not pop/exit, since
//! docs/TIL.md documents the default popView behavior crashing when it
//! double-fires on a root view.
class PagedDelegate extends WatchUi.BehaviorDelegate {

    private var _index as Number;

    function initialize(index as Number) {
        BehaviorDelegate.initialize();
        _index = index;
    }

    function onNextPage() as Boolean {
        Pages.goTo((_index + 1) % Pages.COUNT, WatchUi.SLIDE_LEFT);
        return true;
    }

    function onPreviousPage() as Boolean {
        Pages.goTo((_index - 1 + Pages.COUNT) % Pages.COUNT, WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() as Boolean {
        System.println("PagedDelegate.onBack fired (page " + _index + ")");
        ButtonPressToast.show(WatchUi.KEY_ESC);
        return true;
    }

    // fenix847mm/this Simulator combo doesn't auto-translate the physical
    // UP/DOWN keys into onPreviousPage()/onNextPage() (confirmed by
    // instrumenting onKey: it fires for UP/DOWN, so the framework's
    // built-in behavior mapping never claimed them first). Handle them
    // directly here rather than relying on that translation.
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            return onPreviousPage();
        } else if (key == WatchUi.KEY_DOWN) {
            return onNextPage();
        }
        return BehaviorDelegate.onKey(keyEvent) as Boolean;
    }

}
