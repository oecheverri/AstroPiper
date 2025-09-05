import Foundation

/// Astronomical coordinate transformation mathematics for WCS (World Coordinate System)
/// 
/// Implements proper spherical trigonometry and projection algorithms according to:
/// - FITS WCS Paper II (Calabretta & Greisen, 2002)
/// - IAU recommendations for celestial coordinate systems
/// 
/// All angles are in degrees unless otherwise specified.
/// RA coordinates: 0° to 360°, Dec coordinates: -90° to +90°
public struct WCSMath {
    
    /// Mathematical constants for astronomical calculations
    private static let degreesToRadians = Double.pi / 180.0
    private static let radiansToDegrees = 180.0 / Double.pi
    
    // MARK: - Coordinate Validation & Normalization
    
    /// Normalize Right Ascension to [0, 360) degrees
    /// - Parameter ra: Right Ascension in degrees
    /// - Returns: Normalized RA in [0, 360) degrees
    public static func normalizeRA(_ ra: Double) -> Double {
        let normalized = ra.truncatingRemainder(dividingBy: 360.0)
        return normalized < 0 ? normalized + 360.0 : normalized
    }
    
    /// Validate and clamp Declination to [-90, +90] degrees
    /// - Parameter dec: Declination in degrees
    /// - Returns: Clamped declination in [-90, +90] degrees
    public static func validateDeclination(_ dec: Double) -> Double {
        return max(-90.0, min(90.0, dec))
    }
    
    /// Validate astronomical coordinates
    /// - Parameters:
    ///   - ra: Right Ascension in degrees
    ///   - dec: Declination in degrees
    /// - Returns: Tuple of (normalizedRA, validatedDec)
    public static func validateCoordinates(ra: Double, dec: Double) -> (ra: Double, dec: Double) {
        return (ra: normalizeRA(ra), dec: validateDeclination(dec))
    }
    
    // MARK: - Angular Distance Calculations
    
