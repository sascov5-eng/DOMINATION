import SwiftUI

@main
struct OutpostApp: App {
    var body: some Scene {
        WindowGroup {
            GameRootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
