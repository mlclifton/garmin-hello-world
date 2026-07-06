import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HelloWorldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new HelloWorldView(), new HelloWorldDelegate() ];
    }

}

function getApp() as HelloWorldApp {
    return Application.getApp() as HelloWorldApp;
}
