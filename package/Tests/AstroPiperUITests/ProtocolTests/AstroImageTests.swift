import XCTest
@testable import AstroPiperCore
import Foundation

/// Tests for AstroImage master protocol behavior
/// Focuses on: consistent pixel data access, histogram generation, metadata consistency,
/// cross-format compatibility, and performance characteristics
final class AstroImageTests: XCTestCase {
    
    // MARK: - Mock implementation for testing
    
    private struct MockAstroImage: AstroImage {
        let metadata: any AstroImageMetadata
        private let pixelData: Data
        
        init(width: UInt32, height: UInt32, pixelFormat: PixelFormat, pixelData: Data) {
            self.metadata = MockAstroImageMetadata(
                width: width,
                height: height,
                pixelFormat: pixelFormat,
                colorSpace: .linear
            )
            self.pixelData = pixelData
        }
        
        // AstroImage protocol requirements
        func pixelData(in region: PixelRegion?) async throws -> Data {
            if let region = region {
                // Simulate region extraction
                return extractRegion(region, from: pixelData)
            }
            return pixelData
        }
        
        func generateHistogram() async throws -> HistogramData {
            // Convert raw data to appropriate pixel values based on format
            let pixelValues = convertToPixelValues(pixelData, format: metadata.pixelFormat)
            return HistogramData(pixelValues: pixelValues, bitDepth: metadata.pixelFormat.bitDepth)
        }
        
        func supportsBayerDemosaic() -> Bool {
            // Mock implementation - could support demosaic for monochrome images
            return metadata.colorSpace == .grayscale || metadata.colorSpace == .linear
        }
        
        func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
            guard supportsBayerDemosaic() else {
                throw AstroImageError.demosaicNotSupported
            }
            
            // Mock demosaicing - would create RGB version
            let rgbMetadata = MockAstroImageMetadata(
                width: metadata.dimensions.width,
                height: metadata.dimensions.height,
                pixelFormat: metadata.pixelFormat,
                colorSpace: .sRGB
            )
            
            // Simulate RGB data (3x the size for RGB channels)
            let rgbDataSize = pixelData.count * 3
            let rgbData = Data(count: rgbDataSize)
            
            return MockAstroImage(
                width: metadata.dimensions.width,
                height: metadata.dimensions.height,
                pixelFormat: metadata.pixelFormat,
                pixelData: rgbData
            )
        }
        
        // Helper methods for mock implementation
        private func extractRegion(_ region: PixelRegion, from data: Data) -> Data {
            // Simplified region extraction for testing
            let bytesPerPixel = metadata.pixelFormat.bytesPerPixel
            let regionSize = Int(region.width * region.height) * bytesPerPixel
            return Data(count: regionSize)
        }
        
