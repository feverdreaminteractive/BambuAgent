import SwiftUI
import Network
import Foundation

@Observable
class PrinterManager {
    // MARK: - Published Properties
    var printers: [BambuPrinter] = []
    var connectedPrinter: BambuPrinter?
    var connectionStatus: ConnectionStatus = .disconnected
    var currentJob: PrintJob?
    var isScanning: Bool = false
    var errorMessage: String?

    // MARK: - Private Properties
    private var mqttClient: MQTTClient?
    private var ftpClient: FTPClient?

    enum ConnectionStatus: String, CaseIterable {
        case disconnected = "Disconnected"
        case scanning = "Scanning"
        case connecting = "Connecting"
        case connected = "Connected"
        case error = "Error"

        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .scanning: return .blue
            case .connecting: return .orange
            case .connected: return .bambuPrimary
            case .error: return .red
            }
        }

        var systemImage: String {
            switch self {
            case .disconnected: return "wifi.slash"
            case .scanning: return "wifi"
            case .connecting: return "wifi.exclamationmark"
            case .connected: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Initialization
    init() {
        loadSavedPrinters()
    }

    // MARK: - Printer Discovery
    @MainActor
    func scanForPrinters() async {
        guard !isScanning else { return }

        // Temporarily disabled network scanning to prevent connection spam
        // TODO: Re-enable after proper MQTT discovery implementation
        isScanning = true
        errorMessage = nil
        connectionStatus = .scanning

        // Simulate scan completion without actual network discovery
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isScanning = false
        connectionStatus = .disconnected
        return

        /*
        do {
            let discoveredPrinters = try await discoverPrintersOnNetwork()

            // Merge with saved printers
            var updatedPrinters = printers
            for discovered in discoveredPrinters {
                if !updatedPrinters.contains(where: { $0.serialNumber == discovered.serialNumber }) {
                    updatedPrinters.append(discovered)
                }
            }

            printers = updatedPrinters
            savePrinters()

            if connectedPrinter == nil && !printers.isEmpty {
                connectionStatus = .disconnected
            }

        } catch {
            errorMessage = error.localizedDescription
            connectionStatus = .error
        }

        isScanning = false
        */
    }

    private func discoverPrintersOnNetwork() async throws -> [BambuPrinter] {
        return await withCheckedContinuation { continuation in
            var discoveredPrinters: [BambuPrinter] = []
            var hasResumed = false
            let resumeLock = NSLock()

            func safeResume(with result: [BambuPrinter]) {
                resumeLock.lock()
                defer { resumeLock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: result)
                }
            }

            // Scan common IP ranges for Bambu printers
            let ipRanges = generateIPRanges()
            let group = DispatchGroup()

            for ip in ipRanges.prefix(5) { // Limit to first 5 IPs to avoid overwhelming the network
                group.enter()

                Task {
                    defer { group.leave() }

                    if let printer = await checkForBambuPrinter(at: ip) {
                        resumeLock.lock()
                        discoveredPrinters.append(printer)
                        resumeLock.unlock()
                    }
                }
            }

            group.notify(queue: .main) {
                safeResume(with: discoveredPrinters)
            }

            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                safeResume(with: discoveredPrinters)
            }
        }
    }

    private func generateIPRanges() -> [String] {
        // Generate common local network IP ranges
        var ips: [String] = []

        // Common ranges: 192.168.1.x, 192.168.0.x, 10.0.0.x
        let baseRanges = ["192.168.1", "192.168.0", "10.0.0", "172.16.0"]

        for base in baseRanges {
            for i in 1...254 {
                ips.append("\(base).\(i)")
            }
        }

        return ips
    }

    private func checkForBambuPrinter(at ip: String) async -> BambuPrinter? {
        // Try to connect to Bambu MQTT port (8883) to verify it's a Bambu printer
        let connection = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(8883),
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeLock = NSLock()

            func safeResume(with result: BambuPrinter?) {
                resumeLock.lock()
                defer { resumeLock.unlock() }

                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: result)
                }
            }

            connection.stateUpdateHandler = { (state: NWConnection.State) in
                switch state {
                case .ready:
                    connection.cancel()
                    // This is likely a Bambu printer
                    let printer = BambuPrinter(
                        name: "Bambu Printer",
                        model: .a1Mini,
                        ipAddress: ip,
                        serialNumber: "Unknown",
                        accessCode: nil,
                        isOnline: true
                    )
                    safeResume(with: printer)

                case .failed, .cancelled:
                    connection.cancel()
                    safeResume(with: nil)

                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                connection.cancel()
                safeResume(with: nil)
            }
        }
    }

    // MARK: - Printer Connection
    @MainActor
    func connectToPrinter(_ printer: BambuPrinter, accessCode: String) async {
        connectionStatus = .connecting
        errorMessage = nil

        do {
            // Update printer with access code
            var updatedPrinter = printer
            updatedPrinter.accessCode = accessCode

            // Initialize MQTT and FTP clients
            mqttClient = MQTTClient(printer: updatedPrinter)
            ftpClient = FTPClient(printer: updatedPrinter)

            // Test connection
            try await mqttClient?.connect()

            // Update printer status
            connectedPrinter = updatedPrinter
            connectionStatus = .connected

            // Update in saved printers list
            if let index = printers.firstIndex(where: { $0.id == printer.id }) {
                printers[index] = updatedPrinter
                savePrinters()
            }

            // Start monitoring printer status
            startStatusMonitoring()

        } catch {
            errorMessage = error.localizedDescription
            connectionStatus = .error
            mqttClient = nil
            ftpClient = nil
        }
    }

    @MainActor
    func disconnectFromPrinter() {
        if let mqttClient = mqttClient {
            Task {
                await mqttClient.disconnect()
            }
        }
        mqttClient = nil
        ftpClient = nil

        connectedPrinter = nil
        connectionStatus = .disconnected
        currentJob = nil
    }

    // MARK: - Print Job Management
    @MainActor
    func sendPrintJob(_ job: PrintJob) async throws {
        guard let _ = connectedPrinter,
              let ftpClient = ftpClient,
              let mqttClient = mqttClient else {
            throw PrinterError.notConnected
        }

        // Upload file via FTP
        try await ftpClient.uploadFile(job.filePath, as: job.fileName)

        // Send print command via MQTT
        try await mqttClient.sendPrintCommand(fileName: job.fileName, jobName: job.name)

        currentJob = job
    }

    @MainActor
    func pauseCurrentJob() async throws {
        guard let mqttClient = mqttClient else {
            throw PrinterError.notConnected
        }

        try await mqttClient.sendPauseCommand()
    }

    @MainActor
    func resumeCurrentJob() async throws {
        guard let mqttClient = mqttClient else {
            throw PrinterError.notConnected
        }

        try await mqttClient.sendResumeCommand()
    }

    @MainActor
    func cancelCurrentJob() async throws {
        guard let mqttClient = mqttClient else {
            throw PrinterError.notConnected
        }

        try await mqttClient.sendCancelCommand()
        currentJob = nil
    }

    // MARK: - Status Monitoring
    private func startStatusMonitoring() {
        Task {
            await mqttClient?.startStatusUpdates { [weak self] status in
                Task { @MainActor in
                    self?.updatePrinterStatus(status)
                }
            }
        }
    }

    @MainActor
    private func updatePrinterStatus(_ status: PrinterStatus) {
        connectedPrinter?.status = status

        // Update current job if printing
        if status.state == .printing || status.state == .paused {
            currentJob?.progress = status.progress
            currentJob?.timeRemaining = status.timeRemaining
        } else if status.state == .idle {
            currentJob = nil
        }
    }

    // MARK: - Data Persistence
    private func savePrinters() {
        if let data = try? JSONEncoder().encode(printers) {
            UserDefaults.standard.set(data, forKey: "SavedPrinters")
        }
    }

    private func loadSavedPrinters() {
        guard let data = UserDefaults.standard.data(forKey: "SavedPrinters"),
              let savedPrinters = try? JSONDecoder().decode([BambuPrinter].self, from: data) else {
            return
        }
        printers = savedPrinters
    }

    // MARK: - Utility Methods
    @MainActor
    func removePrinter(_ printer: BambuPrinter) {
        printers.removeAll { $0.id == printer.id }
        savePrinters()

        if connectedPrinter?.id == printer.id {
            disconnectFromPrinter()
        }
    }
}

