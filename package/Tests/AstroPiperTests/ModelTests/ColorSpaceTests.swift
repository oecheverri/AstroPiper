import XCTest
@testable import AstroPiperCore

/// Tests for ColorSpace enum behavior
/// Focuses on: standard astronomical color spaces, transformation matrices,
/// Sendable concurrency safety, and color space conversions
final class ColorSpaceTests: XCTestCase {
    
    // MARK: - Behavior: ColorSpace should represent standard astronomical color spaces
    
    func test_colorSpace_shouldProvideStandardAstronomicalColorSpaces() throws {
        // Given: Common astronomical color spaces
        let expectedColorSpaces: [ColorSpace] = [
            .sRGB,
            .displayP3,
            .rec2020,
            .linear,
            .grayscale,
            .cie1931XYZ
        ]
        
        // Then: All color spaces should be available
        for colorSpace in expectedColorSpaces {
            XCTAssertNotNil(colorSpace, "ColorSpace should provide \(colorSpace) for astronomical imaging")
        }
    }
    
    func test_colorSpace_shouldSupportMonochromeImagery() throws {
        // Given: Monochrome is very common in astronomical imaging
        let grayscaleColorSpace = ColorSpace.grayscale
        let linearColorSpace = ColorSpace.linear
        
        // Then: Should support single-channel representations
        XCTAssertEqual(grayscaleColorSpace.channelCount, 1, "Grayscale should have 1 channel")
        XCTAssertTrue(grayscaleColorSpace.isMonochrome, "Grayscale should be monochrome")
        XCTAssertFalse(ColorSpace.sRGB.isMonochrome, "sRGB should not be monochrome")
    }
    
    func test_colorSpace_shouldDistinguishLinearFromGammaCorrected() throws {
        // Given: Linear vs gamma-corrected color spaces are important in astronomy
        let linearSpace = ColorSpace.linear
        let sRGBSpace = ColorSpace.sRGB
        
        // Then: Should distinguish linear from gamma-corrected
        XCTAssertTrue(linearSpace.isLinear, "Linear color space should be linear")
        XCTAssertFalse(sRGBSpace.isLinear, "sRGB should not be linear (gamma-corrected)")
    }
    
    // MARK: - Behavior: ColorSpace should provide transformation matrices
    
    func test_colorSpace_shouldProvideWhitePointInformation() throws {
        // Given: Different color spaces with known white points
        let sRGB = ColorSpace.sRGB
        let displayP3 = ColorSpace.displayP3
        let rec2020 = ColorSpace.rec2020
        
        // Then: Should provide white point information
        XCTAssertNotNil(sRGB.whitePoint, "sRGB should have white point")
        XCTAssertNotNil(displayP3.whitePoint, "Display P3 should have white point")
        XCTAssertNotNil(rec2020.whitePoint, "Rec2020 should have white point")
        
        // Standard illuminant D65 for most color spaces
        let d65WhitePoint = ColorSpace.WhitePoint.d65
        XCTAssertEqual(sRGB.whitePoint, d65WhitePoint, "sRGB uses D65 illuminant")
    }
    
    func test_colorSpace_shouldProvideGamutInformation() throws {
        // Given: Color spaces with different gamut sizes
        let sRGB = ColorSpace.sRGB
        let rec2020 = ColorSpace.rec2020
        
        // Then: Should indicate relative gamut coverage
        XCTAssertLessThan(sRGB.gamutCoverage, rec2020.gamutCoverage, "Rec2020 should have larger gamut than sRGB")
        XCTAssertGreaterThan(sRGB.gamutCoverage, 0.0, "Gamut coverage should be positive")
        XCTAssertLessThanOrEqual(rec2020.gamutCoverage, 1.0, "Gamut coverage should not exceed 100%")
    }
    
    // MARK: - Behavior: ColorSpace should support Sendable concurrency
    
    func test_colorSpace_shouldBeSendableForConcurrentProcessing() async throws {
        // Given: Color space used in concurrent image processing
        let colorSpace = ColorSpace.linear
        
        // When: Used across multiple async tasks
        let results = await withTaskGroup(of: ColorSpace.self) { group in
            // Add multiple tasks that use the color space
            for _ in 0..<5 {
                group.addTask { colorSpace } // Should compile without Sendable warnings
            }
            
            var taskResults: [ColorSpace] = []
            for await result in group {
                taskResults.append(result)
            }
            return taskResults
        }
        
        // Then: Should work safely in concurrent contexts
        XCTAssertEqual(results.count, 5, "All concurrent tasks should complete")
        XCTAssertTrue(results.allSatisfy { $0 == colorSpace }, "All results should match original")
    }
    
