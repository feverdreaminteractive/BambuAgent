import SwiftUI
import Foundation

// MARK: - Filament Models
struct Filament: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let brand: FilamentBrand
    let material: FilamentMaterial
    let color: FilamentColor
    let diameter: Double
    var nozzleTemperature: TemperatureRange
    var bedTemperature: TemperatureRange
    var isLoaded: Bool = false
    var slotNumber: Int? // AMS slot if applicable
    var remainingWeight: Double? // in grams

    init(
        name: String,
        brand: FilamentBrand,
        material: FilamentMaterial,
        color: FilamentColor,
        diameter: Double = 1.75,
        nozzleTemp: TemperatureRange,
        bedTemp: TemperatureRange
    ) {
        self.name = name
        self.brand = brand
        self.material = material
        self.color = color
        self.diameter = diameter
        self.nozzleTemperature = nozzleTemp
        self.bedTemperature = bedTemp
    }

    var displayName: String {
        "\(brand.name) \(name) (\(material.rawValue))"
    }

    var temperatureInfo: String {
        "Nozzle: \(nozzleTemperature.display) | Bed: \(bedTemperature.display)"
    }
}

enum FilamentBrand: String, CaseIterable, Codable {
    case bambu = "Bambu Lab"
    case polymaker = "Polymaker"
    case prusament = "Prusament"
    case hatchbox = "HATCHBOX"
    case overture = "OVERTURE"
    case sunlu = "SUNLU"
    case esun = "eSUN"
    case generic = "Generic"

    var name: String {
        return self.rawValue
    }

    var logo: String {
        switch self {
        case .bambu: return "cube.transparent.fill"
        case .polymaker: return "cube.fill"
        case .prusament: return "cube"
        default: return "cube.transparent"
        }
    }
}

enum FilamentMaterial: String, CaseIterable, Codable {
    case pla = "PLA"
    case abs = "ABS"
    case petg = "PETG"
    case tpu = "TPU"
    case pla_cf = "PLA-CF"
    case abs_cf = "ABS-CF"
    case pa_cf = "PA-CF"
    case pva = "PVA"
    case hips = "HIPS"

    var color: Color {
        switch self {
        case .pla: return .green
        case .abs: return .blue
        case .petg: return .purple
        case .tpu: return .orange
        case .pla_cf, .abs_cf, .pa_cf: return .black
        case .pva: return .cyan
        case .hips: return .yellow
        }
    }

    var defaultNozzleTemp: TemperatureRange {
        switch self {
        case .pla: return TemperatureRange(min: 190, max: 220, recommended: 210)
        case .abs: return TemperatureRange(min: 240, max: 270, recommended: 250)
        case .petg: return TemperatureRange(min: 220, max: 250, recommended: 235)
        case .tpu: return TemperatureRange(min: 200, max: 230, recommended: 215)
        case .pla_cf: return TemperatureRange(min: 220, max: 250, recommended: 235)
        case .abs_cf: return TemperatureRange(min: 260, max: 290, recommended: 275)
        case .pa_cf: return TemperatureRange(min: 280, max: 320, recommended: 300)
        case .pva: return TemperatureRange(min: 190, max: 220, recommended: 205)
        case .hips: return TemperatureRange(min: 220, max: 250, recommended: 235)
        }
    }

    var defaultBedTemp: TemperatureRange {
        switch self {
        case .pla: return TemperatureRange(min: 45, max: 65, recommended: 55)
        case .abs: return TemperatureRange(min: 80, max: 110, recommended: 95)
        case .petg: return TemperatureRange(min: 60, max: 80, recommended: 70)
        case .tpu: return TemperatureRange(min: 40, max: 60, recommended: 50)
        case .pla_cf: return TemperatureRange(min: 50, max: 70, recommended: 60)
        case .abs_cf: return TemperatureRange(min: 85, max: 115, recommended: 100)
        case .pa_cf: return TemperatureRange(min: 100, max: 130, recommended: 115)
        case .pva: return TemperatureRange(min: 45, max: 65, recommended: 55)
        case .hips: return TemperatureRange(min: 70, max: 100, recommended: 85)
        }
    }
}

struct FilamentColor: Codable, Hashable {
    let name: String
    let hexCode: String

    var color: Color {
        Color(hex: hexCode)
    }

    static let presets: [FilamentColor] = [
        FilamentColor(name: "White", hexCode: "#FFFFFF"),
        FilamentColor(name: "Black", hexCode: "#2C2C2C"),
        FilamentColor(name: "Red", hexCode: "#E53E3E"),
        FilamentColor(name: "Blue", hexCode: "#3182CE"),
        FilamentColor(name: "Green", hexCode: "#38A169"),
        FilamentColor(name: "Yellow", hexCode: "#D69E2E"),
        FilamentColor(name: "Orange", hexCode: "#DD6B20"),
        FilamentColor(name: "Purple", hexCode: "#805AD5"),
        FilamentColor(name: "Pink", hexCode: "#D53F8C"),
        FilamentColor(name: "Gray", hexCode: "#718096"),
        FilamentColor(name: "Clear", hexCode: "#E2E8F0"),
        FilamentColor(name: "Wood", hexCode: "#8B4513"),
        FilamentColor(name: "Metal", hexCode: "#A0AEC0"),
        FilamentColor(name: "Carbon", hexCode: "#1A202C")
    ]
}

