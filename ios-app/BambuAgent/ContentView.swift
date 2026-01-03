import SwiftUI

struct ContentView: View {
    @Environment(PrinterManager.self) private var printerManager
    @Environment(WiFiManager.self) private var wifiManager
    @Environment(APIService.self) private var apiService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            PrinterStatusView()
                .tabItem {
                    Label("Printer", systemImage: "printer.fill")
                }
                .tag(1)
                .badge(printerManager.connectionStatus == .connected ? nil : "!")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.bambuPrimary)
        .onAppear {
            // Initialize services
            Task {
                await printerManager.scanForPrinters()
                await wifiManager.scanForNetworks()
                apiService.checkServerConnection()
            }
        }
    }
}