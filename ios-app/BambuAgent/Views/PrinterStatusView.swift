import SwiftUI

struct PrinterStatusView: View {
    @Environment(PrinterManager.self) private var printerManager
    @Environment(WiFiManager.self) private var wifiManager

    @State private var selectedPrinterForSetup: BambuPrinter?

    var body: some View {
        NavigationStack {
            VStack(spacing: BambuSpacing.lg) {
                if let printer = printerManager.connectedPrinter {
                    connectedPrinterView(printer)
                } else {
                    setupPrinterView
                }

                Spacer()
            }
            .padding(BambuSpacing.lg)
            .navigationTitle("Printer")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedPrinterForSetup) { printer in
                BambuHandyStyleSetupView(printer: printer)
            }
        }
    }

    // MARK: - Connected Printer View
    private func connectedPrinterView(_ printer: BambuPrinter) -> some View {
        VStack(spacing: BambuSpacing.lg) {
            // Printer Info Card
            VStack(alignment: .leading, spacing: BambuSpacing.md) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(printer.displayName)
                            .font(BambuTextStyle.title2)
                            .fontWeight(.semibold)

                        Text(printer.model.displayName)
                            .font(BambuTextStyle.callout)
                            .foregroundColor(.secondary)

                        Text("IP: \(printer.ipAddress)")
                            .font(BambuTextStyle.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    StatusIndicator(
                        printer.status.state == .printing ? .printing :
                        printer.status.state == .idle ? .idle :
                        printer.status.state == .error ? .error : .success
                    )
                }
            }
            .bambuCard()

            // Temperature Card
            VStack(alignment: .leading, spacing: BambuSpacing.md) {
                Text("Temperature")
                    .font(BambuTextStyle.headline)

                HStack(spacing: BambuSpacing.lg) {
                    TemperatureGauge(
                        title: "Nozzle",
                        current: printer.status.nozzleTemperature,
                        target: printer.status.targetNozzleTemp,
                        maxTemp: 300
                    )

                    TemperatureGauge(
                        title: "Bed",
                        current: printer.status.bedTemperature,
                        target: printer.status.targetBedTemp,
                        maxTemp: 100
                    )
                }
            }
            .bambuCard()

            // Current Job (if any)
            if let currentJob = printerManager.currentJob {
                currentJobCard(currentJob)
            }

            // Controls
            VStack(spacing: BambuSpacing.md) {
                Button("Disconnect") {
                    printerManager.disconnectFromPrinter()
                }
                .bambuDestructiveButton()
            }
        }
    }

    // MARK: - Setup Printer View
    private var setupPrinterView: some View {
        VStack(spacing: BambuSpacing.lg) {
            // Header
            VStack(spacing: BambuSpacing.md) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.bambuPrimary)

                VStack(spacing: BambuSpacing.sm) {
                    Text("Connect to Printer")
                        .font(BambuTextStyle.title)
                        .multilineTextAlignment(.center)

                    Text("Find and connect to your Bambu A1 mini on the local network")
                        .font(BambuTextStyle.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .bambuCard()

            // Scanner Status
            if printerManager.isScanning {
                HStack {
                    LoadingSpinner()
                    Text("Scanning for printers...")
                        .font(BambuTextStyle.callout)
                }
                .bambuCard()
            }

            // Found Printers
            if !printerManager.printers.isEmpty {
                VStack(alignment: .leading, spacing: BambuSpacing.md) {
                    Text("Found Printers")
                        .font(BambuTextStyle.headline)

                    ForEach(printerManager.printers) { printer in
                        PrinterRowView(printer: printer) {
                            // Connect to printer
                            showConnectSheet(for: printer)
                        }
                    }
                }
            }

            // Actions
            VStack(spacing: BambuSpacing.md) {
                Button("Scan for Printers") {
                    Task {
                        await printerManager.scanForPrinters()
                    }
                }
                .bambuPrimaryButton()
                .disabled(printerManager.isScanning)

                Button("Add Manually") {
                    // TODO: Show manual setup sheet
                }
                .bambuSecondaryButton()
            }
        }
    }

    private func currentJobCard(_ job: PrintJob) -> some View {
        VStack(alignment: .leading, spacing: BambuSpacing.md) {
            Text("Current Print")
                .font(BambuTextStyle.headline)

            VStack(spacing: BambuSpacing.md) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(job.name)
                            .font(BambuTextStyle.title2)
                            .fontWeight(.semibold)

                        if let prompt = job.prompt {
                            Text(prompt)
                                .font(BambuTextStyle.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    ProgressRing(progress: job.progress, strokeWidth: 6)
                        .frame(width: 60, height: 60)
                }

                if let timeRemaining = job.timeRemaining {
                    HStack {
                        Label("Time Remaining", systemImage: "clock")
                        Spacer()
                        Text(timeRemaining)
                            .fontWeight(.medium)
                    }
                    .font(BambuTextStyle.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .bambuCard()
    }

    private func showConnectSheet(for printer: BambuPrinter) {
        selectedPrinterForSetup = printer
        // HapticFeedback.light() // TODO: Add HapticFeedback back when properly integrated
    }
}

// MARK: - Supporting Views
struct PrinterRowView: View {
    let printer: BambuPrinter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(printer.displayName)
                        .font(BambuTextStyle.callout)
                        .fontWeight(.medium)

                    Text("IP: \(printer.ipAddress)")
                        .font(BambuTextStyle.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack {
                    Circle()
                        .fill(printer.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(printer.isOnline ? "Online" : "Offline")
                        .font(BambuTextStyle.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(BambuSpacing.md)
            .background(Color.surfaceSecondary)
            .cornerRadius(BambuRadius.md)
        }
        .buttonStyle(.plain)
    }
}

struct TemperatureGauge: View {
    let title: String
    let current: Double
    let target: Double
    let maxTemp: Double

    var body: some View {
        VStack {
            Text(title)
                .font(BambuTextStyle.caption)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: current / maxTemp)
                    .stroke(
                        current > target * 0.9 ? Color.bambuPrimary : Color.orange,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: current)

                VStack {
                    Text("\(Int(current))°")
                        .font(BambuTextStyle.caption)
                        .fontWeight(.semibold)

                    if target > 0 {
                        Text("→\(Int(target))°")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

// MARK: - BambuHandy Style Setup Demo
struct BambuHandyStyleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let printer: BambuPrinter

    @State private var currentStep = 0
    @State private var selectedFilament: String = "PLA"
    @State private var selectedPlate: String = "Smooth PEI"
    @State private var accessCode: String = ""

    private let steps = ["Select Filament", "Choose Plate", "Access Code", "Connect"]
    private let filaments = ["PLA (White)", "ABS (Black)", "PETG (Clear)", "TPU (Red)"]
    private let plates = ["Smooth PEI", "Textured PEI", "Glass Bed"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color.bambuPrimary)

                        VStack(alignment: .leading) {
                            Text(printer.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(printer.ipAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Progress Steps
                    HStack {
                        ForEach(0..<steps.count, id: \.self) { index in
                            HStack {
                                Circle()
                                    .fill(index <= currentStep ? Color.bambuPrimary : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)

                                if index < steps.count - 1 {
                                    Rectangle()
                                        .fill(index < currentStep ? Color.bambuPrimary : Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .background(.ultraThinMaterial)

                Divider()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(steps[currentStep])
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(stepDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                        Group {
                            switch currentStep {
                            case 0: filamentSelection
                            case 1: plateSelection
                            case 2: accessCodeEntry
                            case 3: connectionStep
                            default: Text("Complete")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                }

                // Bottom Actions
                VStack {
                    Divider()

                    HStack {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation { currentStep -= 1 }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button(currentStep == 3 ? "Connect" : "Continue") {
                            if currentStep < 3 {
                                withAnimation { currentStep += 1 }
                            } else {
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentStep == 2 && accessCode.count != 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .background(.regularMaterial)
            }
            .navigationTitle("Setup Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 0: return "Choose the filament you want to use for printing"
        case 1: return "Select your build plate type for optimal adhesion"
        case 2: return "Enter the 8-character access code from your printer"
        case 3: return "Establishing connection to your Bambu printer"
        default: return ""
        }
    }

    @ViewBuilder
    private var filamentSelection: some View {
        VStack(spacing: 12) {
            ForEach(filaments, id: \.self) { filament in
                Button(action: { selectedFilament = filament }) {
                    HStack {
                        Circle()
                            .fill(filamentColor(filament))
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading) {
                            Text(filament)
                                .fontWeight(.medium)
                            Text("210°C | 60°C bed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedFilament == filament {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.bambuPrimary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var plateSelection: some View {
        VStack(spacing: 12) {
            ForEach(plates, id: \.self) { plate in
                Button(action: { selectedPlate = plate }) {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(plateColor(plate))
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading) {
                            Text(plate)
                                .fontWeight(.medium)
                            Text("180 × 180 × 180 mm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedPlate == plate {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.bambuPrimary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var accessCodeEntry: some View {
        VStack(spacing: 20) {
            TextField("12345678", text: $accessCode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .font(.system(.title3, design: .monospaced))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Find your access code:")
                    .font(.headline)
                Text("• Go to Settings on your printer")
                Text("• Navigate to Network → WiFi")
                Text("• Look for 'Access Code'")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var connectionStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.bambuPrimary)

            VStack(spacing: 12) {
                Text("Connecting to \(printer.displayName)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Filament:")
                        Spacer()
                        Text(selectedFilament)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build Plate:")
                        Spacer()
                        Text(selectedPlate)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Network:")
                        Spacer()
                        Text(printer.ipAddress)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func filamentColor(_ filament: String) -> Color {
        if filament.contains("White") { return .white }
        if filament.contains("Black") { return .black }
        if filament.contains("Clear") { return .blue.opacity(0.3) }
        if filament.contains("Red") { return .red }
        return .gray
    }

    private func plateColor(_ plate: String) -> Color {
        if plate.contains("Smooth") { return .black }
        if plate.contains("Textured") { return .gray }
        if plate.contains("Glass") { return .blue.opacity(0.3) }
        return .gray
    }
}

#Preview {
    PrinterStatusView()
        .environment(PrinterManager())
        .environment(WiFiManager())
}