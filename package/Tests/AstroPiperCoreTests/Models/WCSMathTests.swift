import Testing
import Foundation
@testable import AstroPiperCore

/// Comprehensive tests for astronomical coordinate transformation mathematics
/// 
/// Tests cover:
/// - Spherical trigonometry calculations  
/// - TAN projection forward and inverse transformations
/// - CD matrix operations and CDELT/CROTA conversions
/// - Field of view calculations and coordinate validation
/// - Round-trip transformation accuracy
struct WCSMathTests {
    
    // MARK: - Coordinate Validation Tests
    
    @Test func normalizeRAHandlesPositiveValues() {
        #expect(WCSMath.normalizeRA(45.0) == 45.0)
        #expect(WCSMath.normalizeRA(180.0) == 180.0)
        #expect(WCSMath.normalizeRA(359.9) == 359.9)
    }
    
    @Test func normalizeRAHandlesNegativeValues() {
        #expect(WCSMath.normalizeRA(-45.0) == 315.0)
        #expect(WCSMath.normalizeRA(-180.0) == 180.0)
        #expect(WCSMath.normalizeRA(-0.1) == 359.9)
    }
    
    @Test func normalizeRAHandlesLargeValues() {
        #expect(WCSMath.normalizeRA(450.0) == 90.0)
        #expect(WCSMath.normalizeRA(720.0) == 0.0)
        #expect(abs(WCSMath.normalizeRA(725.5) - 5.5) < 1e-10)
    }
    
    @Test func validateDeclinationClampsValues() {
        #expect(WCSMath.validateDeclination(45.0) == 45.0)
        #expect(WCSMath.validateDeclination(90.0) == 90.0)
        #expect(WCSMath.validateDeclination(-90.0) == -90.0)
        #expect(WCSMath.validateDeclination(95.0) == 90.0)
        #expect(WCSMath.validateDeclination(-95.0) == -90.0)
    }
    
    @Test func validateCoordinatesHandlesBothAxes() {
        let coords = WCSMath.validateCoordinates(ra: -45.0, dec: 95.0)
        #expect(coords.ra == 315.0)
        #expect(coords.dec == 90.0)
    }
    
    // MARK: - Angular Distance Tests
    
    @Test func angularSeparationCalculatesIdenticalPoints() {
        let separation = WCSMath.angularSeparation(
            ra1: 180.0, dec1: 45.0,
            ra2: 180.0, dec2: 45.0
        )
        #expect(abs(separation) < 1e-10)
    }
    
    @Test func angularSeparationCalculates90DegreeOffset() {
        let separation = WCSMath.angularSeparation(
            ra1: 0.0, dec1: 0.0,
            ra2: 90.0, dec2: 0.0
        )
        #expect(abs(separation - 90.0) < 1e-6)
    }
    
    @Test func angularSeparationHandlesPolesToEquator() {
        let separation = WCSMath.angularSeparation(
            ra1: 0.0, dec1: 90.0,    // North pole
            ra2: 180.0, dec2: 0.0    // Equator
        )
        #expect(abs(separation - 90.0) < 1e-6)
    }
    
    @Test func angularSeparationHandlesRAWraparound() {
        let separation = WCSMath.angularSeparation(
            ra1: 359.0, dec1: 0.0,
            ra2: 1.0, dec2: 0.0
        )
        #expect(abs(separation - 2.0) < 1e-6)
    }
    
    // MARK: - TAN Projection Tests
    
