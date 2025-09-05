import XCTest
@testable import AstroPiperCore
import Foundation

/// Tests for AstroImageMetadata protocol behavior
/// Focuses on: universal metadata access, optional astronomical fields,
/// type safety across formats, serialization, and extensibility
final class AstroImageMetadataTests: XCTestCase {
    
    // MARK: - Mock implementation for testing
    
    private struct MockAstroImageMetadata: AstroImageMetadata {
        let dimensions: ImageDimensions
        let pixelFormat: PixelFormat
        let colorSpace: ColorSpace
        let filename: String?
        let fileSize: UInt64?
        let creationDate: Date?
        let modificationDate: Date?
        
        // Astronomical-specific metadata
        let exposureTime: TimeInterval?
        let iso: Int?
        let telescopeName: String?
        let instrumentName: String?
        let filterName: String?
        let objectName: String?
        let observationDate: Date?
        let coordinates: SkyCoordinates?
        let temperature: Double?
        let gain: Double?
        let binning: ImageBinning?
        let customMetadata: [String: String]
        
        init(
            width: UInt32 = 1920, height: UInt32 = 1080,
            pixelFormat: PixelFormat = .uint16,
            colorSpace: ColorSpace = .linear,
            filename: String? = nil,
            customMetadata: [String: String] = [:]
        ) {
            self.dimensions = ImageDimensions(width: width, height: height)
            self.pixelFormat = pixelFormat
            self.colorSpace = colorSpace
            self.filename = filename
            self.fileSize = nil
            self.creationDate = Date()
            self.modificationDate = Date()
            
            self.exposureTime = nil
            self.iso = nil
            self.telescopeName = nil
            self.instrumentName = nil
            self.filterName = nil
            self.objectName = nil
            self.observationDate = nil
            self.coordinates = nil
            self.temperature = nil
            self.gain = nil
            self.binning = nil
            self.customMetadata = customMetadata
        }
    }
    
    // MARK: - Behavior: Metadata should provide universal access to image properties
    
    func test_astroImageMetadata_shouldProvideBasicImageProperties() throws {
        // Given: Basic image metadata
        let metadata = MockAstroImageMetadata(width: 4096, height: 4096, pixelFormat: .uint16)
        
        // Then: Should provide fundamental image information
        XCTAssertEqual(metadata.dimensions.width, 4096, "Width should be accessible")
        XCTAssertEqual(metadata.dimensions.height, 4096, "Height should be accessible")
        XCTAssertEqual(metadata.pixelFormat, .uint16, "Pixel format should be accessible")
        XCTAssertEqual(metadata.colorSpace, .linear, "Color space should be accessible")
        XCTAssertNotNil(metadata.creationDate, "Creation date should be accessible")
    }
    
    func test_astroImageMetadata_shouldCalculateDerivedProperties() throws {
        // Given: Metadata with known dimensions
        let metadata = MockAstroImageMetadata(width: 1920, height: 1080)
        
        // Then: Should provide calculated properties
        let totalPixels = metadata.totalPixels
        XCTAssertEqual(totalPixels, 1920 * 1080, "Total pixels should be calculated correctly")
        
        let aspectRatio = metadata.aspectRatio
        XCTAssertEqual(aspectRatio, 1920.0 / 1080.0, accuracy: 0.01, "Aspect ratio should be calculated")
        
        let megapixels = metadata.megapixels
        XCTAssertEqual(megapixels, Double(totalPixels) / 1_000_000.0, accuracy: 0.01, "Megapixels should be calculated")
    }
    
    // MARK: - Behavior: Metadata should support optional astronomical-specific fields
    
    func test_astroImageMetadata_shouldSupportExposureInformation() throws {
        // Given: Metadata with exposure information
        var metadata = MockAstroImageMetadata()
        metadata = MockAstroImageMetadata(
            width: 1920, height: 1080,
            customMetadata: [:]
        )
        
        // When: Accessing exposure-related fields
        let exposureTime = metadata.exposureTime
        let iso = metadata.iso
        let gain = metadata.gain
        
        // Then: Should support optional exposure fields
        // These might be nil for this mock, but the protocol should support them
        XCTAssertTrue(exposureTime == nil || exposureTime! > 0, "Exposure time should be positive if present")
        XCTAssertTrue(iso == nil || iso! > 0, "ISO should be positive if present")
        XCTAssertTrue(gain == nil || gain! >= 0, "Gain should be non-negative if present")
    }
    
    func test_astroImageMetadata_shouldSupportTelescopeInformation() throws {
        // Given: Metadata that might contain telescope info
        let metadata = MockAstroImageMetadata()
        
        // When: Accessing telescope-related fields
        let telescopeName = metadata.telescopeName
        let instrumentName = metadata.instrumentName
        let filterName = metadata.filterName
        let temperature = metadata.temperature
        
        // Then: Should support optional telescope fields
        XCTAssertTrue(telescopeName?.isEmpty == false || telescopeName == nil, "Telescope name should be meaningful if present")
        XCTAssertTrue(instrumentName?.isEmpty == false || instrumentName == nil, "Instrument name should be meaningful if present")
        XCTAssertTrue(filterName?.isEmpty == false || filterName == nil, "Filter name should be meaningful if present")
        XCTAssertTrue(temperature == nil || temperature! > -300, "Temperature should be reasonable if present")
    }
    
