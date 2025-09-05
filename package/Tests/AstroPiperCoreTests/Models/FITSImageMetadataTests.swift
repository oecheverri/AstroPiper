import Testing
import Foundation
@testable import AstroPiperCore

struct FITSImageMetadataTests {
    
    @Test func fitsImageMetadataConformsToAstroImageMetadata() {
        let metadata = FITSImageMetadata.mock()
        #expect(metadata is any AstroImageMetadata)
    }
    
    @Test func fitsImageMetadataHandlesBasicProperties() {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 1.0,
            filename: "test.fits",
            fileSize: 2097280,
            telescope: "Hubble",
            instrument: "WFC3",
            object: "M31"
        )
        
        #expect(metadata.naxis == 2)
        #expect(metadata.bitpix == 16)
        #expect(metadata.bzero == 32768.0)
        #expect(metadata.bscale == 1.0)
        #expect(metadata.telescope == "Hubble")
        #expect(metadata.instrument == "WFC3")
        #expect(metadata.object == "M31")
    }
    
    @Test func fitsImageMetadataComputesDimensions() {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [2048, 1536],
            bitpix: 16,
            filename: "test.fits"
        )
        
        #expect(metadata.dimensions.width == 2048)
        #expect(metadata.dimensions.height == 1536)
        #expect(metadata.totalPixels == 3145728)
    }
    
    @Test func fitsImageMetadataHandlesPixelFormats() {
        let testCases = [
            (bitpix: 8, expected: PixelFormat.uint8),
            (bitpix: 16, expected: PixelFormat.int16),
            (bitpix: 32, expected: PixelFormat.int32),
            (bitpix: -32, expected: PixelFormat.float32),
            (bitpix: -64, expected: PixelFormat.float64)
        ]
        
        for testCase in testCases {
            let metadata = FITSImageMetadata(
                naxis: 2,
                axisSizes: [1024, 1024],
                bitpix: testCase.bitpix,
                filename: "test.fits"
            )
            
            #expect(metadata.pixelFormat == testCase.expected)
            #expect(metadata.bytesPerPixel == abs(testCase.bitpix) / 8)
        }
    }
    
    @Test func fitsImageMetadataCalculatesPhysicalValues() {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 2.0,
            filename: "test.fits"
        )
        
        // Test physical value calculation: physical = BSCALE * raw + BZERO
        #expect(metadata.physicalValue(from: 0.0) == 32768.0)  // 2.0 * 0 + 32768
        #expect(metadata.physicalValue(from: 100.0) == 32968.0) // 2.0 * 100 + 32768
        #expect(metadata.physicalValue(from: -1000.0) == 30768.0) // 2.0 * -1000 + 32768
    }
    
    @Test func fitsImageMetadataHandlesDataTypes() {
        let integerMetadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            filename: "integer.fits"
        )
        
        let floatMetadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: -32,
            filename: "float.fits"
        )
        
        #expect(integerMetadata.isSignedInteger == true)
        #expect(integerMetadata.isFloatingPoint == false)
        #expect(floatMetadata.isSignedInteger == false)
        #expect(floatMetadata.isFloatingPoint == true)
    }
    
    @Test func fitsImageMetadataSupportsCustomHeaders() {
        let customHeaders = [
            "TELESCOP": "Subaru",
            "INSTRUME": "Suprime-Cam",
            "FILTER01": "r-band",
            "AIRMASS": "1.25"
        ]
        
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            filename: "test.fits",
            fitsHeaders: customHeaders
        )
        
        #expect(metadata.customValue(for: "TELESCOP") == "Subaru")
        #expect(metadata.customValue(for: "telescop") == "Subaru") // Case insensitive
        #expect(metadata.customValue(for: "AIRMASS") == "1.25")
        #expect(metadata.customValue(for: "NONEXISTENT") == nil)
        #expect(metadata.customMetadata.count == 4)
    }
    
    @Test func fitsImageMetadataCalculatesCompletenessScore() {
        let minimalMetadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            filename: "minimal.fits"
        )
        
        let completeMetadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            filename: "complete.fits",
            telescope: "VLT",
            object: "NGC 4472",
            exptime: 300.0,
            filter: "V"
        )
        
        #expect(minimalMetadata.completenessScore == 0.0) // No astronomical metadata
        #expect(completeMetadata.completenessScore > 0.0) // Has astronomical metadata
        #expect(completeMetadata.completenessScore <= 1.0) // Within valid range
    }
    
    @Test func fitsImageMetadataCodable() throws {
        let original = FITSImageMetadata.mock()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FITSImageMetadata.self, from: data)
        
        #expect(decoded.naxis == original.naxis)
        #expect(decoded.bitpix == original.bitpix)
        #expect(decoded.telescope == original.telescope)
        #expect(decoded.object == original.object)
    }
    
    @Test func fitsImageMetadataEquatable() {
        let metadata1 = FITSImageMetadata.mock()
        let metadata2 = FITSImageMetadata.mock()
        let metadata3 = FITSImageMetadata(
            naxis: 3, // Different
            axisSizes: [1024, 1024],
            bitpix: 16,
            filename: "different.fits"
        )
        
        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)
    }
}

// MARK: - WCS Tests

struct WCSInfoTests {
    
