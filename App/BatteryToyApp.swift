import SwiftUI

@main
struct BatteryToyApp: App {
    @State private var lab = BatteryLab()
    var body: some Scene {
        WindowGroup {
            BatteryRootView(lab: lab)
                .preferredColorScheme(.dark)
                .tint(LabStyle.cyan)
        }
    }
}
