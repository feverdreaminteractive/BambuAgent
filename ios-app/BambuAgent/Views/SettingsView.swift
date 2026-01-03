import SwiftUI

struct SettingsView: View {
    @Environment(APIService.self) private var apiService
    @Environment(WiFiManager.self) private var wifiManager
    @Environment(PrinterManager.self) private var printerManager

    @State private var serverURL: String = ""
    @State private var showingServerURLAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Server Configuration
                Section("Backend Server") {
                    HStack {
                        Label("Server URL", systemImage: "server.rack")
                        Spacer()
                        Text(apiService.serverURL.absoluteString)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        serverURL = apiService.serverURL.absoluteString
                        showingServerURLAlert = true
                    }

                    HStack {
                        Label("Connection", systemImage: apiService.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Spacer()
                        Text(apiService.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(apiService.isConnected ? .green : .red)
                            .font(.caption)
                    }

                    Button("Test Connection") {
                        apiService.checkServerConnection()
                    }
                    .disabled(apiService.isConnected)
                }

                // WiFi Information
                Section("Network") {
                    if let currentNetwork = wifiManager.currentNetwork {
                        HStack {
                            Label("Current Network", systemImage: "wifi")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(currentNetwork.ssid)
                                    .font(.caption)
                                WiFiSignalIndicator(signalStrength: currentNetwork.signalStrength)
                            }
                        }
                    } else {
                        Label("No WiFi Connection", systemImage: "wifi.slash")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(wifiManager.connectionStatus.rawValue)
                            .foregroundColor(wifiManager.connectionStatus.color)
                            .font(.caption)
                    }

                    Button("Scan Networks") {
                        Task {
                            await wifiManager.scanForNetworks()
                        }
                    }
                    .disabled(wifiManager.isScanning)
                }

                // Printer Information
                Section("Printer") {
                    if let printer = printerManager.connectedPrinter {
                        HStack {
                            Label("Connected Printer", systemImage: "printer.fill")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(printer.displayName)
                                    .font(.caption)
                                Text(printer.ipAddress)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Label("Status", systemImage: printer.status.state.systemImage)
                            Spacer()
                            Text(printer.status.state.displayName)
                                .foregroundColor(printer.status.state.color)
                                .font(.caption)
                        }
                    } else {
                        Label("No Printer Connected", systemImage: "printer.slash")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Discovered Printers", systemImage: "magnifyingglass")
                        Spacer()
                        Text("\(printerManager.printers.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // App Information
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text("1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/your-repo/bambu-agent")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                }

                // Debug Section
                Section("Debug") {
                    Button("Clear Cache") {
                        // TODO: Implement cache clearing
                        HapticFeedback.light()
                    }

                    Button("Reset Settings") {
                        // TODO: Implement settings reset
                        HapticFeedback.medium()
                    }
                    .foregroundColor(.red)

                    if let errorMessage = apiService.errorMessage {
                        VStack(alignment: .leading) {
                            Text("Last Error:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Server URL", isPresented: $showingServerURLAlert) {
                TextField("http://192.168.1.50:8000", text: $serverURL)
                    .keyboardType(.URL)
                Button("Cancel", role: .cancel) { }
                Button("Update") {
                    apiService.updateServerURL(serverURL)
                }
            } message: {
                Text("Enter the backend server URL (e.g., http://192.168.1.50:8000)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(APIService())
        .environment(WiFiManager())
        .environment(PrinterManager())
}