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
/// 
/// Enhanced WCS implementation supporting proper astronomical coordinate transformations:
/// - TAN (Gnomonic) projection with spherical trigonometry
/// - CD matrix transformations for full affine mapping  
/// - CDELT/CROTA legacy support for backward compatibility
/// - Field of view calculations and coordinate validation
/// 
/// All coordinates are in degrees (RA: 0-360°, Dec: ±90°)
public struct WCSInfo: Sendable, Codable, Equatable, Hashable {
    
    /// Reference pixel coordinates (CRPIX1, CRPIX2) - FITS uses 1-based indexing
    public let referencePixel: PixelCoordinate
    
    /// Reference world coordinates (CRVAL1, CRVAL2) in degrees
    public let referenceValue: WorldCoordinate
    
    /// Pixel scale (CDELT1, CDELT2) in degrees per pixel - legacy support
    public let pixelScale: PixelScale
    
    /// CD transformation matrix for full affine transformations
    public let transformMatrix: WCSMath.TransformMatrix?
    
    /// Coordinate system types (CTYPE1, CTYPE2)
    public let coordinateTypes: CoordinateTypes
    
    /// Projection type (e.g., "TAN", "SIN", "ARC")  
    public let projection: String?
    
    /// Coordinate system name (e.g., "ICRS", "FK5")
    public let coordinateSystem: String?
    
    /// Equinox year (EQUINOX keyword)
    public let equinox: Double?
    
    /// Rotation angle in degrees (CROTA2) - for CDELT-based WCS
    public let rotationAngle: Double?
    