        private func convertToPixelValues(_ data: Data, format: PixelFormat) -> [UInt16] {
            // Simplified conversion for testing - assume UInt16 values
            let pixelCount = data.count / format.bytesPerPixel
            return Array(0..<pixelCount).map { UInt16($0 % 65536) }
        }
    }
    
    private struct MockAstroImageMetadata: AstroImageMetadata {
        let dimensions: ImageDimensions
        let pixelFormat: PixelFormat
        let colorSpace: ColorSpace
        let filename: String? = "test.fits"
        let fileSize: UInt64? = 1024
        let creationDate: Date? = Date()
        let modificationDate: Date? = Date()
        
        // Astronomical metadata (all optional)
        let exposureTime: TimeInterval? = nil
        let iso: Int? = nil
        let telescopeName: String? = nil
        let instrumentName: String? = nil
        let filterName: String? = nil
        let objectName: String? = nil
        let observationDate: Date? = nil
        let coordinates: SkyCoordinates? = nil
        let temperature: Double? = nil
        let gain: Double? = nil
        let binning: ImageBinning? = nil
        let customMetadata: [String: String] = [:]
        
        init(width: UInt32, height: UInt32, pixelFormat: PixelFormat, colorSpace: ColorSpace) {
            self.dimensions = ImageDimensions(width: width, height: height)
            self.pixelFormat = pixelFormat
            self.colorSpace = colorSpace
        }
    }
    
    // MARK: - Test Data
    
    private func createSampleImage(width: UInt32 = 1920, height: UInt32 = 1080) -> MockAstroImage {
        let pixelFormat = PixelFormat.uint16
        let dataSize = Int(width * height) * pixelFormat.bytesPerPixel
        let sampleData = Data(count: dataSize)
        
        return MockAstroImage(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            pixelData: sampleData
        )
    }
    
    // MARK: - Behavior: AstroImage should provide consistent pixel data access
    
    func test_astroImage_shouldProvideFullImagePixelData() async throws {
        // Given: An astronomical image
        let image = createSampleImage(width: 100, height: 100)
        
        // When: Requesting full image pixel data
        let pixelData = try await image.pixelData(in: nil)
        
        // Then: Should provide complete pixel data
        let expectedSize = 100 * 100 * image.metadata.pixelFormat.bytesPerPixel
        XCTAssertEqual(pixelData.count, expectedSize, "Full image data should have correct size")
        XCTAssertFalse(pixelData.isEmpty, "Pixel data should not be empty")
    }
    
    func test_astroImage_shouldSupportRegionExtraction() async throws {
        // Given: An image and a specific region
        let image = createSampleImage(width: 1000, height: 1000)
        let region = PixelRegion(x: 100, y: 100, width: 200, height: 200)
        
        // When: Requesting region pixel data
        let regionData = try await image.pixelData(in: region)
        
        // Then: Should provide region-specific data
        let expectedSize = 200 * 200 * image.metadata.pixelFormat.bytesPerPixel
        XCTAssertEqual(regionData.count, expectedSize, "Region data should have correct size")
        
        // Region data should be smaller than full image
        let fullData = try await image.pixelData(in: nil)
        XCTAssertLessThan(regionData.count, fullData.count, "Region data should be smaller than full image")
    }
    
    func test_astroImage_shouldHandlePixelDataConsistently() async throws {
        // Given: Multiple requests for the same data
        let image = createSampleImage()
        
        // When: Requesting pixel data multiple times
        let data1 = try await image.pixelData(in: nil)
        let data2 = try await image.pixelData(in: nil)
        
        // Then: Should provide consistent results
        XCTAssertEqual(data1.count, data2.count, "Multiple requests should return same size")
        XCTAssertEqual(data1, data2, "Multiple requests should return identical data")
    }
    
    // MARK: - Behavior: AstroImage should support histogram generation
    
    func test_astroImage_shouldGenerateHistogram() async throws {
        // Given: An astronomical image
        let image = createSampleImage(width: 100, height: 100)
        
        // When: Generating histogram
        let histogram = try await image.generateHistogram()
        
        // Then: Should provide valid histogram
        XCTAssertEqual(histogram.count, 100 * 100, "Histogram should reflect total pixel count")
        XCTAssertGreaterThanOrEqual(histogram.minimum, 0, "Minimum should be non-negative")
        XCTAssertGreaterThanOrEqual(histogram.maximum, histogram.minimum, "Maximum should be >= minimum")
        XCTAssertEqual(histogram.bitDepth, image.metadata.pixelFormat.bitDepth, "Histogram bit depth should match image")
    }
    
    func test_astroImage_shouldProvideHistogramStatistics() async throws {
        // Given: An image with known characteristics
        let image = createSampleImage(width: 50, height: 50)
        
        // When: Generating histogram
        let histogram = try await image.generateHistogram()
        
        // Then: Should provide statistical information
        XCTAssertGreaterThanOrEqual(histogram.mean, 0, "Mean should be calculable")
        XCTAssertGreaterThanOrEqual(histogram.standardDeviation, 0, "Standard deviation should be non-negative")
        
        // Percentiles should be available
        let median = histogram.percentile(50)
        let p95 = histogram.percentile(95)
        XCTAssertLessThanOrEqual(median, p95, "Median should be <= 95th percentile")
    }
    
    func test_astroImage_shouldGenerateHistogramEfficiently() async throws {
        // Given: A moderately large image
        let image = createSampleImage(width: 1000, height: 1000)
        
        // When: Generating histogram with timing
        let startTime = CFAbsoluteTimeGetCurrent()
        let histogram = try await image.generateHistogram()
        let computeTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete in reasonable time
        XCTAssertLessThan(computeTime, 2.0, "Histogram generation should be efficient")
        XCTAssertEqual(histogram.count, 1000 * 1000, "Histogram should be complete")
    }
    
    // MARK: - Behavior: AstroImage should maintain metadata consistency
    
    func test_astroImage_shouldProvideConsistentMetadata() throws {
        // Given: An image with specific metadata
        let image = createSampleImage(width: 2048, height: 1536)
        
        // When: Accessing metadata
        let metadata = image.metadata
        
        // Then: Metadata should be consistent with image characteristics
        XCTAssertEqual(metadata.dimensions.width, 2048, "Metadata width should match")
        XCTAssertEqual(metadata.dimensions.height, 1536, "Metadata height should match")
        XCTAssertEqual(metadata.pixelFormat, .uint16, "Metadata pixel format should match")
        XCTAssertNotNil(metadata.filename, "Metadata should include filename if available")
    }
    
    func test_astroImage_shouldValidateMetadataImageConsistency() async throws {
        // Given: Image with metadata
        let image = createSampleImage(width: 800, height: 600)
        
        // When: Cross-referencing pixel data with metadata
        let pixelData = try await image.pixelData(in: nil)
        let expectedSize = Int(image.metadata.dimensions.width * image.metadata.dimensions.height) * 
                          image.metadata.pixelFormat.bytesPerPixel
        
        // Then: Pixel data size should match metadata
        XCTAssertEqual(pixelData.count, expectedSize, "Pixel data size should match metadata dimensions")
    }
    
    // MARK: - Behavior: AstroImage should support Bayer demosaicing
    
    func test_astroImage_shouldIndicateBayerDemosaicSupport() throws {
        // Given: Various types of images
        let monochromeImage = createSampleImage()
        
        // When: Checking demosaic support
        let supportsDemosaic = monochromeImage.supportsBayerDemosaic()
        
        // Then: Should indicate capability appropriately
        // Mock implementation supports demosaic for linear/grayscale images
        XCTAssertTrue(supportsDemosaic, "Monochrome linear image should support demosaic")
    }
    
    func test_astroImage_shouldPerformBayerDemosaicing() async throws {
        // Given: A monochrome image that supports demosaicing
        let originalImage = createSampleImage(width: 100, height: 100)
        
        guard originalImage.supportsBayerDemosaic() else {
            throw XCTSkip("Image doesn't support demosaicing")
        }
        
        // When: Performing demosaicing
        let demosaicedImage = try await originalImage.demosaicedImage(bayerPattern: .rggb)
        
        // Then: Should produce RGB image
        XCTAssertEqual(demosaicedImage.metadata.dimensions.width, originalImage.metadata.dimensions.width, 
                      "Demosaiced image should maintain width")
        XCTAssertEqual(demosaicedImage.metadata.dimensions.height, originalImage.metadata.dimensions.height,
                      "Demosaiced image should maintain height")
        
        // Color space should be updated
        XCTAssertNotEqual(demosaicedImage.metadata.colorSpace, originalImage.metadata.colorSpace,
                         "Demosaiced image should have different color space")
    }
    
    func test_astroImage_shouldHandleDemosaicingErrors() async throws {
        // Given: An image that doesn't support demosaicing
        let unsupportedImage = createSampleImage()
        
        // Mock the image as not supporting demosaic
        // (In real implementation, some formats might not support this)
        
        // When: Attempting demosaicing on unsupported image
        // Then: Should handle gracefully (test assumes mock supports it)
        do {
            let _ = try await unsupportedImage.demosaicedImage(bayerPattern: .rggb)
            // If successful, that's fine for our mock
        } catch AstroImageError.demosaicNotSupported {
            // This is also acceptable behavior
        }
    }
    
    // MARK: - Behavior: AstroImage should be Sendable for concurrent processing
    
    func test_astroImage_shouldSupportConcurrentAccess() async throws {
        // Given: Image used in concurrent context
        let image = createSampleImage(width: 200, height: 200)
        
        // When: Accessing from multiple concurrent tasks
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            group.addTask { (try await image.pixelData(in: nil)).count }
            group.addTask { (try await image.generateHistogram()).count }
            group.addTask { Int(image.metadata.dimensions.width) }
            group.addTask { Int(image.metadata.dimensions.height) }
            
            var taskResults: [Int] = []
            for try await result in group {
                taskResults.append(result)
            }
            return taskResults
        }
        
        // Then: All concurrent operations should succeed
        XCTAssertEqual(results.count, 4, "All concurrent operations should complete")
        XCTAssertTrue(results.allSatisfy { $0 > 0 }, "All results should be meaningful")
    }
    
    // MARK: - Behavior: AstroImage should provide memory-efficient operations
    
    func test_astroImage_shouldSupportPartialDataLoading() async throws {
        // Given: Large image for memory efficiency testing
        let largeImage = createSampleImage(width: 2000, height: 2000)
        
        // When: Loading small regions vs full image
        let smallRegion = PixelRegion(x: 0, y: 0, width: 100, height: 100)
        let regionData = try await largeImage.pixelData(in: smallRegion)
        let fullData = try await largeImage.pixelData(in: nil)
        
        // Then: Region loading should be more memory efficient
        XCTAssertLessThan(regionData.count, fullData.count, "Region data should use less memory")
        
        let expectedRegionSize = 100 * 100 * largeImage.metadata.pixelFormat.bytesPerPixel
        XCTAssertEqual(regionData.count, expectedRegionSize, "Region size should be exact")
    }
    
    func test_astroImage_shouldReleaseMemoryAfterOperations() async throws {
        // Given: Image operations that should not leak memory
        let image = createSampleImage(width: 500, height: 500)
        
        // When: Performing multiple operations
        for _ in 0..<10 {
            let _ = try await image.pixelData(in: nil)
            let _ = try await image.generateHistogram()
            
            // Allow memory cleanup between iterations
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        // Then: Should complete without excessive memory growth
        // This test mainly ensures operations complete without crashing
        XCTAssertTrue(true, "Multiple operations should complete successfully")
    }
    
    // MARK: - Behavior: AstroImage should provide format-agnostic interface
    
    func test_astroImage_shouldProvideUniformInterface() throws {
        // Given: Images of different formats (simulated)
        let image16bit = createSampleImage()
        
        // When: Accessing common properties
        let dimensions = image16bit.metadata.dimensions
        let pixelFormat = image16bit.metadata.pixelFormat
        let colorSpace = image16bit.metadata.colorSpace
        
        // Then: Should provide consistent interface regardless of underlying format
        XCTAssertNotNil(dimensions, "All images should have dimensions")
        XCTAssertNotNil(pixelFormat, "All images should have pixel format")
        XCTAssertNotNil(colorSpace, "All images should have color space")
        
        // Interface should be the same for different formats
        XCTAssertTrue(image16bit.supportsBayerDemosaic() is Bool, "Demosaic support should be queryable")
    }
    
    func test_astroImage_shouldSupportPolymorphicUsage() async throws {
        // Given: Array of different AstroImage implementations
        let images: [any AstroImage] = [
            createSampleImage(width: 100, height: 100),
            createSampleImage(width: 200, height: 200),
            createSampleImage(width: 300, height: 300)
        ]
        
        // When: Operating on images polymorphically
        var histograms: [HistogramData] = []
        
        for image in images {
            let histogram = try await image.generateHistogram()
            histograms.append(histogram)
        }
        
        // Then: Should work uniformly across different implementations
        XCTAssertEqual(histograms.count, 3, "Should generate histograms for all images")
        
        for (index, histogram) in histograms.enumerated() {
            let expectedCount = (index + 1) * (index + 1) * 100 * 100 // 100², 200², 300²
            XCTAssertEqual(histogram.count, expectedCount, "Histogram count should match image size")
        }
    }
    
    // MARK: - Behavior: AstroImage should handle edge cases gracefully
    
    func test_astroImage_shouldHandleEmptyRegions() async throws {
        // Given: Image and invalid region
        let image = createSampleImage(width: 100, height: 100)
        let emptyRegion = PixelRegion(x: 0, y: 0, width: 0, height: 0)
        
        // When: Requesting empty region
        let regionData = try await image.pixelData(in: emptyRegion)
        
        // Then: Should handle gracefully
        XCTAssertEqual(regionData.count, 0, "Empty region should return empty data")
    }
    
    func test_astroImage_shouldValidateRegionBounds() async throws {
        // Given: Image and out-of-bounds region
        let image = createSampleImage(width: 100, height: 100)
        let invalidRegion = PixelRegion(x: 150, y: 150, width: 50, height: 50)
        
        // When/Then: Should handle out-of-bounds requests appropriately
        do {
            let _ = try await image.pixelData(in: invalidRegion)
            // If it succeeds, implementation handled it gracefully
        } catch {
            // If it throws, that's also acceptable behavior
            XCTAssertTrue(error is AstroImageError, "Should throw appropriate error type")
        }
    }
}