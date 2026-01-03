import SwiftUI
import Foundation

// MARK: - Print Job Models
struct PrintJob: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let prompt: String?
    let filePath: String
    let fileName: String
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var status: PrintJobStatus
    var progress: Double
    var timeRemaining: String?
    var estimatedPrintTime: String?
    var filamentUsed: String?

    init(
        name: String,
        prompt: String? = nil,
        filePath: String,
        fileName: String,
        estimatedPrintTime: String? = nil,
        filamentUsed: String? = nil
    ) {
        self.name = name
        self.prompt = prompt
        self.filePath = filePath
        self.fileName = fileName
        self.createdAt = Date()
        self.status = .queued
        self.progress = 0.0
        self.estimatedPrintTime = estimatedPrintTime
        self.filamentUsed = filamentUsed
    }

    var isActive: Bool {
        status == .printing || status == .paused
    }

    var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "Not started" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "Unknown"
    }

    var statusColor: Color {
        status.color
    }

    var statusIcon: String {
        status.systemImage
    }
}

enum PrintJobStatus: String, CaseIterable, Codable {
    case queued = "Queued"
    case uploading = "Uploading"
    case printing = "Printing"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .queued: return .gray
        case .uploading: return .blue
        case .printing: return .bambuPrimary
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .queued: return "clock"
        case .uploading: return "arrow.up.circle"
        case .printing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .queued: return "Waiting to start"
        case .uploading: return "Uploading to printer"
        case .printing: return "Currently printing"
        case .paused: return "Print paused"
        case .completed: return "Print completed successfully"
        case .failed: return "Print failed"
        case .cancelled: return "Print cancelled"
        }
    }
}

// MARK: - Printer Models
struct BambuPrinter: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    let model: PrinterModel
    let ipAddress: String
    let serialNumber: String
    var accessCode: String?
    var isOnline: Bool
    var status: PrinterStatus = PrinterStatus()
    var lastSeen: Date = Date()

    var isConfigured: Bool {
        accessCode != nil && !accessCode!.isEmpty
    }

    var displayName: String {
        name.isEmpty ? "\(model.displayName) (\(ipAddress))" : name
    }
}

enum PrinterModel: String, CaseIterable, Codable {
    case a1Mini = "A1 mini"
    case a1 = "A1"
    case x1Carbon = "X1 Carbon"
    case x1 = "X1"
    case p1p = "P1P"
    case p1s = "P1S"

    var displayName: String {
        switch self {
        case .a1Mini: return "Bambu A1 mini"
        case .a1: return "Bambu A1"
        case .x1Carbon: return "Bambu X1 Carbon"
        case .x1: return "Bambu X1"
        case .p1p: return "Bambu P1P"
        case .p1s: return "Bambu P1S"
        }
    }

    var maxBuildVolume: (x: Int, y: Int, z: Int) {
        switch self {
        case .a1Mini: return (180, 180, 180)
        case .a1: return (256, 256, 256)
        case .x1Carbon, .x1: return (256, 256, 256)
        case .p1p, .p1s: return (256, 256, 256)
        }
    }

    var hasAMS: Bool {
        switch self {
        case .a1Mini: return false
        case .a1, .x1Carbon, .x1, .p1p, .p1s: return true
        }
    }
}

struct PrinterStatus: Codable, Hashable {
    var state: PrinterState = .idle
    var progress: Double = 0.0
    var bedTemperature: Double = 0.0
    var nozzleTemperature: Double = 0.0
    var targetBedTemp: Double = 0.0
    var targetNozzleTemp: Double = 0.0
    var currentLayer: Int = 0
    var totalLayers: Int = 0
    var timeRemaining: String?
    var currentJobName: String?
    var lastUpdated: Date = Date()

    var isHeating: Bool {
        abs(bedTemperature - targetBedTemp) > 5.0 || abs(nozzleTemperature - targetNozzleTemp) > 5.0
    }

    var layerProgress: String {
        guard totalLayers > 0 else { return "N/A" }
        return "\(currentLayer)/\(totalLayers)"
    }
}

