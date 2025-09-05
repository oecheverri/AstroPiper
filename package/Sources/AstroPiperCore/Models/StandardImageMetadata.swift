import Foundation

public struct StandardImageMetadata: AstroImageMetadata, Sendable, Codable, Equatable, Hashable {
    
    private let _width: UInt32
    private let _height: UInt32
    private let _pixelFormat: PixelFormat
    private let _colorSpace: ColorSpace
    private let _creationDate: Date?
    private let _fileSize: UInt64?
    private let _fileName: String
    public let format: ImageFormat
    
    public init(
        width: Int,
        height: Int,
        pixelFormat: PixelFormat,
        colorSpace: ColorSpace,
        creationDate: Date?,
        fileSize: Int?,
        fileName: String,
        format: ImageFormat
    ) {
        self._width = UInt32(max(0, width))
        self._height = UInt32(max(0, height))
        self._pixelFormat = pixelFormat
        self._colorSpace = colorSpace
        self._creationDate = creationDate
        self._fileSize = fileSize.map { UInt64($0) }
        self._fileName = fileName
        self.format = format
    }
    
    // MARK: - AstroImageMetadata Protocol
    
    public var dimensions: ImageDimensions {
        ImageDimensions(width: _width, height: _height)
    }
    
    public var pixelFormat: PixelFormat { _pixelFormat }
    public var colorSpace: ColorSpace { _colorSpace }
    public var filename: String? { _fileName }
    public var fileSize: UInt64? { _fileSize }
    public var creationDate: Date? { _creationDate }
    public var modificationDate: Date? { nil } // Standard images don't track modification separately
    
    // MARK: - Astronomical Metadata (nil for standard images)
    public var exposureTime: TimeInterval? { nil }
    public var iso: Int? { nil }
    public var telescopeName: String? { nil }
    public var instrumentName: String? { nil }
    public var filterName: String? { nil }
    public var objectName: String? { nil }
    public var observationDate: Date? { nil }
    public var coordinates: SkyCoordinates? { nil }
    public var temperature: Double? { nil }
    public var gain: Double? { nil }
    public var binning: ImageBinning? { nil }
    public var customMetadata: [String: String] { [:] }
    
    // MARK: - Convenience Properties  
    public var width: Int { Int(dimensions.width) }
    public var height: Int { Int(dimensions.height) }
    public var fileName: String { _fileName }
}

public enum ImageFormat: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case jpeg
    case png  
    case tiff
    
    public var fileExtensions: Set<String> {
        switch self {
        case .jpeg:
            return ["jpg", "jpeg"]
        case .png:
            return ["png"]
        case .tiff:
            return ["tiff", "tif"]
        }
    }
    
    public var mimeType: String {
        switch self {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        case .tiff:
            return "image/tiff"
        }
    }
}