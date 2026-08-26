import SwiftUI

@main
struct QuickMailApp: App {
    init() {
        QuickMailFontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