// MARK: - Supporting Types
enum PrinterError: LocalizedError {
    case notConnected
    case invalidAccessCode
    case connectionTimeout
    case uploadFailed
    case commandFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to printer"
        case .invalidAccessCode:
            return "Invalid access code"
        case .connectionTimeout:
            return "Connection timed out"
        case .uploadFailed:
            return "Failed to upload file"
        case .commandFailed:
            return "Command failed"
        }
    }
}

// MARK: - Mock Clients (to be implemented)
private actor MQTTClient {
    let printer: BambuPrinter

    init(printer: BambuPrinter) {
        self.printer = printer
    }

    func connect() async throws {
        // Implement MQTT connection logic
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func disconnect() async {
        // Implement disconnect logic
    }

    func sendPrintCommand(fileName: String, jobName: String) async throws {
        // Implement print command
    }

    func sendPauseCommand() async throws {
        // Implement pause command
    }

    func sendResumeCommand() async throws {
        // Implement resume command
    }

    func sendCancelCommand() async throws {
        // Implement cancel command
    }

    func startStatusUpdates(callback: @escaping (PrinterStatus) -> Void) async {
        // Implement status monitoring
    }
}

private actor FTPClient {
    let printer: BambuPrinter

    init(printer: BambuPrinter) {
        self.printer = printer
    }

    func uploadFile(_ path: String, as fileName: String) async throws {
        // Implement FTP upload
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}