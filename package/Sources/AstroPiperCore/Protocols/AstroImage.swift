import Foundation

/// Master protocol for astronomical image representations
/// 
/// Provides a unified interface for accessing pixel data, generating histograms,
/// and performing common image processing operations across different file formats.
/// All implementations must be Sendable for safe concurrent processing.
public protocol AstroImage: Sendable {
    
    /// Comprehensive metadata about the image
    var metadata: any AstroImageMetadata { get }
    
    // MARK: - Pixel Data Access
    
    /// Retrieve pixel data for the entire image or a specific region
    /// - Parameter region: Optional region to extract, nil for entire image
    /// - Returns: Raw pixel data in the format specified by metadata.pixelFormat
    /// - Throws: AstroImageError for I/O or processing errors
    func pixelData(in region: PixelRegion?) async throws -> Data
    
    // MARK: - Histogram Generation
    
    /// Generate histogram data for image analysis and processing
    /// - Returns: Complete histogram with statistics and percentile data
    /// - Throws: AstroImageError if histogram computation fails
    func generateHistogram() async throws -> HistogramData
    
    // MARK: - Bayer Pattern Processing
    
    /// Check if this image supports Bayer pattern demosaicing
    /// - Returns: true if demosaicing is available for this image
    func supportsBayerDemosaic() -> Bool
    
    /// Perform Bayer pattern demosaicing to create RGB image
    /// - Parameter bayerPattern: The Bayer pattern arrangement used
    /// - Returns: Demosaiced RGB image
    /// - Throws: AstroImageError.demosaicNotSupported if not supported
    func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage
}

// MARK: - Supporting Types

/// Represents a rectangular region within an image
public struct PixelRegion: Sendable, Codable, Equatable {
    /// X coordinate of the region's top-left corner
    public let x: UInt32
    
    /// Y coordinate of the region's top-left corner  
    public let y: UInt32
    
    /// Width of the region in pixels
    public let width: UInt32
    
    /// Height of the region in pixels
    public let height: UInt32
    
    public init(x: UInt32, y: UInt32, width: UInt32, height: UInt32) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Bayer pattern arrangements used in astronomical cameras
public enum BayerPattern: String, Sendable, Codable, CaseIterable {
    case rggb = "RGGB"
    case bggr = "BGGR" 
    case grbg = "GRBG"
    case gbrg = "GBRG"
    
    /// Get the color at a specific pixel position
    public func colorAt(x: Int, y: Int) -> BayerColor {
        let isEvenRow = (y % 2) == 0
        let isEvenCol = (x % 2) == 0
        
        switch self {
        case .rggb:
            return (isEvenRow && isEvenCol) ? .red : 
                   (isEvenRow && !isEvenCol) ? .green : 
                   (!isEvenRow && isEvenCol) ? .green : .blue
        case .bggr:
            return (isEvenRow && isEvenCol) ? .blue : 
                   (isEvenRow && !isEvenCol) ? .green : 
                   (!isEvenRow && isEvenCol) ? .green : .red
        case .grbg:
            return (isEvenRow && isEvenCol) ? .green : 
                   (isEvenRow && !isEvenCol) ? .red : 
                   (!isEvenRow && isEvenCol) ? .blue : .green
        case .gbrg:
            return (isEvenRow && isEvenCol) ? .green : 
                   (isEvenRow && !isEvenCol) ? .blue : 
                   (!isEvenRow && isEvenCol) ? .red : .green
        }
    }
    
    /// Bayer color components
    public enum BayerColor: String, Sendable, Codable {
        case red = "R"
        case green = "G"
        case blue = "B"
    }
}

/// Errors that can occur during astronomical image operations
public enum AstroImageError: Error, Sendable, LocalizedError {
    case demosaicNotSupported
    case regionOutOfBounds(PixelRegion)
    case invalidPixelFormat
    case dataCorruption
    case memoryAllocationFailed
    case processingTimeout
    case customError(String)
    
    public var errorDescription: String? {
        switch self {
        case .demosaicNotSupported:
            return "Bayer demosaicing is not supported for this image"
        case .regionOutOfBounds(let region):
            return "Requested region \(region) is outside image bounds"
        case .invalidPixelFormat:
            return "Invalid or unsupported pixel format"
        case .dataCorruption:
            return "Image data appears to be corrupted"
        case .memoryAllocationFailed:
            return "Failed to allocate sufficient memory for operation"
        case .processingTimeout:
            return "Image processing operation timed out"
        case .customError(let message):
            return message
        }
    }
}