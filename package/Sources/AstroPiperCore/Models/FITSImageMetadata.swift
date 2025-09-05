import Foundation

/// Comprehensive FITS (Flexible Image Transport System) metadata model
/// 
/// Implements AstroImageMetadata with full support for FITS header keywords,
/// World Coordinate System information, and observatory-specific metadata.
/// Designed for astronomical imaging with proper scientific data handling.
public struct FITSImageMetadata: AstroImageMetadata, Sendable, Codable, Equatable, Hashable {
    
    // MARK: - Core FITS Properties
    
    /// Number of axes (dimensions) in the image
    public let naxis: Int
    
    /// Image dimensions from NAXIS1, NAXIS2, etc.
    private let axisSizes: [UInt32]
    
    /// Bits per pixel (BITPIX keyword)
    public let bitpix: Int
    
    /// Zero point for data scaling (BZERO keyword)
    public let bzero: Double?
    
    /// Scale factor for data values (BSCALE keyword) 
    public let bscale: Double?
    
    /// Original filename
    private let _filename: String
    
    /// File size in bytes
    private let _fileSize: UInt64?
    
    /// File creation timestamp
    private let _creationDate: Date?
    
    /// File modification timestamp  
    private let _modificationDate: Date?
    
    // MARK: - Observatory Metadata
    
    /// Telescope name (TELESCOP keyword)
    public let telescope: String?
    
    /// Instrument name (INSTRUME keyword)
    public let instrument: String?
    
    /// Observer name (OBSERVER keyword)
    public let observer: String?
    
    /// Target object name (OBJECT keyword)  
    public let object: String?
    
    /// Observation date/time (DATE-OBS keyword)
    public let dateObs: Date?
    
    /// Exposure time in seconds (EXPTIME keyword)
    public let exptime: TimeInterval?
    
    /// Filter name (FILTER keyword)
    public let filter: String?
    
    /// CCD temperature in Celsius (CCD-TEMP keyword)
    public let ccdTemp: Double?
    
    /// CCD gain (GAIN keyword)
    public let ccdGain: Double?
    
    /// Pixel binning (XBINNING, YBINNING keywords)
    public let binning: ImageBinning?
    
    // MARK: - World Coordinate System (WCS)
    
    /// WCS coordinate information
    public let wcs: WCSInfo?
    
    // MARK: - Custom FITS Headers
    
    /// Complete FITS header as key-value pairs
    public let fitsHeaders: [String: String]
    
    // MARK: - Initialization
    
    public init(
        naxis: Int,
        axisSizes: [UInt32],
        bitpix: Int,
        bzero: Double? = nil,
        bscale: Double? = nil,
        filename: String,
        fileSize: UInt64? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        telescope: String? = nil,
        instrument: String? = nil,
        observer: String? = nil,
        object: String? = nil,
        dateObs: Date? = nil,
        exptime: TimeInterval? = nil,
        filter: String? = nil,
        ccdTemp: Double? = nil,
        ccdGain: Double? = nil,
        binning: ImageBinning? = nil,
        wcs: WCSInfo? = nil,
        fitsHeaders: [String: String] = [:]
    ) {
        self.naxis = naxis
        self.axisSizes = axisSizes
        self.bitpix = bitpix
        self.bzero = bzero
        self.bscale = bscale
        self._filename = filename
        self._fileSize = fileSize
        self._creationDate = creationDate
        self._modificationDate = modificationDate
        self.telescope = telescope
        self.instrument = instrument
        self.observer = observer
        self.object = object
        self.dateObs = dateObs
        self.exptime = exptime
        self.filter = filter
        self.ccdTemp = ccdTemp
        self.ccdGain = ccdGain
        self.binning = binning
        self.wcs = wcs
        self.fitsHeaders = fitsHeaders
    }
    
    // MARK: - AstroImageMetadata Conformance
    
    public var dimensions: ImageDimensions {
        let width = axisSizes.first ?? 0
        let height = axisSizes.count > 1 ? axisSizes[1] : 1
        return ImageDimensions(width: width, height: height)
    }
    
    public var pixelFormat: PixelFormat {
        switch bitpix {
        case 8: return .uint8
        case 16: return .int16  // FITS uses signed 16-bit by default
        case 32: return .int32
        case -32: return .float32
        case -64: return .float64
        default: return .uint16 // Fallback
        }
    }
    
    public var colorSpace: ColorSpace {
        return .grayscale // FITS images are typically monochrome
    }
    
    public var filename: String? { _filename }
    public var fileSize: UInt64? { _fileSize }
    public var creationDate: Date? { _creationDate }
    public var modificationDate: Date? { _modificationDate }
    
    // MARK: - Astronomical Metadata
    
    public var exposureTime: TimeInterval? { exptime }
    public var iso: Int? { nil } // Not applicable to scientific cameras
    public var telescopeName: String? { telescope }
    public var instrumentName: String? { instrument }
    public var filterName: String? { filter }
    public var objectName: String? { object }
    public var observationDate: Date? { dateObs }
    public var coordinates: SkyCoordinates? { wcs?.referenceCoordinates }
    public var temperature: Double? { ccdTemp }
    public var gain: Double? { ccdGain }
    
    public var customMetadata: [String: String] { fitsHeaders }
    
    // MARK: - Custom Value Access
    