    // MARK: - Behavior: ColorSpace should support Codable serialization
    
    func test_colorSpace_shouldSerializeToJSON() throws {
        // Given: Color space that needs persistence
        let originalColorSpace = ColorSpace.displayP3
        
        // When: Encoding and decoding
        let jsonData = try JSONEncoder().encode(originalColorSpace)
        let decodedColorSpace = try JSONDecoder().decode(ColorSpace.self, from: jsonData)
        
        // Then: Should preserve identity through serialization
        XCTAssertEqual(originalColorSpace, decodedColorSpace, "ColorSpace should survive JSON serialization")
    }
    
    func test_colorSpace_shouldHandleAllColorSpacesInSerialization() throws {
        // Given: All available color spaces
        let allColorSpaces: [ColorSpace] = [
            .sRGB, .displayP3, .rec2020, .linear, .grayscale, .cie1931XYZ
        ]
        
        // When: Serializing each color space
        for colorSpace in allColorSpaces {
            let jsonData = try JSONEncoder().encode(colorSpace)
            let decodedColorSpace = try JSONDecoder().decode(ColorSpace.self, from: jsonData)
            
            // Then: Each should serialize correctly
            XCTAssertEqual(colorSpace, decodedColorSpace, "\(colorSpace) should serialize correctly")
        }
    }
    
    // MARK: - Behavior: ColorSpace should support Equatable comparison
    
    func test_colorSpace_shouldCompareCorrectlyForEquality() throws {
        // Given: Same and different color spaces
        let space1 = ColorSpace.sRGB
        let space2 = ColorSpace.sRGB
        let space3 = ColorSpace.displayP3
        
        // Then: Equality should work correctly
        XCTAssertEqual(space1, space2, "Same color spaces should be equal")
        XCTAssertNotEqual(space1, space3, "Different color spaces should not be equal")
    }
    
    func test_colorSpace_shouldWorkInCollections() throws {
        // Given: Color spaces in a set
        let colorSpaces: Set<ColorSpace> = [.sRGB, .displayP3, .displayP3, .linear]
        
        // Then: Set should handle uniqueness correctly
        XCTAssertEqual(colorSpaces.count, 3, "Set should contain unique color spaces only")
        XCTAssertTrue(colorSpaces.contains(.sRGB), "Set should contain sRGB")
        XCTAssertTrue(colorSpaces.contains(.displayP3), "Set should contain Display P3")
        XCTAssertTrue(colorSpaces.contains(.linear), "Set should contain linear")
    }
    
    // MARK: - Behavior: ColorSpace should provide channel information
    
    func test_colorSpace_shouldProvideChannelCount() throws {
        // Given: Color spaces with different channel counts
        let grayscale = ColorSpace.grayscale
        let sRGB = ColorSpace.sRGB
        let cie = ColorSpace.cie1931XYZ
        
        // Then: Should report correct channel counts
        XCTAssertEqual(grayscale.channelCount, 1, "Grayscale should have 1 channel")
        XCTAssertEqual(sRGB.channelCount, 3, "sRGB should have 3 channels (RGB)")
        XCTAssertEqual(cie.channelCount, 3, "CIE XYZ should have 3 channels")
    }
    
    func test_colorSpace_shouldProvideChannelNames() throws {
        // Given: Color spaces with known channel names
        let sRGB = ColorSpace.sRGB
        let grayscale = ColorSpace.grayscale
        
        // Then: Should provide meaningful channel names
        XCTAssertEqual(sRGB.channelNames, ["Red", "Green", "Blue"], "sRGB should have RGB channel names")
        XCTAssertEqual(grayscale.channelNames, ["Luminance"], "Grayscale should have luminance channel")
    }
    
    // MARK: - Behavior: ColorSpace should handle color space conversion readiness
    
    func test_colorSpace_shouldIndicateConversionCapability() throws {
        // Given: Color spaces that might need conversion
        let linear = ColorSpace.linear
        let sRGB = ColorSpace.sRGB
        let unsupported = ColorSpace.cie1931XYZ
        
        // Then: Should indicate what conversions are supported
        XCTAssertTrue(linear.canConvertTo(.sRGB), "Linear should convert to sRGB")
        XCTAssertTrue(sRGB.canConvertTo(.linear), "sRGB should convert to linear")
        XCTAssertTrue(sRGB.canConvertTo(.displayP3), "sRGB should convert to Display P3")
        
        // Some conversions might not be directly supported
        XCTAssertFalse(ColorSpace.grayscale.canConvertTo(.cie1931XYZ), "Complex conversions might not be direct")
    }
}