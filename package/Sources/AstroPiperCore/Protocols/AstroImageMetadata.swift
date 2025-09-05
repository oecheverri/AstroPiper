import Foundation

/// Protocol for astronomical image metadata
/// 
/// Provides universal access to image properties across different file formats,
/// supporting both standard image metadata and astronomical-specific information.
/// All implementations must be Sendable for safe concurrent access.
public protocol AstroImageMetadata: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    
    // MARK: - Basic Image Properties
    
    /// Image dimensions in pixels
    var dimensions: ImageDimensions { get }
    
    /// Pixel data format (bit depth and type)
    var pixelFormat: PixelFormat { get }
    
    /// Color space representation
    var colorSpace: ColorSpace { get }
    
    // MARK: - File Information
    
    /// Original filename if available
    var filename: String? { get }
    
    /// File size in bytes if known
    var fileSize: UInt64? { get }
    
    /// File creation date
    var creationDate: Date? { get }
    
    /// File modification date
    var modificationDate: Date? { get }
    
    // MARK: - Astronomical Metadata (Optional)
    
    /// Exposure duration in seconds
    var exposureTime: TimeInterval? { get }
    
    /// ISO sensitivity value
    var iso: Int? { get }
    
    /// Telescope identifier
    var telescopeName: String? { get }
    
    /// Camera/instrument identifier
    var instrumentName: String? { get }
    
    /// Optical filter used
    var filterName: String? { get }
    
    /// Target object name
    var objectName: String? { get }
    
    /// Observation timestamp
    var observationDate: Date? { get }
    
    /// Sky coordinates if available
    var coordinates: SkyCoordinates? { get }
    
    /// Sensor temperature in Celsius
    var temperature: Double? { get }
    
    /// Camera gain setting
    var gain: Double? { get }
    
    /// Pixel binning configuration
    var binning: ImageBinning? { get }
    
    /// Format-specific custom metadata  
    var customMetadata: [String: String] { get }
    
    // MARK: - Computed Properties
    
    /// Total number of pixels in the image
    var totalPixels: UInt64 { get }
    
    /// Image aspect ratio (width/height)
    var aspectRatio: Double { get }
    
    /// Image size in megapixels
    var megapixels: Double { get }
    
    /// Whether basic image information is available
    var hasBasicImageInfo: Bool { get }
    
    /// Whether astronomical metadata is available
    var hasAstronomicalInfo: Bool { get }
    
    /// Metadata completeness score (0.0 to 1.0)
    var completenessScore: Double { get }
    
    // MARK: - Custom Metadata Access
    
    /// Retrieve custom metadata value by key
    func customValue(for key: String) -> String?
}

// MARK: - Default Implementations

public extension AstroImageMetadata {
    
    var totalPixels: UInt64 {
        return UInt64(dimensions.width) * UInt64(dimensions.height)
    }
    
    var aspectRatio: Double {
        guard dimensions.height > 0 else { return 1.0 }
        return Double(dimensions.width) / Double(dimensions.height)
    }
    
    var megapixels: Double {
        return Double(totalPixels) / 1_000_000.0
    }
    
    var hasBasicImageInfo: Bool {
        return dimensions.width > 0 && dimensions.height > 0
    }
    
    var hasAstronomicalInfo: Bool {
        return objectName != nil || telescopeName != nil || exposureTime != nil
    }
    
    var completenessScore: Double {
        var score = 0.0
        let fields = [objectName, telescopeName, filterName, exposureTime != nil ? "exposure" : nil]
        let nonNilFields = fields.compactMap { $0 }.count
        score = Double(nonNilFields) / Double(fields.count)
        return max(0.0, min(1.0, score))
    }
    
    func customValue(for key: String) -> String? {
        return nil  // Minimal implementation
    }
    
    var description: String {
        return "AstroImage \(dimensions.width)x\(dimensions.height) (\(String(format: "%.1f", megapixels))MP)"
    }
    
    var debugDescription: String {
        return description + " - PixelFormat: \(pixelFormat), ColorSpace: \(colorSpace)"
    }
}

// MARK: - Supporting Types

/// Represents image dimensions
public struct ImageDimensions: Sendable, Codable, Equatable {
    public let width: UInt32
    public let height: UInt32
    
    public init(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }
}

/// Represents astronomical coordinates
public struct SkyCoordinates: Sendable, Codable, Equatable {
    /// Right ascension in degrees
    public let rightAscension: Double
    
    /// Declination in degrees  
    public let declination: Double
    
    /// Coordinate epoch (e.g., 2000.0 for J2000)
    public let epoch: Double
    
    public init(rightAscension: Double, declination: Double, epoch: Double = 2000.0) {
        self.rightAscension = rightAscension
        self.declination = declination
        self.epoch = epoch
    }
}

/// Represents pixel binning configuration
public struct ImageBinning: Sendable, Codable, Equatable {
    /// Horizontal binning factor
    public let horizontal: Int
    
    /// Vertical binning factor
    public let vertical: Int
    
    public init(horizontal: Int, vertical: Int) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    
    /// Square binning convenience initializer
    public init(_ factor: Int) {
        self.horizontal = factor
        self.vertical = factor
    }
}