    public func customValue(for key: String) -> String? {
        return fitsHeaders[key.uppercased()]
    }
    
    // MARK: - FITS-Specific Properties
    
    /// Calculate the actual pixel value using BZERO and BSCALE
    /// - Parameter rawValue: Raw pixel value from file
    /// - Returns: Scaled physical value
    public func physicalValue(from rawValue: Double) -> Double {
        let scale = bscale ?? 1.0
        let zero = bzero ?? 0.0
        return scale * rawValue + zero
    }
    
    /// Get the data type size in bytes
    public var bytesPerPixel: Int {
        switch abs(bitpix) {
        case 8: return 1
        case 16: return 2  
        case 32: return 4
        case 64: return 8
        default: return 2
        }
    }
    
    /// Check if this is a signed integer format
    public var isSignedInteger: Bool {
        return bitpix > 0 && bitpix != 8
    }
    
    /// Check if this is a floating-point format
    public var isFloatingPoint: Bool {
        return bitpix < 0
    }
}

// MARK: - WCS Supporting Types

/// Represents pixel coordinates in FITS reference frame
public struct PixelCoordinate: Sendable, Codable, Equatable, Hashable {
    /// X coordinate (CRPIX1)
    public let x: Double
    
    /// Y coordinate (CRPIX2)  
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Represents world coordinates in degrees
public struct WorldCoordinate: Sendable, Codable, Equatable, Hashable {
    /// Longitude coordinate (CRVAL1) in degrees
    public let longitude: Double
    
    /// Latitude coordinate (CRVAL2) in degrees
    public let latitude: Double
    
    public init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }
}

/// Represents pixel scale in degrees per pixel
public struct PixelScale: Sendable, Codable, Equatable, Hashable {
    /// X-axis scale (CDELT1) in degrees per pixel
    public let x: Double
    
    /// Y-axis scale (CDELT2) in degrees per pixel
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Represents coordinate system types from FITS headers
public struct CoordinateTypes: Sendable, Codable, Equatable, Hashable {
    /// X-axis coordinate type (CTYPE1)
    public let x: String
    
    /// Y-axis coordinate type (CTYPE2) 
    public let y: String
    
    public init(x: String, y: String) {
        self.x = x
        self.y = y
    }
}

/// World Coordinate System information from FITS headers
public struct WCSInfo: Sendable, Codable, Equatable, Hashable {
    
    /// Reference pixel coordinates (CRPIX1, CRPIX2)
    public let referencePixel: PixelCoordinate
    
    /// Reference world coordinates (CRVAL1, CRVAL2) in degrees
    public let referenceValue: WorldCoordinate
    
    /// Pixel scale (CDELT1, CDELT2) in degrees per pixel
    public let pixelScale: PixelScale
    
    /// Coordinate system types (CTYPE1, CTYPE2)
    public let coordinateTypes: CoordinateTypes
    
    /// Projection type (e.g., "TAN", "SIN", "ARC")
    public let projection: String?
    
    /// Coordinate system name (e.g., "ICRS", "FK5")
    public let coordinateSystem: String?
    
    /// Equinox year (EQUINOX keyword)
    public let equinox: Double?
    
    public init(
        referencePixel: PixelCoordinate,
        referenceValue: WorldCoordinate,
        pixelScale: PixelScale,
        coordinateTypes: CoordinateTypes,
        projection: String? = nil,
        coordinateSystem: String? = nil,
        equinox: Double? = nil
    ) {
        self.referencePixel = referencePixel
        self.referenceValue = referenceValue
        self.pixelScale = pixelScale
        self.coordinateTypes = coordinateTypes
        self.projection = projection
        self.coordinateSystem = coordinateSystem
        self.equinox = equinox
    }
    
    /// Get reference coordinates as SkyCoordinates
    public var referenceCoordinates: SkyCoordinates {
        let epoch = equinox ?? 2000.0
        return SkyCoordinates(
            rightAscension: referenceValue.longitude,
            declination: referenceValue.latitude,
            epoch: epoch
        )
    }
    
    /// Calculate world coordinates for a given pixel position
    /// - Parameters:
    ///   - x: Pixel X coordinate (0-based)
    ///   - y: Pixel Y coordinate (0-based)
    /// - Returns: Sky coordinates in degrees
    public func worldCoordinates(for x: Double, y: Double) -> (longitude: Double, latitude: Double) {
        // Simple linear transformation (TAN projection approximation)
        let deltaX = (x + 1 - referencePixel.x) * pixelScale.x  // FITS uses 1-based pixels
        let deltaY = (y + 1 - referencePixel.y) * pixelScale.y
        
        return (
            longitude: referenceValue.longitude + deltaX,
            latitude: referenceValue.latitude + deltaY
        )
    }
    
    /// Calculate pixel coordinates for given world coordinates
    /// - Parameters:
    ///   - longitude: World longitude in degrees
    ///   - latitude: World latitude in degrees  
    /// - Returns: Pixel coordinates (0-based)
    public func pixelCoordinates(for longitude: Double, latitude: Double) -> (x: Double, y: Double) {
        let deltaLon = longitude - referenceValue.longitude
        let deltaLat = latitude - referenceValue.latitude
        
        return (
            x: referencePixel.x - 1 + deltaLon / pixelScale.x,  // Convert to 0-based
            y: referencePixel.y - 1 + deltaLat / pixelScale.y
        )
    }
}