    func test_astroImageMetadata_shouldSupportAstronomicalCoordinates() throws {
        // Given: Metadata with potential coordinate information
        let metadata = MockAstroImageMetadata()
        
        // When: Accessing coordinate fields
        let coordinates = metadata.coordinates
        let objectName = metadata.objectName
        let observationDate = metadata.observationDate
        
        // Then: Should support astronomical positioning
        if let coords = coordinates {
            XCTAssertGreaterThanOrEqual(coords.rightAscension, 0, "RA should be non-negative")
            XCTAssertLessThan(coords.rightAscension, 360, "RA should be less than 360 degrees")
            XCTAssertGreaterThanOrEqual(coords.declination, -90, "Dec should be >= -90 degrees")
            XCTAssertLessThanOrEqual(coords.declination, 90, "Dec should be <= 90 degrees")
        }
        
        XCTAssertTrue(objectName?.isEmpty == false || objectName == nil, "Object name should be meaningful if present")
        XCTAssertTrue(observationDate == nil || observationDate! <= Date(), "Observation date should not be in future")
    }
    
    // MARK: - Behavior: Metadata should maintain type safety across formats
    
    func test_astroImageMetadata_shouldEnforceTypeConstraints() throws {
        // Given: Metadata with typed fields
        let metadata = MockAstroImageMetadata(width: 100, height: 200, pixelFormat: .float32)
        
        // Then: Types should be enforced
        XCTAssertTrue(metadata.dimensions.width is UInt32, "Width should be UInt32")
        XCTAssertTrue(metadata.dimensions.height is UInt32, "Height should be UInt32")
        XCTAssertTrue(metadata.pixelFormat is PixelFormat, "PixelFormat should be strongly typed")
        XCTAssertTrue(metadata.colorSpace is ColorSpace, "ColorSpace should be strongly typed")
        
        // Astronomical fields should have appropriate types
        if let exposure = metadata.exposureTime {
            XCTAssertTrue(exposure is TimeInterval, "Exposure should be TimeInterval")
        }
        if let coords = metadata.coordinates {
            XCTAssertTrue(coords is SkyCoordinates, "Coordinates should be SkyCoordinates type")
        }
    }
    
    func test_astroImageMetadata_shouldValidateImageDimensions() throws {
        // Given: Various dimension scenarios
        let validMetadata = MockAstroImageMetadata(width: 1920, height: 1080)
        
        // Then: Should ensure valid dimensions
        XCTAssertGreaterThan(validMetadata.dimensions.width, 0, "Width should be positive")
        XCTAssertGreaterThan(validMetadata.dimensions.height, 0, "Height should be positive")
        
        // Aspect ratio should be reasonable
        let aspectRatio = validMetadata.aspectRatio
        XCTAssertGreaterThan(aspectRatio, 0, "Aspect ratio should be positive")
        XCTAssertLessThan(aspectRatio, 100, "Aspect ratio should be reasonable")
    }
    
    // MARK: - Behavior: Metadata should support custom metadata extension
    
    func test_astroImageMetadata_shouldSupportCustomMetadata() throws {
        // Given: Metadata with custom fields
        let customData: [String: String] = [
            "FITS_COMMENT": "Test image",
            "BSCALE": "1.0",
            "BZERO": "32768.0",
            "HISTORY": "Created with AstroPiper; Processed on 2024-01-01"
        ]
        let metadata = MockAstroImageMetadata(customMetadata: customData)
        
        // When: Accessing custom metadata
        let customMetadata = metadata.customMetadata
        
        // Then: Should preserve custom data
        XCTAssertFalse(customMetadata.isEmpty, "Custom metadata should be preserved")
        XCTAssertEqual(customMetadata["FITS_COMMENT"], "Test image", "Custom string should be preserved")
        XCTAssertEqual(customMetadata["BSCALE"], "1.0", "Custom value should be preserved")
        
        // Should support retrieval by key
        let comment = metadata.customValue(for: "FITS_COMMENT")
        XCTAssertEqual(comment, "Test image", "Custom value retrieval should work")
    }
    