    @Test func tanProjectionHandlesReferencePoint() throws {
        let ra0 = 180.0, dec0 = 45.0
        
        let result = try WCSMath.tanProjectionForward(
            ra: ra0, dec: dec0,
            ra0: ra0, dec0: dec0
        )
        
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y) < 1e-10)
    }
    
    @Test func tanProjectionRoundTripAccuracy() throws {
        let ra0 = 185.0, dec0 = 12.0
        let testRA = 184.9, testDec = 12.1
        
        // Forward projection
        let projected = try WCSMath.tanProjectionForward(
            ra: testRA, dec: testDec,
            ra0: ra0, dec0: dec0
        )
        
        // Inverse projection
        let backProjected = WCSMath.tanProjectionInverse(
            x: projected.x, y: projected.y,
            ra0: ra0, dec0: dec0
        )
        
        #expect(abs(backProjected.ra - testRA) < 1e-8)
        #expect(abs(backProjected.dec - testDec) < 1e-8)
    }
    
    @Test func tanProjectionFailsForAntipodal() {
        let ra0 = 0.0, dec0 = 0.0
        
        #expect(throws: WCSMathError.self) {
            _ = try WCSMath.tanProjectionForward(
                ra: 180.0, dec: 0.0,  // Antipodal point
                ra0: ra0, dec0: dec0
            )
        }
    }
    
    @Test func tanProjectionHandlesSmallOffsets() throws {
        let ra0 = 180.0, dec0 = 45.0
        
        let result = try WCSMath.tanProjectionForward(
            ra: 180.01, dec: 45.01,  // 0.01 degree offset
            ra0: ra0, dec0: dec0
        )
        
        // For small angles, TAN projection should be approximately linear
        let expectedX = 0.01 * cos(45.0 * Double.pi / 180.0) // RA scaled by cos(dec)
        #expect(abs(result.x - expectedX) < 2e-6) // Slightly relaxed tolerance for spherical trig
        #expect(abs(result.y - 0.01) < 1e-6)
    }
    
    // MARK: - Field of View Calculation Tests
    
    @Test func calculateFieldOfViewBasic() {
        let fov = WCSMath.calculateFieldOfView(
            width: 1000, height: 1000,
            pixelScaleX: 0.001, pixelScaleY: 0.001  // 3.6 arcsec/pixel
        )
        
        #expect(abs(fov.width - 1.0) < 1e-10)  // 1000 * 0.001 = 1 degree
        #expect(abs(fov.height - 1.0) < 1e-10)
        #expect(abs(fov.diagonal - sqrt(2.0)) < 1e-10)
    }
    
    @Test func calculateFieldOfViewAsymmetric() {
        let fov = WCSMath.calculateFieldOfView(
            width: 2048, height: 1536,
            pixelScaleX: -0.0001, pixelScaleY: 0.0001  // Negative X scale (normal for RA)
        )
        
        #expect(abs(fov.width - 0.2048) < 1e-10)
        #expect(abs(fov.height - 0.1536) < 1e-10)
        
        let expectedDiagonal = sqrt(0.2048 * 0.2048 + 0.1536 * 0.1536)
        #expect(abs(fov.diagonal - expectedDiagonal) < 1e-10)
    }
    
    // MARK: - Unit Conversion Tests
    
    @Test func arcsecToDegreesConversion() {
        #expect(abs(WCSMath.arcsecToDegreesPerPixel(3600.0) - 1.0) < 1e-10)
        #expect(abs(WCSMath.arcsecToDegreesPerPixel(1.0) - 1.0/3600.0) < 1e-15)
        #expect(abs(WCSMath.arcsecToDegreesPerPixel(0.5) - 0.5/3600.0) < 1e-15)
    }
    
    @Test func degreesToArcsecConversion() {
        #expect(abs(WCSMath.degreesToArcsecPerPixel(1.0) - 3600.0) < 1e-10)
        #expect(abs(WCSMath.degreesToArcsecPerPixel(1.0/3600.0) - 1.0) < 1e-10)
    }
    
    @Test func pixelScaleFromOptics() {
        // 1000mm f/5 telescope with 3.8 micron pixels
        let pixelScale = WCSMath.pixelScaleFromOptics(focalLengthMM: 1000.0, pixelSizeMicrons: 3.8)
        
        // Expected: 3.8/1000 * 206265 ≈ 0.784 arcsec/pixel
        #expect(abs(pixelScale - 0.784047) < 0.001)
    }
    
    @Test func pixelScaleFromOpticsTypicalValues() {
        // Common setups
        let shortFL = WCSMath.pixelScaleFromOptics(focalLengthMM: 400.0, pixelSizeMicrons: 3.76) // ZWO ASI533MC on short refractor
        let longFL = WCSMath.pixelScaleFromOptics(focalLengthMM: 2000.0, pixelSizeMicrons: 3.76) // Same camera on long refractor
        
        #expect(shortFL > longFL)  // Shorter focal length = larger pixels scale
        #expect(shortFL > 1.0 && shortFL < 3.0)  // Reasonable range
        #expect(longFL > 0.2 && longFL < 1.0)    // Reasonable range
    }
}

// MARK: - Transform Matrix Tests

struct TransformMatrixTests {
    
    @Test func transformMatrixBasicTransform() {
        let matrix = WCSMath.TransformMatrix(cd11: 0.001, cd12: 0.0, cd21: 0.0, cd22: 0.001)
        let result = matrix.transform(deltaX: 100.0, deltaY: 100.0)
        
        #expect(abs(result.x - 0.1) < 1e-10)
        #expect(abs(result.y - 0.1) < 1e-10)
    }
    
    @Test func transformMatrixWithRotation() {
        // 45-degree rotation matrix (approximately)
        let cos45 = 1.0 / sqrt(2.0)
        let matrix = WCSMath.TransformMatrix(
            cd11: cos45 * 0.001, cd12: -cos45 * 0.001,
            cd21: cos45 * 0.001, cd22: cos45 * 0.001
        )
        
        let result = matrix.transform(deltaX: 100.0, deltaY: 0.0)
        
        // Should rotate (100, 0) by 45 degrees
        #expect(abs(result.x - cos45 * 0.1) < 1e-10)
        #expect(abs(result.y - cos45 * 0.1) < 1e-10)
    }
    
    @Test func transformMatrixFromCDELT() {
        let matrix = WCSMath.TransformMatrix.fromCDELT(
            cdelt1: -0.001, cdelt2: 0.001, crota2: 0.0
        )
        
        #expect(matrix.cd11 == -0.001)
        #expect(matrix.cd12 == 0.0)
        #expect(matrix.cd21 == 0.0)  
        #expect(matrix.cd22 == 0.001)
    }
    
