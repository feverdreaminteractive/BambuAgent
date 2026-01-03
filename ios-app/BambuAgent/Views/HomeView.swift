import SwiftUI

struct HomeView: View {
    @Environment(APIService.self) private var apiService
    @Environment(PrinterManager.self) private var printerManager

    @State private var promptText = ""
    @State private var generationHistory: [GenerationRequest] = []
    @State private var showingPromptSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BambuSpacing.lg) {
                    // Header
                    headerSection

                    // Quick Actions
                    quickActionsSection

                    // Current Status
                    if let currentJob = printerManager.currentJob {
                        currentJobSection(currentJob)
                    }

                    // Recent Generations
                    if !generationHistory.isEmpty {
                        recentGenerationsSection
                    }

                    Spacer(minLength: 100)
                }
                .padding(BambuSpacing.lg)
            }
            .navigationTitle("BambuAgent")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    connectionStatusButton
                }
            }
            .sheet(isPresented: $showingPromptSheet) {
                PromptInputSheet(
                    promptText: $promptText,
                    onGenerate: generateModel
                )
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: BambuSpacing.md) {
            Image(systemName: "cube.fill")
                .font(.system(size: 60))
                .foregroundColor(.bambuPrimary)

            VStack(spacing: BambuSpacing.sm) {
                Text("AI-Powered 3D Printing")
                    .font(BambuTextStyle.title)
                    .multilineTextAlignment(.center)

                Text("Describe what you want to print, and I'll make it happen")
                    .font(BambuTextStyle.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .bambuCard()
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: BambuSpacing.md) {
            Text("Quick Actions")
                .font(BambuTextStyle.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: BambuSpacing.md) {
                QuickActionCard(
                    title: "Generate Model",
                    subtitle: "From text prompt",
                    systemImage: "brain.head.profile",
                    color: .bambuPrimary
                ) {
                    // HapticFeedback.light() // TODO: Add back when properly integrated
                    showingPromptSheet = true
                }

                QuickActionCard(
                    title: "Quick Print",
                    subtitle: "Full pipeline",
                    systemImage: "bolt.fill",
                    color: .bambuAccent
                ) {
                    // HapticFeedback.light() // TODO: Add back when properly integrated
                    // TODO: Implement quick print
                }

                QuickActionCard(
                    title: "Browse Files",
                    subtitle: "Upload existing",
                    systemImage: "folder.fill",
                    color: .bambuSecondary
                ) {
                    // HapticFeedback.light() // TODO: Add back when properly integrated
                    // TODO: Implement file browser
                }

                QuickActionCard(
                    title: "Examples",
                    subtitle: "Try samples",
                    systemImage: "star.fill",
                    color: .statusWarning
                ) {
                    // HapticFeedback.light() // TODO: Add back when properly integrated
                    showSamplePrompts()
                }
            }
        }
    }

    // MARK: - Current Job Section
    private func currentJobSection(_ job: PrintJob) -> some View {
        VStack(alignment: .leading, spacing: BambuSpacing.md) {
            HStack {
                Text("Current Print")
                    .font(BambuTextStyle.headline)

                Spacer()

                StatusIndicator(job.status == .printing ? .printing : .paused)
            }

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

                // Job controls
                HStack(spacing: BambuSpacing.md) {
                    if job.status == .printing {
                        Button("Pause") {
                            Task {
                                try? await printerManager.pauseCurrentJob()
                            }
                        }
                        .bambuSecondaryButton()
                    } else if job.status == .paused {
                        Button("Resume") {
                            Task {
                                try? await printerManager.resumeCurrentJob()
                            }
                        }
                        .bambuPrimaryButton()
                    }

                    Button("Cancel") {
                        Task {
                            try? await printerManager.cancelCurrentJob()
                        }
                    }
                    .bambuDestructiveButton()
                }
            }
        }
        .bambuCard()
    }

    // MARK: - Recent Generations
    private var recentGenerationsSection: some View {
        VStack(alignment: .leading, spacing: BambuSpacing.md) {
            Text("Recent Generations")
                .font(BambuTextStyle.headline)

            ForEach(generationHistory.prefix(3)) { request in
                GenerationHistoryCard(request: request) {
                    // Print this generation
                    if let code = request.openscadCode {
                        printGeneration(code: code, name: request.prompt)
                    }
                }
            }
        }
    }

    // MARK: - Connection Status
    private var connectionStatusButton: some View {
        HStack(spacing: BambuSpacing.sm) {
            Circle()
                .fill(apiService.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Circle()
                .fill(printerManager.connectionStatus == .connected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Actions
    private func generateModel() {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let request = GenerationRequest(prompt: promptText)
        generationHistory.insert(request, at: 0)

        Task {
            if let index = generationHistory.firstIndex(where: { $0.id == request.id }) {
                await MainActor.run {
                    generationHistory[index].status = .generating
                }

                do {
                    let response = try await apiService.generateModel(from: request.prompt)

                    await MainActor.run {
                        generationHistory[index].status = .completed
                        generationHistory[index].openscadCode = response.openscadCode
                        generationHistory[index].explanation = response.explanation
                        generationHistory[index].estimatedPrintTime = response.estimatedPrintTime
                    }

                    // HapticFeedback.success() // TODO: Add back when properly integrated

                } catch {
                    await MainActor.run {
                        generationHistory[index].status = .failed
                        generationHistory[index].errorMessage = error.localizedDescription
                    }

                    // HapticFeedback.error() // TODO: Add back when properly integrated
                }
            }
        }

        promptText = ""
        showingPromptSheet = false
    }

    private func printGeneration(code: String, name: String) {
        Task {
            do {
                let response = try await apiService.runFullPipeline(prompt: name)

                let job = PrintJob(
                    name: name,
                    prompt: name,
                    filePath: response.gcodePath,
                    fileName: "\(name.replacingOccurrences(of: " ", with: "_")).3mf",
                    estimatedPrintTime: response.estimatedPrintTime
                )

                try await printerManager.sendPrintJob(job)
                // HapticFeedback.success() // TODO: Add back when properly integrated

            } catch {
                // Show error
                // HapticFeedback.error() // TODO: Add back when properly integrated
            }
        }
    }

    private func showSamplePrompts() {
        let samples = [
            "a simple phone stand with 45 degree angle",
            "a desk organizer with 3 pen holders",
            "a small cable management box",
            "a minimalist bookmark with geometric pattern"
        ]

        promptText = samples.randomElement() ?? samples[0]
        showingPromptSheet = true
    }
}

// MARK: - Supporting Views
struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: BambuSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(BambuTextStyle.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(BambuSpacing.md)
            .background(Color.surfaceSecondary)
            .cornerRadius(BambuRadius.md)
        }
        .buttonStyle(.plain)
    }
}

struct GenerationHistoryCard: View {
    let request: GenerationRequest
    let onPrint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BambuSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.prompt)
                        .font(BambuTextStyle.callout)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Text(request.timestamp, style: .relative)
                        .font(BambuTextStyle.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusIndicator(
                    request.status == .completed ? .success :
                    request.status == .generating ? .printing :
                    request.status == .failed ? .error : .idle,
                    showLabel: false
                )
            }

            if request.status == .completed {
                HStack {
                    if let explanation = request.explanation {
                        Text(explanation)
                            .font(BambuTextStyle.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }

                    Spacer()

                    Button("Print") {
                        onPrint()
                    }
                    .bambuPrimaryButton()
                }
            }
        }
        .bambuCard()
    }
}

struct PromptInputSheet: View {
    @Binding var promptText: String
    let onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: BambuSpacing.lg) {
                VStack(alignment: .leading, spacing: BambuSpacing.md) {
                    Text("Describe what you want to print")
                        .font(BambuTextStyle.headline)

                    TextField("e.g., a phone stand with cable management", text: $promptText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                VStack(alignment: .leading, spacing: BambuSpacing.sm) {
                    Text("Tips for better results:")
                        .font(BambuTextStyle.caption)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Be specific about size and dimensions")
                        Text("• Mention intended use or function")
                        Text("• Include style preferences")
                        Text("• Consider 3D printing constraints")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .bambuCard()

                Spacer()

                Button("Generate Model") {
                    onGenerate()
                }
                .bambuPrimaryButton()
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(BambuSpacing.lg)
            .navigationTitle("New Generation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(APIService())
        .environment(PrinterManager())
}