import SwiftUI
import Network
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

@Observable
class WiFiManager {
    // MARK: - Published Properties
    var isScanning: Bool = false
    var availableNetworks: [WiFiNetwork] = []
    var currentNetwork: WiFiNetwork?
    var connectionStatus: ConnectionStatus = .disconnected
    var errorMessage: String?

    // MARK: - Private Properties
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "WiFiMonitor")

    enum ConnectionStatus: String, CaseIterable {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
        case failed = "Failed"

        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .orange
            case .connected: return .bambuPrimary
            case .failed: return .red
            }
        }
    }

    // MARK: - Initialization
    init() {
        startMonitoring()
        getCurrentNetwork()
    }

    // MARK: - Network Monitoring
    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path: path)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func updateConnectionStatus(path: Network.NWPath) {
        if path.status == .satisfied && path.usesInterfaceType(.wifi) {
            connectionStatus = .connected
            getCurrentNetwork()
        } else {
            connectionStatus = .disconnected
            currentNetwork = nil
        }
    }

    // MARK: - Network Discovery
    func scanForNetworks() async {
        guard !isScanning else { return }

        await MainActor.run {
            isScanning = true
            errorMessage = nil
        }

        do {
            // Request location permission if needed for WiFi scanning
            let networks = try await discoverNetworks()

            await MainActor.run {
                self.availableNetworks = networks
                self.isScanning = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isScanning = false
            }
        }
    }

    private func discoverNetworks() async throws -> [WiFiNetwork] {
        // On iOS, we can't directly scan for WiFi networks due to privacy restrictions
        // Instead, we'll simulate discovery with common network patterns and use
        // Bonjour to discover Bambu printers

        var networks: [WiFiNetwork] = []

        // Discover Bambu printers on the current network using Bonjour
        let bambuDevices = await discoverBambuPrinters()

        // Add networks based on discovered printers
        for device in bambuDevices {
            let network = WiFiNetwork(
                ssid: "Network with \(device.name)",
                rssi: -50, // Simulated signal strength
                security: .wpa2,
                bambuDevice: device
            )
            networks.append(network)
        }

        // Add current network if available
        if let current = currentNetwork {
            networks.insert(current, at: 0)
        }

        return networks
    }

    private func discoverBambuPrinters() async -> [BambuDevice] {
        return await withCheckedContinuation { continuation in
            let browser = NetServiceBrowser()
            var devices: [BambuDevice] = []
            let delegate = BonjourDiscoveryDelegate { discoveredDevices in
                devices = discoveredDevices
                continuation.resume(returning: devices)
            }

            browser.delegate = delegate
            browser.searchForServices(ofType: "_bambu._tcp", inDomain: "local.")

            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                browser.stop()
                if devices.isEmpty {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Current Network Info
    private func getCurrentNetwork() {
        guard connectionStatus == .connected else { return }

        // Get current WiFi network info
        if let ssid = getCurrentSSID() {
            currentNetwork = WiFiNetwork(
                ssid: ssid,
                rssi: -45, // Simulated - iOS doesn't provide actual RSSI
                security: .wpa2,
                bambuDevice: nil
            )
        }
    }

    private func getCurrentSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }

        for interface in interfaces {
            guard let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                  let ssid = networkInfo[kCNNetworkInfoKeySSID as String] as? String else {
                continue
            }
            return ssid
        }
        return nil
    }

    // MARK: - Network Connection
    func connectToNetwork(_ network: WiFiNetwork, password: String? = nil) async {
        await MainActor.run {
            connectionStatus = .connecting
            errorMessage = nil
        }

        do {
            try await performConnection(to: network, password: password)

            await MainActor.run {
                self.connectionStatus = .connected
                self.currentNetwork = network
            }
        } catch {
            await MainActor.run {
                self.connectionStatus = .failed
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func performConnection(to network: WiFiNetwork, password: String?) async throws {
        // On iOS, we can't programmatically connect to WiFi networks
        // This would require MDM or special entitlements
        // For now, we'll simulate the connection process

        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay

        // In a real implementation, you would:
        // 1. Use NEHotspotConfiguration for known networks
        // 2. Present system WiFi settings if needed
        // 3. Guide user through manual connection process

        // Simulate success for demo purposes
        if network.ssid.lowercased().contains("test") {
            throw NetworkError.invalidPassword
        }
    }

    // MARK: - WiFi Signal Quality
    func getSignalQuality() -> Int {
        // Return simulated signal strength (0-3)
        switch connectionStatus {
        case .connected:
            return 3 // Strong signal
        case .connecting:
            return 2
        default:
            return 0
        }
    }

    // MARK: - Cleanup
    deinit {
        pathMonitor.cancel()
    }
}

// MARK: - Data Models
struct WiFiNetwork: Identifiable, Equatable {
    let id = UUID()
    let ssid: String
    let rssi: Int // Signal strength in dBm
    let security: SecurityType
    let bambuDevice: BambuDevice?

    var signalStrength: Int {
        // Convert RSSI to 0-3 scale
        if rssi >= -50 { return 3 }
        if rssi >= -65 { return 2 }
        if rssi >= -80 { return 1 }
        return 0
    }

    var isSecure: Bool {
        security != .none
    }

    enum SecurityType {
        case none
        case wep
        case wpa
        case wpa2
        case wpa3
    }
}

struct BambuDevice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let model: String
    let ipAddress: String
    let port: Int
    let accessCode: String?

    var isConfigured: Bool {
        accessCode != nil
    }
}

enum NetworkError: LocalizedError {
    case invalidPassword
    case networkNotFound
    case connectionTimeout
    case insufficientPermissions

    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            return "Invalid network password"
        case .networkNotFound:
            return "Network not found"
        case .connectionTimeout:
            return "Connection timed out"
        case .insufficientPermissions:
            return "Insufficient permissions to connect to network"
        }
    }
}

// MARK: - Bonjour Discovery Delegate
private class BonjourDiscoveryDelegate: NSObject, NetServiceBrowserDelegate {
    private var completion: (([BambuDevice]) -> Void)?
    private var discoveredServices: [NetService] = []

    init(completion: @escaping ([BambuDevice]) -> Void) {
        self.completion = completion
        super.init()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        discoveredServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)

        if !moreComing {
            // Convert services to BambuDevice objects
            let devices: [BambuDevice] = discoveredServices.compactMap { service in
                guard let addresses = service.addresses,
                      let address = addresses.first else { return nil }

                let ipAddress = extractIPAddress(from: address) ?? "Unknown"

                return BambuDevice(
                    name: service.name,
                    model: "Bambu A1 mini", // Would parse from TXT records
                    ipAddress: ipAddress,
                    port: service.port,
                    accessCode: nil
                )
            }
            completion?(devices)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        completion?([])
    }

    private func extractIPAddress(from data: Data) -> String? {
        let address = data.withUnsafeBytes { bytes in
            bytes.bindMemory(to: sockaddr.self).first
        }

        guard let addr = address else { return nil }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var mutableAddr = addr
        let result = getnameinfo(&mutableAddr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)

        return result == 0 ? String(cString: hostname) : nil
    }
}

extension BonjourDiscoveryDelegate: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        // Service resolved - IP address is now available
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // Handle resolution failure
    }
}