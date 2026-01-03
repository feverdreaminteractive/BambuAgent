import SwiftUI
import Foundation

@Observable
class APIService {
    // MARK: - Published Properties
    var isConnected: Bool = false
    var serverURL: URL = URL(string: "http://localhost:8000")!
    var isGenerating: Bool = false
    var errorMessage: String?

    // MARK: - Private Properties
    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization
    init() {
        loadServerURL()
        checkServerConnection()
    }

    // MARK: - Server Configuration
    @MainActor
    func updateServerURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL format"
            return
        }

        serverURL = url
        saveServerURL()
        checkServerConnection()
    }

    @MainActor
    func checkServerConnection() {
        Task {
            isConnected = await testConnection()
        }
    }

    private func testConnection() async -> Bool {
        do {
            let url = serverURL.appendingPathComponent("/")
            let (_, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false

        } catch {
            await MainActor.run {
                errorMessage = "Connection failed: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - API Endpoints
    @MainActor
    func generateModel(from prompt: String) async throws -> GenerateResponse {
        isGenerating = true
        errorMessage = nil

        defer { isGenerating = false }

        do {
            let request = GenerateRequest(prompt: prompt)
            let response: GenerateResponse = try await performRequest(
                endpoint: "/generate",
                method: .POST,
                body: request
            )

            return response

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func compileModel(openscadCode: String, filename: String = "model") async throws -> CompileResponse {
        let request = CompileRequest(openscadCode: openscadCode, filename: filename)

        return try await performRequest(
            endpoint: "/compile",
            method: .POST,
            body: request
        )
    }

    func sliceModel(
        stlPath: String,
        filename: String = "model",
        layerHeight: Double = 0.2,
        infill: Double = 15.0
    ) async throws -> SliceResponse {
        let request = SliceRequest(
            stlPath: stlPath,
            filename: filename,
            layerHeight: layerHeight,
            infill: infill
        )

        return try await performRequest(
            endpoint: "/slice",
            method: .POST,
            body: request
        )
    }

    func sendToPrinter(filePath: String, printName: String = "BambuAgent Print") async throws -> PrintResponse {
        let request = PrintRequest(filePath: filePath, printName: printName)

        return try await performRequest(
            endpoint: "/print",
            method: .POST,
            body: request
        )
    }

    func getPrinterStatus() async throws -> PrinterStatusResponse {
        return try await performRequest(
            endpoint: "/printer/status",
            method: .GET
        )
    }

    func getRecentJobs() async throws -> JobsResponse {
        return try await performRequest(
            endpoint: "/printer/jobs",
            method: .GET
        )
    }

    @MainActor
    func runFullPipeline(prompt: String) async throws -> FullPipelineResponse {
        isGenerating = true
        errorMessage = nil

        defer { isGenerating = false }

        do {
            let request = GenerateRequest(prompt: prompt)
            let response: FullPipelineResponse = try await performRequest(
                endpoint: "/pipeline/full",
                method: .POST,
                body: request
            )

            return response

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Generic Request Handler
    private func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: T? = nil
    ) async throws -> U {
        let url = serverURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.detail)
            } else {
                throw APIError.httpError(httpResponse.statusCode)
            }
        }

        return try decoder.decode(U.self, from: data)
    }

    private func performRequest<U: Codable>(
        endpoint: String,
        method: HTTPMethod
    ) async throws -> U {
        let emptyBody: EmptyBody? = nil
        return try await performRequest(endpoint: endpoint, method: method, body: emptyBody)
    }

    // MARK: - Data Persistence
    private func saveServerURL() {
        UserDefaults.standard.set(serverURL.absoluteString, forKey: "ServerURL")
    }

    private func loadServerURL() {
        if let urlString = UserDefaults.standard.string(forKey: "ServerURL"),
           let url = URL(string: urlString) {
            serverURL = url
        }
    }
}

// MARK: - Supporting Types
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case encodingError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

private struct EmptyBody: Codable {}

// MARK: - API Models
struct GenerateRequest: Codable {
    let prompt: String
    let userId: String?

    init(prompt: String, userId: String? = "ios_user") {
        self.prompt = prompt
        self.userId = userId
    }
}

struct GenerateResponse: Codable {
    let openscadCode: String
    let explanation: String
    let estimatedPrintTime: String?
}

struct CompileRequest: Codable {
    let openscadCode: String
    let filename: String?
}

struct CompileResponse: Codable {
    let stlPath: String
    let success: Bool
    let errorMessage: String?
}

struct SliceRequest: Codable {
    let stlPath: String
    let filename: String?
    let layerHeight: Double?
    let infill: Double?
}

struct SliceResponse: Codable {
    let gcodePath: String
    let success: Bool
    let estimatedPrintTime: String?
    let filamentUsed: String?
    let errorMessage: String?
}

struct PrintRequest: Codable {
    let filePath: String
    let printName: String?
}

struct PrintResponse: Codable {
    let jobId: String
    let status: String
    let message: String
}

struct PrinterStatusResponse: Codable {
    let status: String
    let currentJob: PrintJobStatus?
    let bedTemperature: Double?
    let nozzleTemperature: Double?
    let progress: Double?
}

struct PrintJobStatus: Codable {
    let name: String
    let progress: Double
    let timeRemaining: String?
}

struct JobsResponse: Codable {
    let jobs: [PrintJobInfo]
}

struct PrintJobInfo: Codable {
    let id: String
    let name: String
    let status: String
    let createdAt: String
    let completedAt: String?
}

struct FullPipelineResponse: Codable {
    let jobId: String
    let message: String
    let openscadCode: String
    let stlPath: String
    let gcodePath: String
    let estimatedPrintTime: String?
}

struct APIErrorResponse: Codable {
    let detail: String
}