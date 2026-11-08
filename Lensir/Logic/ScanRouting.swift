//
//  ScanRouting.swift
//  Lensir
//
//  What lensir://scan does to the screen, as a plain function so it's tested.
//  Whatever is open (the result or Make drawer, History, the photo list) closes, and
//  the opening animation gets out of the way: someone who pressed a button
//  for the camera wants the camera.
//

nonisolated enum ScanRouting {
    enum Splash: Equatable {
        /// Already over: nothing to do.
        case none
        /// Not started yet (a cold launch): play the quick version.
        case quick
        /// Playing (the link arrived late in a cold launch): skip to the end,
        /// as a tap does.
        case skip
    }

    struct Plan: Equatable {
        var splash: Splash
        var closeDrawer: Bool
        var closeHistory: Bool
        var closePhotoList: Bool
    }

    static func plan(for link: LensirLink, splashDone: Bool, splashStarted: Bool,
                     hasDrawer: Bool, showingHistory: Bool, showingPhotoList: Bool) -> Plan {
        switch link {
        case .scan:
            Plan(splash: splashDone ? .none : (splashStarted ? .skip : .quick),
                 closeDrawer: hasDrawer,
                 closeHistory: showingHistory,
                 closePhotoList: showingPhotoList)
        }
    }
}
