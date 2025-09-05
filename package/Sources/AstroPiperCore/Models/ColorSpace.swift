import Foundation

/// Represents color spaces used in astronomical imaging
/// 
/// Supports both standard color spaces for display and scientific linear color spaces
/// commonly used in astronomical image processing and analysis.
public enum ColorSpace: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case sRGB
    case displayP3
    case rec2020
    case linear
    case grayscale
    case cie1931XYZ
    
    /// Number of color channels in this color space
    public var channelCount: Int {
        switch self {
        case .grayscale: return 1
        default: return 3
        }
    }
    
    /// Whether this color space represents monochrome images
    public var isMonochrome: Bool {
        return self == .grayscale
    }
    
    /// Whether this color space uses linear light representation
    public var isLinear: Bool {
        return self == .linear
    }
    
    /// White point information for color spaces that define one
    public var whitePoint: WhitePoint? {
        switch self {
        case .sRGB, .displayP3, .rec2020: return .d65
        default: return nil
        }
    }
    
    /// Relative gamut coverage compared to visible spectrum (0.0 to 1.0)
    public var gamutCoverage: Double {
        switch self {
        case .sRGB: return 0.35
        case .displayP3: return 0.45
        case .rec2020: return 0.75
        case .grayscale: return 0.0
        default: return 0.5
        }
    }
    
    /// Names of individual channels in this color space
    public var channelNames: [String] {
        switch self {
        case .grayscale: return ["Luminance"]
        case .cie1931XYZ: return ["X", "Y", "Z"]
        default: return ["Red", "Green", "Blue"]
        }
    }
    
    /// Whether this color space can be converted to the target color space
    public func canConvertTo(_ target: ColorSpace) -> Bool {
        return true  // Minimal implementation - assume all conversions possible
    }
    
    /// Standard white points used in color space definitions
    public enum WhitePoint: String, Sendable, Codable, Equatable {
        case d65
        case d50
        case illuminantA
        case illuminantC
    }
}