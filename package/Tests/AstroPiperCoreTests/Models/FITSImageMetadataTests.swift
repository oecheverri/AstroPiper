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
    
    @Test func wcsInfoCalculatesWorldCoordinates() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777), // 1 arcsec/pixel
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN"
        )
        
        // Test center pixel
        let centerCoords = wcs.worldCoordinates(for: 511.5, y: 511.5) // 0-based
        #expect(abs(centerCoords.longitude - 185.0) < 0.001)
        #expect(abs(centerCoords.latitude - 12.0) < 0.001)
        
        // Test offset pixel
        let offsetCoords = wcs.worldCoordinates(for: 611.5, y: 611.5) // 100 pixels offset
        #expect(offsetCoords.longitude < 185.0) // Negative X scale moves west
        #expect(offsetCoords.latitude > 12.0) // Positive Y scale moves north
    }
    
    @Test func wcsInfoCalculatesPixelCoordinates() {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 512.5, y: 512.5),
            referenceValue: WorldCoordinate(longitude: 185.0, latitude: 12.0),
            pixelScale: PixelScale(x: -0.0002777, y: 0.0002777),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN")
        )
        
        // Test round-trip conversion
        let originalPixel = (x: 100.0, y: 200.0)
        let worldCoords = wcs.worldCoordinates(for: originalPixel.x, y: originalPixel.y)
        let backToPixel = wcs.pixelCoordinates(for: worldCoords.longitude, latitude: worldCoords.latitude)
        
        #expect(abs(backToPixel.x - originalPixel.x) < 0.001)
        #expect(abs(backToPixel.y - originalPixel.y) < 0.001)
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