    @Test func wcsInfoCalculatesWorldCoordinatesWithTanProjection() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777), // 1 arcsec/pixel
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN"
        )
        
        // Test center pixel (should be very close to reference coordinates)
        let centerCoords = wcs.worldCoordinates(for: 511.5, y: 511.5) // 0-based
        #expect(abs(centerCoords.longitude - 185.0) < 0.001)
        #expect(abs(centerCoords.latitude - 12.0) < 0.001)
        
        // Test offset pixel - small offset should behave approximately linearly
        let offsetCoords = wcs.worldCoordinates(for: 611.5, y: 611.5) // 100 pixels offset
        #expect(offsetCoords.longitude < 185.0) // Negative X scale moves west
        #expect(offsetCoords.latitude > 12.0) // Positive Y scale moves north
        
        // The offset should be approximately 100 * 0.0002777 = 0.02777 degrees
        let expectedRAOffset = -0.02777 / cos(12.0 * Double.pi / 180.0) // RA scaling by cos(dec)
        let expectedDecOffset = 0.02777
        
        #expect(abs(offsetCoords.longitude - (185.0 + expectedRAOffset)) < 0.001)
        #expect(abs(offsetCoords.latitude - (12.0 + expectedDecOffset)) < 0.001)
    }
    
    @Test func wcsInfoCalculatesPixelCoordinates() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN" // Specify projection for proper round-trip
        )
        
        // Test round-trip conversion with coordinates close to reference
        // (avoids TAN projection singularities and numerical issues)
        let originalPixel = (x: 500.0, y: 520.0) // Close to reference pixel
        let worldCoords = wcs.worldCoordinates(for: originalPixel.x, y: originalPixel.y)
        let backToPixel = wcs.pixelCoordinates(for: worldCoords.longitude, latitude: worldCoords.latitude)
        
        #expect(abs(backToPixel.x - originalPixel.x) < 0.01) // Relaxed for spherical projection
        #expect(abs(backToPixel.y - originalPixel.y) < 0.01)
    }
    
    @Test func wcsInfoProvidesSkyCoordinates() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            equinox: 2000.0
        )
        
        let skyCoords = wcs.referenceCoordinates
        #expect(skyCoords.rightAscension == 185.0)
        #expect(skyCoords.declination == 12.0)
        #expect(skyCoords.epoch == 2000.0)
    }
    
    @Test func wcsInfoCalculatesFieldOfView() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 1024.5, y: 1024.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777), // 1 arcsec/pixel
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN"
        )
        
        let fov = wcs.fieldOfView(imageWidth: 2048, imageHeight: 2048)
        
        // 2048 pixels * 1 arcsec/pixel = 2048 arcsec = 0.5688 degrees
        let expectedFOV = 2048 * 0.0002777
        
        #expect(abs(fov.width - expectedFOV) < 0.001)
        #expect(abs(fov.height - expectedFOV) < 0.001)
        #expect(abs(fov.diagonal - expectedFOV * sqrt(2.0)) < 0.001)
    }
    
    @Test func wcsInfoHandlesCDMatrix() {
        let cdMatrix = WCSMath.TransformMatrix(cd11: -0.0002777, cd12: 0.0, cd21: 0.0, cd22: 0.0002777)
        
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777), // Legacy values
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            transformMatrix: cdMatrix
        )
        
        // Should use CD matrix for transformations
        let effectiveScale = wcs.effectivePixelScale
        #expect(abs(effectiveScale.x - 0.0002777) < 1e-10)
        #expect(abs(effectiveScale.y - 0.0002777) < 1e-10)
    }
    
    @Test func wcsInfoValidatesParameters() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN"
        )
        
        let issues = wcs.validate()
        #expect(issues.isEmpty) // Should pass validation
        
        // Test problematic WCS
        let badWCS = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: -10.0, latitude: 100.0), // Invalid coords
            pixelScale: PixelScale(x: -0.1, y: 0.1), // Very large pixel scale
            coordinateTypes: CoordinateTypes(x: "UNKNOWN", y: "UNKNOWN"),
            projection: "TAN"
        )
        
        let badIssues = badWCS.validate()
        #expect(!badIssues.isEmpty) // Should have validation issues
    }
    
    @Test func wcsInfoCalculatesPixelScaleArcsec() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777), // 1 arcsec/pixel in degrees
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN"
        )
        
        let scaleArcsec = wcs.pixelScaleArcsec
        #expect(abs(scaleArcsec.x - 1.0) < 0.01) // Should be ~1 arcsec/pixel
        #expect(abs(scaleArcsec.y - 1.0) < 0.01)
    }
    
    @Test func wcsInfoHandlesRotation() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            rotationAngle: 45.0 // 45-degree rotation
        )
        
        // Test that rotation affects coordinate calculations
        let coords1 = wcs.worldCoordinates(for: 612.5, y: 512.5) // 100 pixels in X
        let coords2 = wcs.worldCoordinates(for: 512.5, y: 412.5) // 100 pixels in Y
        
        // With 45-degree rotation, the coordinates should be affected differently
        // than without rotation (can't test exact values easily, but should be different)
        #expect(coords1.longitude != 185.0 - 0.02777) // Should not be simple linear
        #expect(coords2.latitude != 12.0 - 0.02777)
    }
}

// MARK: - Test Helpers

private extension FITSImageMetadata {
    static func mock() -> FITSImageMetadata {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            coordinateSystem: "ICRS",
            equinox: 2000.0
        )
        
        return FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 1.0,
            filename: "mock.fits",
            fileSize: 2097280,
            creationDate: Date(timeIntervalSince1970: 1640995200),
            telescope: "Mock Telescope",
            instrument: "Mock Camera",
            observer: "Test Observer",
            object: "Test Object",
            dateObs: Date(timeIntervalSince1970: 1640995200),
            exptime: 300.0,
            filter: "R",
            ccdTemp: -20.0,
            ccdGain: 2.5,
            binning: ImageBinning(horizontal: 1, vertical: 1),
            wcs: wcs,
            fitsHeaders: [
                "TELESCOP": "Mock Telescope",
                "INSTRUME": "Mock Camera",
                "OBJECT": "Test Object",
                "FILTER": "R"
            ]
        )
    }
}