    func test_astroImageMetadata_shouldHandleComplexCustomTypes() throws {
        // Given: Complex custom metadata as encoded strings
        let customData: [String: String] = [
            "PROCESSING_PIPELINE": "dark_subtraction,flat_division,registration",
            "QUALITY_METRICS": "fwhm:2.3;eccentricity:0.15",
            "CALIBRATION_FRAMES": "42"
        ]
        let metadata = MockAstroImageMetadata(customMetadata: customData)
        
        // When: Accessing complex custom data
        let pipeline = metadata.customValue(for: "PROCESSING_PIPELINE")
        let metrics = metadata.customValue(for: "QUALITY_METRICS")
        let frames = metadata.customValue(for: "CALIBRATION_FRAMES")
        
        // Then: Should handle serialized complex data
        XCTAssertEqual(pipeline, "dark_subtraction,flat_division,registration", "Pipeline data should be preserved")
        XCTAssertEqual(metrics, "fwhm:2.3;eccentricity:0.15", "Metrics data should be preserved")
        XCTAssertEqual(frames, "42", "Numeric data should be preserved as string")
    }
    
    // MARK: - Behavior: Metadata should be Sendable for concurrent access
    
    func test_astroImageMetadata_shouldBeSendableForConcurrentAccess() async throws {
        // Given: Metadata used in concurrent context
        let metadata = MockAstroImageMetadata(width: 2048, height: 2048)
        
        // When: Accessed from multiple concurrent tasks
        let results = await withTaskGroup(of: String.self) { group in
            group.addTask { "dimensions: \(metadata.dimensions.width)x\(metadata.dimensions.height)" }
            group.addTask { "format: \(metadata.pixelFormat)" }
            group.addTask { "colorspace: \(metadata.colorSpace)" }
            group.addTask { "pixels: \(metadata.totalPixels)" }
            
            var taskResults: [String] = []
            for await result in group {
                taskResults.append(result)
            }
            return taskResults
        }
        
        // Then: Should work safely in concurrent contexts
        XCTAssertEqual(results.count, 4, "All concurrent accesses should succeed")
        XCTAssertTrue(results.contains { $0.contains("2048x2048") }, "Dimension access should work concurrently")
        XCTAssertTrue(results.contains { $0.contains("uint16") }, "Format access should work concurrently")
    }
    
    // MARK: - Behavior: Metadata should support format-specific extensions
    
    func test_astroImageMetadata_shouldSupportFormatSpecificData() throws {
        // Given: Metadata that might come from different formats
        let fitsMetadata = MockAstroImageMetadata(
            customMetadata: [
                "FITS_KEYWORD": "VALUE",
                "CRVAL1": "180.0",  // FITS WCS
                "CRVAL2": "45.0",
                "CDELT1": "0.001",
                "CDELT2": "0.001"
            ]
        )
        
        // When: Accessing format-specific data
        let fitsKeyword = fitsMetadata.customValue(for: "FITS_KEYWORD")
        let wcsData = [
            fitsMetadata.customValue(for: "CRVAL1"),
            fitsMetadata.customValue(for: "CRVAL2")
        ].compactMap { $0 }
        
        // Then: Should support format-specific metadata
        XCTAssertNotNil(fitsKeyword, "FITS keywords should be supported")
        XCTAssertEqual(wcsData.count, 2, "WCS coordinate data should be accessible")
    }
    
    func test_astroImageMetadata_shouldProvideMetadataQualityIndicators() throws {
        // Given: Metadata with varying completeness
        let completeMetadata = MockAstroImageMetadata()
        
        // When: Evaluating metadata completeness
        let hasBasicInfo = completeMetadata.hasBasicImageInfo
        let hasAstronomicalInfo = completeMetadata.hasAstronomicalInfo
        let completenessScore = completeMetadata.completenessScore
        
        // Then: Should provide quality indicators
        XCTAssertTrue(hasBasicInfo, "Basic image info should be present")
        XCTAssertGreaterThanOrEqual(completenessScore, 0.0, "Completeness score should be non-negative")
        XCTAssertLessThanOrEqual(completenessScore, 1.0, "Completeness score should not exceed 1.0")
        
        // Completeness should reflect available data
        if hasAstronomicalInfo {
            XCTAssertGreaterThan(completenessScore, 0.5, "Complete astronomical metadata should have high score")
        }
    }
    
    // MARK: - Behavior: Metadata should provide debugging and description capabilities
    
    func test_astroImageMetadata_shouldProvideHumanReadableDescription() throws {
        // Given: Metadata instance
        let metadata = MockAstroImageMetadata(
            width: 1920, height: 1080,
            pixelFormat: .uint16,
            colorSpace: .linear
        )
        
        // When: Getting description
        let description = metadata.description
        let debugDescription = metadata.debugDescription
        
        // Then: Should provide meaningful descriptions
        XCTAssertFalse(description.isEmpty, "Description should not be empty")
        XCTAssertTrue(description.contains("1920"), "Description should contain dimensions")
        XCTAssertTrue(description.contains("1080"), "Description should contain dimensions")
        
        XCTAssertFalse(debugDescription.isEmpty, "Debug description should not be empty")
        XCTAssertTrue(debugDescription.contains("uint16"), "Debug description should contain pixel format")
    }
}