import Foundation

/// Represents different pixel data formats used in astronomical imaging
/// 
/// Supports various bit depths and data types commonly found in astronomical images,
/// from basic 8-bit display formats to high-precision 64-bit floating point scientific data.
/// All formats are designed to be Sendable for safe concurrent processing.
public enum PixelFormat: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case uint8
    case uint16
    case uint32
    case int16
    case int32
    case float32
    case float64
    
    /// The number of bits per pixel for this format
    public var bitDepth: Int {
        switch self {
        case .uint8: return 8
        case .uint16: return 16
        case .uint32: return 32
        case .int16: return 16
        case .int32: return 32
        case .float32: return 32
        case .float64: return 64
        }
    }
    
    /// The number of bytes per pixel for this format
    public var bytesPerPixel: Int {
        return bitDepth / 8
    }
    
    /// Calculate memory footprint for given number of pixels
    public func memoryFootprint(for pixelCount: Int) -> Int {
        return pixelCount * bytesPerPixel
    }
    
    /// Whether this format uses floating point representation
    public var isFloatingPoint: Bool {
        switch self {
        case .float32, .float64: return true
        default: return false
        }
    }
    
    /// Whether this format uses signed representation
    public var isSigned: Bool {
        switch self {
        case .int16, .int32, .float32, .float64: return true
        default: return false
        }
    }
}