struct TemperatureRange: Codable, Hashable {
    let min: Int
    let max: Int
    let recommended: Int

    var display: String {
        "\(recommended)°C (\(min)-\(max)°C)"
    }
}

// MARK: - Build Plate Models
struct BuildPlate: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let material: PlateMaterial
    let size: PlateSize
    let texture: PlateTexture
    var isInstalled: Bool = false
    var isActive: Bool = false

    var displayName: String {
        "\(material.displayName) \(texture.displayName)"
    }

    var suitableFilaments: [FilamentMaterial] {
        material.compatibleMaterials
    }

    var temperatureRange: TemperatureRange {
        material.temperatureRange
    }
}

enum PlateMaterial: String, CaseIterable, Codable {
    case smooth_pei = "Smooth PEI"
    case textured_pei = "Textured PEI"
    case glass = "Glass"
    case spring_steel = "Spring Steel"
    case carbon_fiber = "Carbon Fiber"

    var displayName: String {
        return self.rawValue
    }

    var color: Color {
        switch self {
        case .smooth_pei: return .black
        case .textured_pei: return .gray
        case .glass: return .blue.opacity(0.3)
        case .spring_steel: return .gray
        case .carbon_fiber: return .black
        }
    }

    var compatibleMaterials: [FilamentMaterial] {
        switch self {
        case .smooth_pei:
            return [.pla, .abs, .petg, .tpu, .pla_cf]
        case .textured_pei:
            return [.abs, .petg, .abs_cf, .pa_cf, .hips]
        case .glass:
            return [.pla, .petg, .pva]
        case .spring_steel:
            return [.pla, .abs, .petg, .tpu]
        case .carbon_fiber:
            return [.abs_cf, .pa_cf, .pla_cf]
        }
    }

    var temperatureRange: TemperatureRange {
        switch self {
        case .smooth_pei, .textured_pei:
            return TemperatureRange(min: 25, max: 120, recommended: 60)
        case .glass:
            return TemperatureRange(min: 25, max: 100, recommended: 60)
        case .spring_steel:
            return TemperatureRange(min: 25, max: 110, recommended: 60)
        case .carbon_fiber:
            return TemperatureRange(min: 25, max: 150, recommended: 100)
        }
    }
}

enum PlateTexture: String, CaseIterable, Codable {
    case smooth = "Smooth"
    case textured = "Textured"
    case matte = "Matte"

    var displayName: String {
        return self.rawValue
    }
}

struct PlateSize: Codable, Hashable {
    let width: Int
    let height: Int
    let depth: Int

    var displaySize: String {
        "\(width) × \(height) × \(depth) mm"
    }

    static let a1Mini = PlateSize(width: 180, height: 180, depth: 180)
    static let standard = PlateSize(width: 256, height: 256, depth: 256)
}

// MARK: - Sample Data
extension Filament {
    static let sampleFilaments: [Filament] = [
        Filament(
            name: "Basic PLA",
            brand: .bambu,
            material: .pla,
            color: FilamentColor(name: "White", hexCode: "#FFFFFF"),
            nozzleTemp: FilamentMaterial.pla.defaultNozzleTemp,
            bedTemp: FilamentMaterial.pla.defaultBedTemp
        ),
        Filament(
            name: "ABS",
            brand: .bambu,
            material: .abs,
            color: FilamentColor(name: "Black", hexCode: "#2C2C2C"),
            nozzleTemp: FilamentMaterial.abs.defaultNozzleTemp,
            bedTemp: FilamentMaterial.abs.defaultBedTemp
        ),
        Filament(
            name: "PETG",
            brand: .polymaker,
            material: .petg,
            color: FilamentColor(name: "Clear", hexCode: "#E2E8F0"),
            nozzleTemp: FilamentMaterial.petg.defaultNozzleTemp,
            bedTemp: FilamentMaterial.petg.defaultBedTemp
        ),
        Filament(
            name: "Flexible TPU",
            brand: .overture,
            material: .tpu,
            color: FilamentColor(name: "Red", hexCode: "#E53E3E"),
            nozzleTemp: FilamentMaterial.tpu.defaultNozzleTemp,
            bedTemp: FilamentMaterial.tpu.defaultBedTemp
        )
    ]
}

extension BuildPlate {
    static let samplePlates: [BuildPlate] = [
        BuildPlate(
            name: "Standard PEI",
            material: .smooth_pei,
            size: .a1Mini,
            texture: .smooth,
            isInstalled: true,
            isActive: true
        ),
        BuildPlate(
            name: "Textured Plate",
            material: .textured_pei,
            size: .a1Mini,
            texture: .textured,
            isInstalled: false
        ),
        BuildPlate(
            name: "Glass Bed",
            material: .glass,
            size: .a1Mini,
            texture: .smooth,
            isInstalled: false
        )
    ]
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}