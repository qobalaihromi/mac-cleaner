import SwiftUI

@main
struct MacCleanerGUIApp: App {
    var body: some Scene {
        WindowGroup("Mac Cleaner") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
