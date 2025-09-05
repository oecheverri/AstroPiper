import XCTest
@testable import AstroPiperCore

/// Tests for PixelFormat enum behavior
/// Focuses on: representation of astronomical image data types, bit depth information, 
/// serialization capabilities, and value equality
final class PixelFormatTests: XCTestCase {
    
    // MARK: - Behavior: PixelFormat should represent all astronomical image data types
    
    func test_pixelFormat_shouldProvideAllAstronomicalDataTypes() throws {
        // Given: Common astronomical image data types
        let expectedFormats: [PixelFormat] = [
            .uint8,
            .uint16, 
            .uint32,
            .int16,
            .int32,
            .float32,
            .float64
        ]
        
        // Then: All formats should be available
        for format in expectedFormats {
            XCTAssertNotNil(format, "PixelFormat should provide \(format) for astronomical images")
        }
    }
    
    func test_pixelFormat_shouldSupportMonochromeAndColorChannels() throws {
        // Given: Both single-channel and multi-channel images are common in astronomy
        let monochromeFormat = PixelFormat.uint16
        let colorFormat = PixelFormat.uint16 // Same format but will be used for color
        
        // Then: Format should be applicable to both cases
        XCTAssertNotNil(monochromeFormat)
        XCTAssertNotNil(colorFormat)
        XCTAssertEqual(monochromeFormat, colorFormat, "Same pixel format should work for mono and color")
    }
    
    // MARK: - Behavior: PixelFormat should provide bit depth information
    
    func test_pixelFormat_shouldProvideBitDepthInformation() throws {
        // Given: Different pixel formats with known bit depths
        let testCases: [(format: PixelFormat, expectedBitDepth: Int)] = [
            (.uint8, 8),
            (.uint16, 16),
            (.uint32, 32),
            (.int16, 16),
            (.int32, 32),
            (.float32, 32),
            (.float64, 64)
        ]
        
        // Then: Each format should report correct bit depth
        for testCase in testCases {
            XCTAssertEqual(
                testCase.format.bitDepth,
                testCase.expectedBitDepth,
                "\(testCase.format) should report \(testCase.expectedBitDepth) bit depth"
            )
        }
    }
    
    func test_pixelFormat_shouldProvideMemoryFootprintCalculation() throws {
        // Given: Pixel formats with known memory requirements
        let uint16Format = PixelFormat.uint16
        let float32Format = PixelFormat.float32
        let pixelCount = 1000
        
        // Then: Memory calculations should be accurate
        XCTAssertEqual(uint16Format.bytesPerPixel * pixelCount, uint16Format.memoryFootprint(for: pixelCount))
        XCTAssertEqual(float32Format.bytesPerPixel * pixelCount, float32Format.memoryFootprint(for: pixelCount))
        XCTAssertGreaterThan(float32Format.bytesPerPixel, uint16Format.bytesPerPixel, "Float32 should use more memory than UInt16")
    }
    
    // MARK: - Behavior: PixelFormat should support Codable serialization
    
    func test_pixelFormat_shouldSerializeToJSON() throws {
        // Given: A pixel format that needs to be serialized
        let originalFormat = PixelFormat.uint16
        
        // When: Encoding to JSON
        let jsonData = try JSONEncoder().encode(originalFormat)
        let decodedFormat = try JSONDecoder().decode(PixelFormat.self, from: jsonData)
        
        // Then: Serialization should preserve format identity
        XCTAssertEqual(originalFormat, decodedFormat, "PixelFormat should survive JSON serialization")
    }
    
    func test_pixelFormat_shouldHandleAllFormatsInSerialization() throws {
        // Given: All available pixel formats
        let allFormats: [PixelFormat] = [.uint8, .uint16, .uint32, .int16, .int32, .float32, .float64]
        
        // When: Encoding and decoding each format
        for format in allFormats {
            let jsonData = try JSONEncoder().encode(format)
            let decodedFormat = try JSONDecoder().decode(PixelFormat.self, from: jsonData)
            
            // Then: Each format should serialize correctly
            XCTAssertEqual(format, decodedFormat, "\(format) should serialize correctly")
        }
    }
    
    // MARK: - Behavior: PixelFormat should support Equatable comparison
    
    func test_pixelFormat_shouldCompareCorrectlyForEquality() throws {
        // Given: Same and different pixel formats
        let format1 = PixelFormat.uint16
        let format2 = PixelFormat.uint16
        let format3 = PixelFormat.float32
        
        // Then: Equality should work correctly
        XCTAssertEqual(format1, format2, "Same pixel formats should be equal")
        XCTAssertNotEqual(format1, format3, "Different pixel formats should not be equal")
    }
    
    func test_pixelFormat_shouldHashCorrectlyForCollections() throws {
        // Given: Pixel formats in a set
        let formats: Set<PixelFormat> = [.uint8, .uint16, .uint16, .float32]
        
        // Then: Set should deduplicate correctly
        XCTAssertEqual(formats.count, 3, "Set should contain unique formats only")
        XCTAssertTrue(formats.contains(.uint16), "Set should contain uint16")
        XCTAssertTrue(formats.contains(.float32), "Set should contain float32")
    }
    
    // MARK: - Behavior: PixelFormat should be Sendable for concurrent processing
    
    func test_pixelFormat_shouldBeSendableForConcurrentUse() async throws {
        // Given: Pixel format used across concurrent contexts
        let format = PixelFormat.uint16
        
        // When: Used in async context
        let result = await withTaskGroup(of: PixelFormat.self) { group in
            group.addTask { format } // Should compile without warnings if Sendable
            group.addTask { format }
            
            var results: [PixelFormat] = []
            for await taskResult in group {
                results.append(taskResult)
            }
            return results
        }
        
        // Then: Should work without data races
        XCTAssertEqual(result.count, 2, "Concurrent access should work")
        XCTAssertTrue(result.allSatisfy { $0 == format }, "All results should match original format")
    }
    
    // MARK: - Behavior: PixelFormat should provide dynamic range information
    
    func test_pixelFormat_shouldProvideDynamicRangeCapabilities() throws {
        // Given: Different format types
        let integerFormat = PixelFormat.uint16
        let floatFormat = PixelFormat.float32
        
        // Then: Should distinguish between integer and floating point formats
        XCTAssertFalse(integerFormat.isFloatingPoint, "Integer formats should not be floating point")
        XCTAssertTrue(floatFormat.isFloatingPoint, "Float formats should be floating point")
        
        XCTAssertTrue(integerFormat.isSigned == false, "UInt16 should be unsigned")
        XCTAssertTrue(PixelFormat.int16.isSigned, "Int16 should be signed")
    }
}