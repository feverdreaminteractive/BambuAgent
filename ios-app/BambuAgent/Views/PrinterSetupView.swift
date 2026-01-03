import SwiftUI

struct PrinterSetupView: View {
    @Environment(PrinterManager.self) private var printerManager
    @Environment(\.dismiss) private var dismiss

    let printer: BambuPrinter

    @State private var setupStep: SetupStep = .filamentSelection
    @State private var selectedFilament: Filament?
    @State private var selectedPlate: BuildPlate?
    @State private var accessCode: String = ""
    @State private var showingAccessCodeAlert = false
    @State private var isConnecting = false

    enum SetupStep: Int, CaseIterable {
        case filamentSelection = 0
        case plateSelection = 1
        case accessCodeEntry = 2
        case connecting = 3

        var title: String {
            switch self {
            case .filamentSelection: return "Select Filament"
            case .plateSelection: return "Select Build Plate"
            case .accessCodeEntry: return "Enter Access Code"
            case .connecting: return "Connecting"
            }
        }

        var subtitle: String {
            switch self {
            case .filamentSelection: return "Choose the filament you want to use"
            case .plateSelection: return "Select your build plate type"
            case .accessCodeEntry: return "Enter the 8-character access code from your printer's screen"
            case .connecting: return "Establishing connection to your printer"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with printer info
                printerHeaderView

                // Progress indicator
                progressIndicatorView

                // Content based on current step
                ScrollView {
                    VStack(spacing: 24) {
                        stepContentView
                    }
                    .padding(.horizontal, 20)
                }

                // Bottom action buttons
                bottomActionButtons
            }
            .navigationTitle("Setup Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var printerHeaderView: some View {
        VStack(spacing: 12) {
            // Printer icon and name
            HStack {
                Image(systemName: "printer.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.bambuPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(printer.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(printer.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Online status indicator
                Circle()
                    .fill(printer.isOnline ? .bambuPrimary : .gray)
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 20)

            Divider()
        }
        .padding(.top, 16)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var progressIndicatorView: some View {
        HStack {
            ForEach(SetupStep.allCases, id: \.rawValue) { step in
                HStack {
                    Circle()
                        .fill(step.rawValue <= setupStep.rawValue ? .bambuPrimary : .gray.opacity(0.3))
                        .frame(width: 12, height: 12)

                    if step != SetupStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < setupStep.rawValue ? .bambuPrimary : .gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var stepContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Step title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text(setupStep.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(setupStep.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Step content
            Group {
                switch setupStep {
                case .filamentSelection:
                    filamentSelectionView
                case .plateSelection:
                    plateSelectionView
                case .accessCodeEntry:
                    accessCodeEntryView
                case .connecting:
                    connectingView
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var filamentSelectionView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
            ForEach(Filament.sampleFilaments, id: \.id) { filament in
                FilamentRowView(
                    filament: filament,
                    isSelected: selectedFilament?.id == filament.id
                ) {
                    selectedFilament = filament
                    HapticFeedback.light()
                }
            }
        }
    }

    @ViewBuilder
    private var plateSelectionView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
            ForEach(BuildPlate.samplePlates, id: \.id) { plate in
                BuildPlateRowView(
                    plate: plate,
                    isSelected: selectedPlate?.id == plate.id,
                    selectedFilament: selectedFilament
                ) {
                    selectedPlate = plate
                    HapticFeedback.light()
                }
            }
        }
    }

    @ViewBuilder
    private var accessCodeEntryView: some View {
        VStack(spacing: 20) {
            // Access code input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Access Code")
                    .font(.headline)

                HStack {
                    TextField("12345678", text: $accessCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.title3, design: .monospaced))

                    Button("Info") {
                        showingAccessCodeAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.bambuSecondary)
                }
            }

            // Instructions card
            VStack(alignment: .leading, spacing: 12) {
                Label("How to find your access code:", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundColor(.bambuPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. On your printer's screen, go to Settings")
                    Text("2. Navigate to Network → WiFi")
                    Text("3. Look for 'Access Code' - it's an 8-digit number")
                    Text("4. Enter this code to allow BambuAgent to connect")
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .alert("Access Code Information", isPresented: $showingAccessCodeAlert) {
            Button("OK") { }
        } message: {
            Text("The access code is a security feature that allows trusted apps to connect to your Bambu printer. You can find it in Settings → Network → WiFi on your printer's display.")
        }
    }

    @ViewBuilder
    private var connectingView: some View {
        VStack(spacing: 24) {
            // Animated connection indicator
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.bambuPrimary)

                Text("Connecting to \(printer.displayName)...")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            // Connection details
            VStack(alignment: .leading, spacing: 12) {
                connectionDetailRow(
                    icon: "network",
                    title: "Network",
                    value: printer.ipAddress
                )

                if let filament = selectedFilament {
                    connectionDetailRow(
                        icon: "cylinder.fill",
                        title: "Filament",
                        value: filament.displayName
                    )
                }

                if let plate = selectedPlate {
                    connectionDetailRow(
                        icon: "rectangle.fill",
                        title: "Build Plate",
                        value: plate.displayName
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func connectionDetailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.bambuSecondary)
                .frame(width: 20)

            Text(title)
                .fontWeight(.medium)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var bottomActionButtons: some View {
        VStack(spacing: 16) {
            Divider()

            HStack {
                if setupStep != .filamentSelection {
                    Button("Back") {
                        withAnimation {
                            setupStep = SetupStep(rawValue: setupStep.rawValue - 1) ?? .filamentSelection
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(nextButtonTitle) {
                    handleNextAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceedToNext)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(.regularMaterial)
    }

    private var nextButtonTitle: String {
        switch setupStep {
        case .filamentSelection: return "Continue"
        case .plateSelection: return "Continue"
        case .accessCodeEntry: return "Connect"
        case .connecting: return "Connecting..."
        }
    }

    private var canProceedToNext: Bool {
        switch setupStep {
        case .filamentSelection: return selectedFilament != nil
        case .plateSelection: return selectedPlate != nil
        case .accessCodeEntry: return accessCode.count == 8 && !isConnecting
        case .connecting: return false
        }
    }

    private func handleNextAction() {
        HapticFeedback.medium()

        switch setupStep {
        case .filamentSelection, .plateSelection:
            withAnimation {
                setupStep = SetupStep(rawValue: setupStep.rawValue + 1) ?? setupStep
            }

        case .accessCodeEntry:
            connectToPrinter()

        case .connecting:
            break
        }
    }

    private func connectToPrinter() {
        isConnecting = true

        withAnimation {
            setupStep = .connecting
        }

        // Update printer with access code
        var updatedPrinter = printer
        updatedPrinter.accessCode = accessCode

        Task {
            await printerManager.connectToPrinter(updatedPrinter, accessCode: accessCode)

            // Simulate connection process
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                // Save filament and plate preferences
                if let filament = selectedFilament, let plate = selectedPlate {
                    // You would save these to the printer's configuration
                    print("Connected with filament: \(filament.displayName), plate: \(plate.displayName)")
                }

                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views
struct FilamentRowView: View {
    let filament: Filament
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Color indicator
                RoundedRectangle(cornerRadius: 8)
                    .fill(filament.color.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(filament.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(filament.temperatureInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: filament.brand.logo)
                        Text(filament.material.rawValue)
                    }
                    .font(.caption2)
                    .foregroundColor(.bambuSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.bambuPrimary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .bambuPrimary.opacity(0.1) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? .bambuPrimary : .quaternary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct BuildPlateRowView: View {
    let plate: BuildPlate
    let isSelected: Bool
    let selectedFilament: Filament?
    let onTap: () -> Void

    private var isCompatible: Bool {
        guard let filament = selectedFilament else { return true }
        return plate.suitableFilaments.contains(filament.material)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Plate visual representation
                RoundedRectangle(cornerRadius: 8)
                    .fill(plate.material.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(plate.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompatible ? .primary : .secondary)

                    Text(plate.size.displaySize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !isCompatible {
                        Text("Not recommended for selected filament")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if plate.isInstalled {
                        Text("Currently installed")
                            .font(.caption2)
                            .foregroundColor(.bambuPrimary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.bambuPrimary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .bambuPrimary.opacity(0.1) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? .bambuPrimary :
                                (isCompatible ? .quaternary : .orange.opacity(0.5)),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCompatible)
    }
}

#Preview {
    PrinterSetupView(printer: BambuPrinter.samplePrinters[0])
        .environment(PrinterManager())
}