    /// Calculate angular separation between two points on celestial sphere
    /// Uses the haversine formula for numerical stability
    /// - Parameters:
    ///   - ra1: Right Ascension of first point (degrees)
    ///   - dec1: Declination of first point (degrees) 
    ///   - ra2: Right Ascension of second point (degrees)
    ///   - dec2: Declination of second point (degrees)
    /// - Returns: Angular separation in degrees
    public static func angularSeparation(
        ra1: Double, dec1: Double,
        ra2: Double, dec2: Double
    ) -> Double {
        let ra1Rad = ra1 * degreesToRadians
        let dec1Rad = dec1 * degreesToRadians
        let ra2Rad = ra2 * degreesToRadians
        let dec2Rad = dec2 * degreesToRadians
        
        let deltaRA = ra2Rad - ra1Rad
        let deltaDec = dec2Rad - dec1Rad
        
        // Haversine formula
        let a = sin(deltaDec / 2) * sin(deltaDec / 2) +
                cos(dec1Rad) * cos(dec2Rad) * sin(deltaRA / 2) * sin(deltaRA / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return c * radiansToDegrees
    }
    
    // MARK: - TAN Projection (Gnomonic)
    
    /// Forward TAN projection: spherical coordinates to tangent plane
    /// Projects celestial coordinates onto a plane tangent to the celestial sphere
    /// - Parameters:
    ///   - ra: Right Ascension (degrees)
    ///   - dec: Declination (degrees)
    ///   - ra0: Reference RA at tangent point (degrees)
    ///   - dec0: Reference Dec at tangent point (degrees)
    /// - Returns: Tangent plane coordinates (x, y) in same angular units
    /// - Throws: WCSMathError for points too far from tangent point
    public static func tanProjectionForward(
        ra: Double, dec: Double,
        ra0: Double, dec0: Double
    ) throws -> (x: Double, y: Double) {
        
        let raRad = ra * degreesToRadians
        let decRad = dec * degreesToRadians
        let ra0Rad = ra0 * degreesToRadians
        let dec0Rad = dec0 * degreesToRadians
        
        let deltaRA = raRad - ra0Rad
        
        // Calculate direction cosines
        let cosC = sin(dec0Rad) * sin(decRad) + cos(dec0Rad) * cos(decRad) * cos(deltaRA)
        
        // Check for points too close to the antipodal point
        if cosC <= 0 {
            throw WCSMathError.projectionSingularity("Point too far from tangent point for TAN projection")
        }
        
        // Tangent plane coordinates  
        let x = cos(decRad) * sin(deltaRA) / cosC
        let y = (sin(decRad) * cos(dec0Rad) - cos(decRad) * sin(dec0Rad) * cos(deltaRA)) / cosC
        
        return (x: x * radiansToDegrees, y: y * radiansToDegrees)
    }
    
    /// Inverse TAN projection: tangent plane to spherical coordinates
    /// Projects from tangent plane back to celestial sphere
    /// - Parameters:
    ///   - x: Tangent plane X coordinate (degrees)
    ///   - y: Tangent plane Y coordinate (degrees)
    ///   - ra0: Reference RA at tangent point (degrees)
    ///   - dec0: Reference Dec at tangent point (degrees)
    /// - Returns: Spherical coordinates (ra, dec) in degrees
    public static func tanProjectionInverse(
        x: Double, y: Double,
        ra0: Double, dec0: Double
    ) -> (ra: Double, dec: Double) {
        
        let xRad = x * degreesToRadians
        let yRad = y * degreesToRadians
        let ra0Rad = ra0 * degreesToRadians
        let dec0Rad = dec0 * degreesToRadians
        
        let rho = sqrt(xRad * xRad + yRad * yRad)
        let c = atan(rho)
        
        let sinC = sin(c)
        let cosC = cos(c)
        
        // Handle special case of origin
        if rho == 0 {
            return (ra: ra0, dec: dec0)
        }
        
        let dec = asin(cosC * sin(dec0Rad) + (yRad * sinC * cos(dec0Rad)) / rho)
        let ra = ra0Rad + atan2(xRad * sinC, rho * cos(dec0Rad) * cosC - yRad * sin(dec0Rad) * sinC)
        
        let coords = validateCoordinates(ra: ra * radiansToDegrees, dec: dec * radiansToDegrees)
        return coords
    }
    
    // MARK: - Field of View Calculations
    
    /// Calculate field of view from image dimensions and pixel scale
    /// - Parameters:
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - pixelScaleX: Pixel scale in X direction (degrees/pixel)
    ///   - pixelScaleY: Pixel scale in Y direction (degrees/pixel)  
    /// - Returns: Field of view (width, height, diagonal) in degrees
    public static func calculateFieldOfView(
        width: Double, height: Double,
        pixelScaleX: Double, pixelScaleY: Double
    ) -> (width: Double, height: Double, diagonal: Double) {
        
        let fovWidth = width * abs(pixelScaleX)
        let fovHeight = height * abs(pixelScaleY)
        let fovDiagonal = sqrt(fovWidth * fovWidth + fovHeight * fovHeight)
        
        return (width: fovWidth, height: fovHeight, diagonal: fovDiagonal)
    }
    
    /// Convert pixel scale from arcseconds per pixel to degrees per pixel
    /// - Parameter arcsecPerPixel: Pixel scale in arcseconds per pixel
    /// - Returns: Pixel scale in degrees per pixel
    public static func arcsecToDegreesPerPixel(_ arcsecPerPixel: Double) -> Double {
        return arcsecPerPixel / 3600.0
    }
    
    /// Convert pixel scale from degrees per pixel to arcseconds per pixel
    /// - Parameter degPerPixel: Pixel scale in degrees per pixel
    /// - Returns: Pixel scale in arcseconds per pixel
    public static func degreesToArcsecPerPixel(_ degPerPixel: Double) -> Double {
        return degPerPixel * 3600.0
    }
    
    /// Calculate effective pixel scale from focal length and pixel size
    /// - Parameters:
    ///   - focalLengthMM: Telescope focal length in millimeters
    ///   - pixelSizeMicrons: Pixel size in microns
    /// - Returns: Pixel scale in arcseconds per pixel
    public static func pixelScaleFromOptics(focalLengthMM: Double, pixelSizeMicrons: Double) -> Double {
        // Formula: pixel_scale = (pixel_size_microns / focal_length_mm) * 206265
        // 206265 = conversion from radians to arcseconds
        return (pixelSizeMicrons / 1000.0) / focalLengthMM * 206265.0
    }
    
    // MARK: - Matrix Operations for CD Matrix Support
    
    /// Represents a 2x2 transformation matrix for WCS
    public struct TransformMatrix: Equatable, Codable, Hashable, Sendable {
        public let cd11: Double  // CD1_1
        public let cd12: Double  // CD1_2  
        public let cd21: Double  // CD2_1
        public let cd22: Double  // CD2_2
        
        public init(cd11: Double, cd12: Double, cd21: Double, cd22: Double) {
            self.cd11 = cd11
            self.cd12 = cd12
            self.cd21 = cd21
            self.cd22 = cd22
        }
        
        /// Create matrix from CDELT and CROTA keywords
        /// - Parameters:
        ///   - cdelt1: X-axis pixel scale (degrees/pixel)
        ///   - cdelt2: Y-axis pixel scale (degrees/pixel)
        ///   - crota2: Rotation angle (degrees)
        /// - Returns: Equivalent CD matrix
        public static func fromCDELT(cdelt1: Double, cdelt2: Double, crota2: Double = 0.0) -> TransformMatrix {
            let rotRad = crota2 * degreesToRadians
            let cosRot = cos(rotRad)
            let sinRot = sin(rotRad)
            
            return TransformMatrix(
                cd11: cdelt1 * cosRot,
                cd12: -cdelt2 * sinRot,
                cd21: cdelt1 * sinRot,
                cd22: cdelt2 * cosRot
            )
        }
        
        /// Transform pixel coordinates using matrix
        /// - Parameters:
        ///   - deltaX: X offset in pixels
        ///   - deltaY: Y offset in pixels
        /// - Returns: Transformed coordinates in degrees
        public func transform(deltaX: Double, deltaY: Double) -> (x: Double, y: Double) {
            let x = cd11 * deltaX + cd12 * deltaY
            let y = cd21 * deltaX + cd22 * deltaY
            return (x: x, y: y)
        }
        
        /// Calculate determinant (for area scaling factor)
        public var determinant: Double {
            return cd11 * cd22 - cd12 * cd21
        }
        
        /// Calculate effective pixel scale (geometric mean)
        public var effectivePixelScale: Double {
            return sqrt(abs(determinant))
        }
    }
}

// MARK: - Error Types

public enum WCSMathError: Error, LocalizedError {
    case projectionSingularity(String)
    case invalidCoordinates(String)
    case unsupportedProjection(String)
    
    public var errorDescription: String? {
        switch self {
        case .projectionSingularity(let message):
            return "Projection singularity: \(message)"
        case .invalidCoordinates(let message):
            return "Invalid coordinates: \(message)"
        case .unsupportedProjection(let message):
            return "Unsupported projection: \(message)"
        }
    }
}