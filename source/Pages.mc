import Toybox.Lang;
import Toybox.WatchUi;

//! Ordered list of the app's pages, plus the shared paging navigation
//! (WatchUi.switchToView + slide direction) so a page's delegate can move
//! to the next/previous page without knowing the others by name.
module Pages {

    const COUNT = 3;

    function build(index as Number) as [Views, InputDelegates] {
        if (index == 1) {
            return [ new CompassFaceView(), new CompassFaceDelegate() ];
        } else if (index == 2) {
            return [ new CompassBearingView(), new CompassBearingDelegate() ];
        }
        return [ new HelloWorldView(), new HelloWorldDelegate() ];
    }

    function goTo(index as Number, transition as WatchUi.SlideType) as Void {
        var page = build(index);
        WatchUi.switchToView(page[0], page[1], transition);
    }

}
