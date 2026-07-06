import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class HelloWorldDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
        System.println(
            "Key codes — UP=" + WatchUi.KEY_UP
            + " DOWN=" + WatchUi.KEY_DOWN
            + " ENTER=" + WatchUi.KEY_ENTER
            + " ESC=" + WatchUi.KEY_ESC
            + " MENU=" + WatchUi.KEY_MENU
            + " LIGHT=" + WatchUi.KEY_LIGHT
            + " START=" + WatchUi.KEY_START
        );
    }

    function onSelect() as Boolean {
        System.println("HelloWorldDelegate.onSelect fired");
        ButtonPressToast.show(WatchUi.KEY_ENTER);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        System.println("HelloWorldDelegate.onBack fired");
        ButtonPressToast.show(WatchUi.KEY_ESC);
        // Exit directly instead of delegating to the default popView
        // behavior: the Simulator can dispatch Back twice for one physical
        // press (once as a direct behavior shortcut, once via a raw onKey
        // hardware event), and a second default pop/exit on an
        // already-exiting root view is what was crashing the app.
        // System.exit() is safe to call more than once.
        System.exit();
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        System.println(
            "HelloWorldDelegate.onKey fired: key=" + keyEvent.getKey()
            + " type=" + keyEvent.getType()
        );
        ButtonPressToast.show(keyEvent.getKey());
        return BehaviorDelegate.onKey(keyEvent) as Boolean;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        System.println("HelloWorldDelegate.onTap fired (touch simulated a tap, not a key press)");
        return BehaviorDelegate.onTap(clickEvent) as Boolean;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        System.println(
            "HelloWorldDelegate.onSwipe fired: direction=" + swipeEvent.getDirection()
            + " (touch simulated a swipe, not a key press)"
        );
        return BehaviorDelegate.onSwipe(swipeEvent) as Boolean;
    }

}
