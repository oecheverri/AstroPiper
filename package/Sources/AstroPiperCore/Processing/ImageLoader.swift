import Foundation
import CoreImage
import CoreGraphics
import ImageIO

public struct ImageLoader {
    
    /// Load an astronomical image from a file URL
    /// - Parameter url: File URL to the image
    /// - Returns: Loaded AstroImage instance
    /// - Throws: ImageLoaderError for loading failures
    public static func load(from url: URL) async throws -> any AstroImage {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        
        return try await load(data: data, fileName: fileName)
    }
    
    /// Load an astronomical image from raw data
    /// - Parameters:
    ///   - data: Raw image data
    ///   - fileName: Original filename for format detection
    /// - Returns: Loaded AstroImage instance
    /// - Throws: ImageLoaderError for loading failures
    public static func load(data: Data, fileName: String) async throws -> any AstroImage {
        guard let format = detectFormat(from: fileName, data: data) else {
            throw ImageLoaderError.unsupportedFormat(fileName)
        }
        
        return try StandardAstroImage(
            imageData: data,
            fileName: fileName,
            format: format
        )
    }
    
    /// Detect image format from filename and data
    /// - Parameters:
    ///   - fileName: Original filename
    ///   - data: Raw image data
    /// - Returns: Detected ImageFormat or nil if unsupported
    static func detectFormat(from fileName: String, data: Data) -> ImageFormat? {
        let pathExtension = (fileName as NSString).pathExtension.lowercased()
        
        // First try extension-based detection
        for format in ImageFormat.allCases {
            if format.fileExtensions.contains(pathExtension) {
                return format
            }
        }
        
        // Fall back to magic number detection
        return detectFormatFromMagicNumbers(data)
    }
    
    /// Detect format using magic number signatures
    /// - Parameter data: Raw image data
    /// - Returns: Detected ImageFormat or nil
    private static func detectFormatFromMagicNumbers(_ data: Data) -> ImageFormat? {
        guard data.count >= 8 else { return nil }
        
        let bytes = Array(data.prefix(8))
        
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }
        
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
           bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A {
            return .png
        }
        
        // TIFF: II*\0 (little endian) or MM\0* (big endian)
        if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
           (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
            return .tiff
        }
        
        return nil
    }
}

public struct MetadataExtractor {
    
    /// Extract comprehensive metadata from an image file
    /// - Parameter url: Image file URL
    /// - Returns: Extracted StandardImageMetadata
    /// - Throws: ImageLoaderError for extraction failures
    public static func extractMetadata(from url: URL) async throws -> StandardImageMetadata {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        
        return try await extractMetadata(from: data, fileName: fileName)
    }
    
    /// Extract metadata from image data
    /// - Parameters:
    ///   - data: Raw image data
    ///   - fileName: Original filename
    /// - Returns: Extracted StandardImageMetadata
    /// - Throws: ImageLoaderError for extraction failures
    public static func extractMetadata(from data: Data, fileName: String) async throws -> StandardImageMetadata {
        guard let format = ImageLoader.detectFormat(from: fileName, data: data) else {
            throw ImageLoaderError.unsupportedFormat(fileName)
        }
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageLoaderError.metadataExtractionFailed
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw ImageLoaderError.metadataExtractionFailed
        }
        
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        
        // Extract color profile information
        let colorSpace = extractColorSpace(from: properties)
        
        // Extract creation date if available
        var creationDate: Date?
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            creationDate = parseExifDate(dateTimeString)
        }
        
        return StandardImageMetadata(
            width: width,
            height: height,
            pixelFormat: .uint8, // Standard images typically use 8-bit
            colorSpace: colorSpace,
            creationDate: creationDate,
            fileSize: data.count,
            fileName: fileName,
            format: format
        )
    }
    
    /// Extract color space information from image properties
    /// - Parameter properties: CGImageSource properties dictionary
    /// - Returns: Detected ColorSpace
    private static func extractColorSpace(from properties: [String: Any]) -> ColorSpace {
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            switch colorModel {
            case String(kCGImagePropertyColorModelGray):
                return .grayscale
            case String(kCGImagePropertyColorModelRGB):
                // Default to sRGB for RGB images - profile inspection would be more complex
                return .sRGB
            default:
                return .sRGB
            }
        }
        
        return .sRGB // Default fallback
    }
    
    /// Parse EXIF date string into Date object
    /// - Parameter dateString: EXIF date string (YYYY:MM:DD HH:MM:SS format)
    /// - Returns: Parsed Date or nil if parsing fails
    private static func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

public enum ImageLoaderError: Error, Sendable, LocalizedError {
    case unsupportedFormat(String)
    case metadataExtractionFailed
    case imageCreationFailed
    case fileNotFound(String)
    case dataCorruption
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let filename):
            return "Unsupported image format for file: \(filename)"
        case .metadataExtractionFailed:
            return "Failed to extract metadata from image"
        case .imageCreationFailed:
            return "Failed to create image from data"
        case .fileNotFound(let path):
            return "Image file not found at path: \(path)"
        case .dataCorruption:
            return "Image data appears to be corrupted"
        }
    }
}