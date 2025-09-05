import Foundation

/// Demonstration of enhanced WCS (World Coordinate System) capabilities
/// 
/// Shows practical examples of astronomical coordinate transformations
/// using proper spherical trigonometry and mathematical projections.
public struct WCSDemo {
    
    /// Example 1: Create WCS from typical telescope/camera setup
    public static func createTypicalWCS() -> WCSInfo {
        // Example: 1000mm f/5 telescope with ASI533MC camera on M31
        let m31_ra = 10.68458   // 00h 42m 44.3s
        let m31_dec = 41.26917  // +41° 16' 09"
        
        // Calculate pixel scale from optical setup
        let focalLength = 1000.0  // mm
        let pixelSize = 3.76      // microns (ASI533MC)
        let pixelScaleArcsec = WCSMath.pixelScaleFromOptics(
            focalLengthMM: focalLength, 
            pixelSizeMicrons: pixelSize
        )
        let pixelScaleDeg = WCSMath.arcsecToDegreesPerPixel(pixelScaleArcsec)
        
        print("📸 Telescope Setup:")
        print("   Focal Length: \(focalLength)mm")
        print("   Pixel Size: \(pixelSize)μm")
        print("   Pixel Scale: \(String(format: "%.2f", pixelScaleArcsec))\" per pixel")
        
        return WCSInfo(
            referencePixel: PixelCoordinate(x: 1608.0, y: 1104.0), // Center of ASI533MC
            referenceValue: WorldCoordinate(longitude: m31_ra, latitude: m31_dec),
            pixelScale: PixelScale(x: -pixelScaleDeg, y: pixelScaleDeg), // RA increases leftward
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            coordinateSystem: "ICRS",
            equinox: 2000.0
        )
    }
    
    /// Example 2: Field of view calculations
    public static func demonstrateFieldOfView() {
        let wcs = createTypicalWCS()
        
        // ASI533MC sensor: 3216 x 2208 pixels
        let sensorWidth = 3216.0
        let sensorHeight = 2208.0
        
        let fov = wcs.fieldOfView(imageWidth: sensorWidth, imageHeight: sensorHeight)
        
        print("\n🌌 Field of View Analysis:")
        print("   Image Size: \(Int(sensorWidth)) × \(Int(sensorHeight)) pixels")
        print("   FOV Width: \(String(format: "%.2f", fov.width))° (\(String(format: "%.1f", fov.width * 60))′)")
        print("   FOV Height: \(String(format: "%.2f", fov.height))° (\(String(format: "%.1f", fov.height * 60))′)")
        print("   FOV Diagonal: \(String(format: "%.2f", fov.diagonal))° (\(String(format: "%.1f", fov.diagonal * 60))′)")
        
        // Validate against known M31 size (about 3° × 1°)
        if fov.width > 3.0 && fov.height > 1.0 {
            print("   ✅ Suitable for M31 imaging (M31 is ~3° × 1°)")
        } else {
            print("   ℹ️  FOV smaller than M31 - good for detailed imaging")
        }
    }
    
    /// Example 3: Coordinate transformations with proper TAN projection
    public static func demonstrateCoordinateTransformations() {
        let wcs = createTypicalWCS()
        
        print("\n📍 Coordinate Transformations:")
        
        // Test coordinates around M31
        let testPoints = [
            ("M31 Core", 10.68458, 41.26917),         // Center
            ("NGC 205", 10.09542, 41.68556),          // Companion galaxy
            ("NGC 221", 10.67458, 40.86194),          // Another companion
            ("Star Field", 10.5, 41.5)               // Nearby star field
        ]
        
        for (name, ra, dec) in testPoints {
            // Convert world coordinates to pixel coordinates
            let pixelCoords = wcs.pixelCoordinates(for: ra, latitude: dec)
            
            // Convert back to verify accuracy
            let backCoords = wcs.worldCoordinates(for: pixelCoords.x, y: pixelCoords.y)
            
            // Calculate angular separation from center
            let separation = WCSMath.angularSeparation(
                ra1: 10.68458, dec1: 41.26917,
                ra2: ra, dec2: dec
            )
            
            print("   \(name):")
            print("     RA/Dec: \(String(format: "%.5f", ra))°, \(String(format: "%.5f", dec))°")
            print("     Pixel: (\(String(format: "%.1f", pixelCoords.x)), \(String(format: "%.1f", pixelCoords.y)))")
            print("     Round-trip error: \(String(format: "%.6f", abs(backCoords.longitude - ra)))° RA, \(String(format: "%.6f", abs(backCoords.latitude - dec)))° Dec")
            print("     Angular separation: \(String(format: "%.3f", separation))° (\(String(format: "%.1f", separation * 60))′)")
        }
    }
    