enum PrinterState: String, CaseIterable, Codable {
    case idle = "idle"
    case printing = "printing"
    case paused = "paused"
    case error = "error"
    case offline = "offline"
    case preparing = "preparing"
    case heating = "heating"
    case calibrating = "calibrating"
    case finished = "finished"

    var color: Color {
        switch self {
        case .idle: return .gray
        case .printing: return .bambuPrimary
        case .paused: return .orange
        case .error: return .red
        case .offline: return .gray
        case .preparing: return .blue
        case .heating: return .orange
        case .calibrating: return .blue
        case .finished: return .green
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "pause.circle"
        case .printing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        case .preparing: return "gear"
        case .heating: return "thermometer"
        case .calibrating: return "level"
        case .finished: return "checkmark.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .printing: return "Printing"
        case .paused: return "Paused"
        case .error: return "Error"
        case .offline: return "Offline"
        case .preparing: return "Preparing"
        case .heating: return "Heating"
        case .calibrating: return "Calibrating"
        case .finished: return "Finished"
        }
    }
}

// MARK: - Generation Models
struct GenerationRequest: Identifiable, Codable {
    let id = UUID()
    let prompt: String
    let timestamp: Date
    var status: GenerationStatus
    var openscadCode: String?
    var explanation: String?
    var estimatedPrintTime: String?
    var errorMessage: String?

    init(prompt: String) {
        self.prompt = prompt
        self.timestamp = Date()
        self.status = .pending
    }

    var isComplete: Bool {
        status == .completed || status == .failed
    }
}

enum GenerationStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case generating = "Generating"
    case completed = "Completed"
    case failed = "Failed"

    var color: Color {
        switch self {
        case .pending: return .gray
        case .generating: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .generating: return "gear"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Sample Data for Previews
extension PrintJob {
    static let sampleJobs: [PrintJob] = [
        PrintJob(
            name: "Phone Stand",
            prompt: "A simple phone stand with 45 degree angle",
            filePath: "/tmp/phone_stand.3mf",
            fileName: "phone_stand.3mf",
            estimatedPrintTime: "45 minutes",
            filamentUsed: "15g"
        ),
        PrintJob(
            name: "Desk Organizer",
            prompt: "A desk organizer with 3 compartments for pens",
            filePath: "/tmp/desk_organizer.3mf",
            fileName: "desk_organizer.3mf",
            estimatedPrintTime: "2 hours",
            filamentUsed: "35g"
        )
    ]

    static var samplePrintingJob: PrintJob {
        var job = sampleJobs[0]
        job.status = .printing
        job.progress = 0.65
        job.timeRemaining = "15 minutes"
        job.startedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        return job
    }

    static var sampleCompletedJob: PrintJob {
        var job = sampleJobs[1]
        job.status = .completed
        job.progress = 1.0
        job.startedAt = Date().addingTimeInterval(-7200) // 2 hours ago
        job.completedAt = Date().addingTimeInterval(-300) // 5 minutes ago
        return job
    }
}

extension BambuPrinter {
    static let samplePrinters: [BambuPrinter] = [
        BambuPrinter(
            name: "Living Room Printer",
            model: .a1Mini,
            ipAddress: "192.168.1.100",
            serialNumber: "01S00A12345678",
            accessCode: "12345678",
            isOnline: true
        ),
        BambuPrinter(
            name: "Office Printer",
            model: .x1Carbon,
            ipAddress: "192.168.1.101",
            serialNumber: "01S00X87654321",
            accessCode: nil,
            isOnline: false
        )
    ]

    static var sampleConnectedPrinter: BambuPrinter {
        var printer = samplePrinters[0]
        printer.status = PrinterStatus(
            state: .printing,
            progress: 0.65,
            bedTemperature: 60.0,
            nozzleTemperature: 220.0,
            targetBedTemp: 60.0,
            targetNozzleTemp: 220.0,
            currentLayer: 145,
            totalLayers: 223,
            timeRemaining: "45 minutes",
            currentJobName: "Phone Stand"
        )
        return printer
    }
}