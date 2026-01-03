import SwiftUI

@main
struct BambuAgentApp: App {
    @State private var printerManager = PrinterManager()
    @State private var wifiManager = WiFiManager()
    @State private var apiService = APIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(printerManager)
                .environment(wifiManager)
                .environment(apiService)
                .preferredColorScheme(.dark)
        }
    }
}