    public init(
        referencePixel: PixelCoordinate,
        referenceValue: WorldCoordinate,
        pixelScale: PixelScale,
        coordinateTypes: CoordinateTypes,
        projection: String? = nil,
        coordinateSystem: String? = nil,
        equinox: Double? = nil,
        transformMatrix: WCSMath.TransformMatrix? = nil,
        rotationAngle: Double? = nil
    ) {
        self.referencePixel = referencePixel
        self.referenceValue = referenceValue
        self.pixelScale = pixelScale
        self.transformMatrix = transformMatrix
        self.coordinateTypes = coordinateTypes
        self.projection = projection
        self.coordinateSystem = coordinateSystem
        self.equinox = equinox
        self.rotationAngle = rotationAngle
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
    
    /// Calculate world coordinates for a given pixel position using proper astronomical projections
    /// - Parameters:
    ///   - x: Pixel X coordinate (0-based)
    ///   - y: Pixel Y coordinate (0-based)
    /// - Returns: Sky coordinates in degrees with proper coordinate validation
    public func worldCoordinates(for x: Double, y: Double) -> (longitude: Double, latitude: Double) {
        
        // Calculate pixel offset from reference (convert 0-based to 1-based FITS convention)
        let deltaX = x + 1.0 - referencePixel.x
        let deltaY = y + 1.0 - referencePixel.y
        
        // Transform pixel offsets to intermediate world coordinates
        let (intermediateX, intermediateY) = applyPixelTransform(deltaX: deltaX, deltaY: deltaY)
        
        // Apply coordinate projection
        let coords = applyProjection(x: intermediateX, y: intermediateY, inverse: false)
        
        // Validate and normalize the resulting coordinates
        let validated = WCSMath.validateCoordinates(ra: coords.longitude, dec: coords.latitude)
        return (longitude: validated.ra, latitude: validated.dec)
    }
    
    /// Calculate pixel coordinates for given world coordinates with proper projection
    /// - Parameters:
    ///   - longitude: World longitude in degrees (RA)
    ///   - latitude: World latitude in degrees (Dec)
    /// - Returns: Pixel coordinates (0-based)
    public func pixelCoordinates(for longitude: Double, latitude: Double) -> (x: Double, y: Double) {
        
        // Validate input coordinates
        let validatedCoords = WCSMath.validateCoordinates(ra: longitude, dec: latitude)
        
        // Apply inverse projection to get intermediate coordinates
        let intermediateCoords = applyProjection(
            x: validatedCoords.ra, 
            y: validatedCoords.dec, 
            inverse: true
        )
        
        // Apply inverse pixel transformation
        let (deltaX, deltaY) = applyInversePixelTransform(
            x: intermediateCoords.longitude, 
            y: intermediateCoords.latitude
        )
        
        // Convert from FITS 1-based to 0-based pixel coordinates
        return (
            x: referencePixel.x + deltaX - 1.0,
            y: referencePixel.y + deltaY - 1.0
        )
    }
    
    // MARK: - Field of View and Scale Calculations
    
    /// Calculate the field of view covered by the image
    /// - Parameters:
    ///   - imageWidth: Image width in pixels
    ///   - imageHeight: Image height in pixels
    /// - Returns: Field of view dimensions in degrees (width, height, diagonal)
    public func fieldOfView(imageWidth: Double, imageHeight: Double) -> (width: Double, height: Double, diagonal: Double) {
        let effectiveScale = self.effectivePixelScale
        return WCSMath.calculateFieldOfView(
            width: imageWidth, 
            height: imageHeight,
            pixelScaleX: effectiveScale.x, 
            pixelScaleY: effectiveScale.y
        )
    }
    
    /// Get the effective pixel scale, accounting for CD matrix or CDELT values
    public var effectivePixelScale: PixelScale {
        if let matrix = transformMatrix {
            let scale = matrix.effectivePixelScale
            return PixelScale(x: scale, y: scale)
        } else {
            return pixelScale
        }
    }
    
    /// Calculate pixel scale in arcseconds per pixel
    public var pixelScaleArcsec: (x: Double, y: Double) {
        let scale = effectivePixelScale
        return (
            x: WCSMath.degreesToArcsecPerPixel(abs(scale.x)),
            y: WCSMath.degreesToArcsecPerPixel(abs(scale.y))
        )
    }
    
    /// Validate WCS parameters for astronomical reasonableness
    /// - Returns: Array of validation warnings/errors
    public func validate() -> [String] {
        var issues: [String] = []
        
        // Check coordinate types
        if !coordinateTypes.x.contains("RA") && !coordinateTypes.x.contains("GLON") {
            issues.append("Unexpected longitude coordinate type: \(coordinateTypes.x)")
        }
        if !coordinateTypes.y.contains("DEC") && !coordinateTypes.y.contains("GLAT") {
            issues.append("Unexpected latitude coordinate type: \(coordinateTypes.y)")
        }
        
        // Check pixel scale reasonableness (typical range: 0.1 arcsec to 10 arcmin per pixel)
        let scaleArcsec = pixelScaleArcsec
        if scaleArcsec.x < 0.1 || scaleArcsec.x > 600 {
            issues.append("Unusual pixel scale X: \(String(format: "%.3f", scaleArcsec.x)) arcsec/pixel")
        }
        if scaleArcsec.y < 0.1 || scaleArcsec.y > 600 {
            issues.append("Unusual pixel scale Y: \(String(format: "%.3f", scaleArcsec.y)) arcsec/pixel")
        }
        
        // Check coordinate ranges
        if referenceValue.longitude < 0 || referenceValue.longitude >= 360 {
            issues.append("RA reference value outside valid range [0,360): \(referenceValue.longitude)")
        }
        if referenceValue.latitude < -90 || referenceValue.latitude > 90 {
            issues.append("Dec reference value outside valid range [-90,90]: \(referenceValue.latitude)")
        }
        
        return issues
    }
    
    // MARK: - Private Transformation Methods
    
    /// Apply pixel-to-world transformation (CD matrix or CDELT/CROTA)
    private func applyPixelTransform(deltaX: Double, deltaY: Double) -> (x: Double, y: Double) {
        if let matrix = transformMatrix {
            return matrix.transform(deltaX: deltaX, deltaY: deltaY)
        } else {
            // Use CDELT with optional rotation
            if let rotation = rotationAngle {
                let matrix = WCSMath.TransformMatrix.fromCDELT(
                    cdelt1: pixelScale.x, 
                    cdelt2: pixelScale.y, 
                    crota2: rotation
                )
                return matrix.transform(deltaX: deltaX, deltaY: deltaY)
            } else {
                // Simple linear scaling
                return (x: deltaX * pixelScale.x, y: deltaY * pixelScale.y)
            }
        }
    }
    
    /// Apply inverse pixel transformation
    private func applyInversePixelTransform(x: Double, y: Double) -> (deltaX: Double, deltaY: Double) {
        if let matrix = transformMatrix {
            // Solve the linear system: [x y] = [deltaX deltaY] * CD_matrix
            let det = matrix.determinant
            guard abs(det) > 1e-15 else {
                // Singular matrix fallback
                return (deltaX: x / pixelScale.x, deltaY: y / pixelScale.y)
            }
            
            // Inverse matrix calculation
            let deltaX = (matrix.cd22 * x - matrix.cd12 * y) / det
            let deltaY = (-matrix.cd21 * x + matrix.cd11 * y) / det
            return (deltaX: deltaX, deltaY: deltaY)
        } else {
            // Use simple inverse scaling with optional rotation
            if let rotation = rotationAngle {
                let matrix = WCSMath.TransformMatrix.fromCDELT(
                    cdelt1: pixelScale.x,
                    cdelt2: pixelScale.y, 
                    crota2: rotation
                )
                let det = matrix.determinant
                let deltaX = (matrix.cd22 * x - matrix.cd12 * y) / det
                let deltaY = (-matrix.cd21 * x + matrix.cd11 * y) / det
                return (deltaX: deltaX, deltaY: deltaY)
            } else {
                return (deltaX: x / pixelScale.x, deltaY: y / pixelScale.y)
            }
        }
    }
    
    /// Apply coordinate projection (forward or inverse)
    private func applyProjection(x: Double, y: Double, inverse: Bool) -> (longitude: Double, latitude: Double) {
        guard let projType = projection?.uppercased() else {
            // No projection specified - assume linear (for backward compatibility)
            if inverse {
                return (longitude: x, latitude: y)
            } else {
                return (longitude: referenceValue.longitude + x, latitude: referenceValue.latitude + y)
            }
        }
        
        switch projType {
        case "TAN":
            return applyTanProjection(x: x, y: y, inverse: inverse)
        default:
            // Unsupported projection - fall back to linear with warning
            if inverse {
                return (longitude: x, latitude: y)
            } else {
                return (longitude: referenceValue.longitude + x, latitude: referenceValue.latitude + y)
            }
        }
    }
    
    /// Apply TAN (Gnomonic) projection using proper spherical trigonometry
    private func applyTanProjection(x: Double, y: Double, inverse: Bool) -> (longitude: Double, latitude: Double) {
        
        if inverse {
            // World coordinates to intermediate coordinates
            do {
                let result = try WCSMath.tanProjectionForward(
                    ra: x, dec: y,
                    ra0: referenceValue.longitude, dec0: referenceValue.latitude
                )
                return (longitude: result.x, latitude: result.y)
            } catch {
                // Fallback for problematic coordinates
                return (longitude: x - referenceValue.longitude, latitude: y - referenceValue.latitude)
            }
        } else {
            // Intermediate coordinates to world coordinates  
            let result = WCSMath.tanProjectionInverse(
                x: x, y: y,
                ra0: referenceValue.longitude, dec0: referenceValue.latitude
            )
            return (longitude: result.ra, latitude: result.dec)
        }
    }
}