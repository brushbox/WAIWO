import SwiftUI

@main
struct WAIWOApp: App {
    var body: some Scene {
        MenuBarExtra("WAIWO", systemImage: "checklist") {
            Text("WAIWO is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