    /// Example 4: CD Matrix transformation with rotation
    public static func demonstrateCDMatrixWithRotation() {
        // Create a WCS with 30-degree field rotation
        let rotationDegrees = 30.0
        let pixelScale = WCSMath.arcsecToDegreesPerPixel(0.77) // 0.77" per pixel
        
        let cdMatrix = WCSMath.TransformMatrix.fromCDELT(
            cdelt1: -pixelScale,
            cdelt2: pixelScale, 
            crota2: rotationDegrees
        )
        
        let rotatedWCS = WCSInfo(
            referencePixel: PixelCoordinate(x: 1608.0, y: 1104.0),
            referenceValue: WorldCoordinate(longitude: 10.68458, latitude: 41.26917),
            pixelScale: PixelScale(x: -pixelScale, y: pixelScale),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            transformMatrix: cdMatrix,
            rotationAngle: rotationDegrees
        )
        
        print("\n🔄 Field Rotation Demonstration:")
        print("   Rotation: \(rotationDegrees)°")
        print("   CD Matrix: [\(String(format: "%.6f", cdMatrix.cd11)), \(String(format: "%.6f", cdMatrix.cd12))]")
        print("             [\(String(format: "%.6f", cdMatrix.cd21)), \(String(format: "%.6f", cdMatrix.cd22))]")
        print("   Determinant: \(String(format: "%.8f", cdMatrix.determinant))")
        print("   Effective Scale: \(String(format: "%.2f", WCSMath.degreesToArcsecPerPixel(cdMatrix.effectivePixelScale)))\" per pixel")
        
        // Show how rotation affects coordinate mapping
        let testPixel = (x: 1708.0, y: 1104.0) // 100 pixels to the right
        let coordsNormal = createTypicalWCS().worldCoordinates(for: testPixel.x, y: testPixel.y)
        let coordsRotated = rotatedWCS.worldCoordinates(for: testPixel.x, y: testPixel.y)
        
        print("   Test Point (100px right of center):")
        print("     No rotation: RA \(String(format: "%.5f", coordsNormal.longitude))°, Dec \(String(format: "%.5f", coordsNormal.latitude))°")
        print("     With rotation: RA \(String(format: "%.5f", coordsRotated.longitude))°, Dec \(String(format: "%.5f", coordsRotated.latitude))°")
    }
    
    /// Example 5: WCS validation and error checking
    public static func demonstrateValidation() {
        print("\n✅ WCS Validation:")
        
        // Good WCS
        let goodWCS = createTypicalWCS()
        let goodIssues = goodWCS.validate()
        print("   Good WCS: \(goodIssues.isEmpty ? "✓ No issues" : "⚠️ \(goodIssues.count) issues")")
        
        // Problematic WCS with various issues
        let badWCS = WCSInfo(
            referencePixel: PixelCoordinate(x: 1000, y: 1000),
            referenceValue: WorldCoordinate(longitude: -50.0, latitude: 100.0), // Invalid coordinates
            pixelScale: PixelScale(x: -0.01, y: 0.01), // Very large pixel scale
            coordinateTypes: CoordinateTypes(x: "UNKNOWN", y: "UNKNOWN"), // Unknown coordinate types
            projection: "TAN"
        )
        
        let badIssues = badWCS.validate()
        print("   Problematic WCS: \(badIssues.count) issues found")
        for (index, issue) in badIssues.enumerated() {
            print("     \(index + 1). \(issue)")
        }
    }
    
    /// Run complete WCS demonstration
    public static func runCompleteDemo() {
        print("🌟 Enhanced WCS (World Coordinate System) Demonstration")
        print("=" * 60)
        
        demonstrateFieldOfView()
        demonstrateCoordinateTransformations()
        demonstrateCDMatrixWithRotation()
        demonstrateValidation()
        
        print("\n" + "=" * 60)
        print("✨ Demo complete! WCS implementation provides:")
        print("   • Proper TAN projection with spherical trigonometry")
        print("   • CD matrix support for complex transformations")
        print("   • Field of view calculations from optical parameters")
        print("   • Coordinate validation and error checking")
        print("   • Round-trip accuracy for astrometric precision")
        print("   • Support for field rotation and distortion modeling")
    }
}

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}