    @Test func transformMatrixFromCDELTWithRotation() {
        let matrix = WCSMath.TransformMatrix.fromCDELT(
            cdelt1: -0.001, cdelt2: 0.001, crota2: 90.0  // 90-degree rotation
        )
        
        // At 90 degrees: cos(90) = 0, sin(90) = 1
        #expect(abs(matrix.cd11) < 1e-10)        // -0.001 * 0
        #expect(abs(matrix.cd12 + 0.001) < 1e-10) // -0.001 * 1
        #expect(abs(matrix.cd21 + 0.001) < 1e-10) // -0.001 * 1
        #expect(abs(matrix.cd22) < 1e-10)        // 0.001 * 0
    }
    
    @Test func transformMatrixDeterminant() {
        let matrix = WCSMath.TransformMatrix(cd11: 0.001, cd12: 0.0, cd21: 0.0, cd22: -0.001)
        #expect(abs(matrix.determinant + 1e-6) < 1e-12) // 0.001 * -0.001 = -1e-6
    }
    
    @Test func transformMatrixEffectivePixelScale() {
        let matrix = WCSMath.TransformMatrix(cd11: 0.001, cd12: 0.0, cd21: 0.0, cd22: -0.001)
        #expect(abs(matrix.effectivePixelScale - 0.001) < 1e-10) // sqrt(|-1e-6|) = 0.001
    }
    
    @Test func transformMatrixWithSkew() {
        // Matrix with both scaling and skew
        let matrix = WCSMath.TransformMatrix(cd11: 0.001, cd12: 0.0005, cd21: 0.0002, cd22: 0.001)
        
        let det = matrix.determinant
        let expectedDet = 0.001 * 0.001 - 0.0005 * 0.0002
        #expect(abs(det - expectedDet) < 1e-12)
        
        let effectiveScale = matrix.effectivePixelScale
        #expect(effectiveScale > 0)
        #expect(effectiveScale < 0.002) // Should be reasonable
    }
}

// MARK: - Integration Tests

struct WCSMathIntegrationTests {
    
    @Test func realWorldCoordinateTransformations() throws {
        // M31 coordinates as example
        let ra0 = 10.68458  // 00h 42m 44.3s 
        let dec0 = 41.26917 // +41° 16' 09"
        
        // Test nearby coordinates
        let testRA = ra0 + 0.1  // ~6 arcmin offset
        let testDec = dec0 + 0.1
        
        let projected = try WCSMath.tanProjectionForward(
            ra: testRA, dec: testDec,
            ra0: ra0, dec0: dec0
        )
        
        let inverse = WCSMath.tanProjectionInverse(
            x: projected.x, y: projected.y,
            ra0: ra0, dec0: dec0
        )
        
        // Should recover original coordinates within numerical precision
        #expect(abs(inverse.ra - testRA) < 1e-8)
        #expect(abs(inverse.dec - testDec) < 1e-8)
    }
    
    @Test func typicalAstronomicalFieldOfView() {
        // Typical DSLR + 200mm lens setup
        let focalLength = 200.0 // mm
        let pixelSize = 5.2     // microns (Canon 5D mark IV)
        let sensorWidth = 8688.0  // pixels
        let sensorHeight = 5792.0 // pixels
        
        let pixelScaleArcsec = WCSMath.pixelScaleFromOptics(
            focalLengthMM: focalLength, 
            pixelSizeMicrons: pixelSize
        )
        let pixelScaleDeg = WCSMath.arcsecToDegreesPerPixel(pixelScaleArcsec)
        
        let fov = WCSMath.calculateFieldOfView(
            width: sensorWidth, height: sensorHeight,
            pixelScaleX: pixelScaleDeg, pixelScaleY: pixelScaleDeg
        )
        
        // Should give reasonable FOV for 200mm lens (roughly 12° x 8°)
        // Canon 5D Mark IV has large sensor, so FOV will be larger than expected
        #expect(fov.width > 10.0 && fov.width < 15.0)
        #expect(fov.height > 6.0 && fov.height < 10.0)
    }
    
    @Test func edgeCaseCoordinateValidation() {
        // Test coordinates at boundaries
        let testCases = [
            (ra: 359.99, dec: 89.99),   // Near north pole
            (ra: 0.01, dec: -89.99),    // Near south pole
            (ra: 180.0, dec: 0.0),      // Opposite RA from 0
            (ra: -0.01, dec: 0.0),      // Slight negative RA
            (ra: 360.01, dec: 0.0)      // Slight over 360 RA
        ]
        
        for testCase in testCases {
            let validated = WCSMath.validateCoordinates(ra: testCase.ra, dec: testCase.dec)
            
            #expect(validated.ra >= 0.0 && validated.ra < 360.0)
            #expect(validated.dec >= -90.0 && validated.dec <= 90.0)
        }
    }
}