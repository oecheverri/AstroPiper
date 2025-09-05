import XCTest
@testable import AstroPiperCore

/// Tests for HistogramData struct behavior
/// Focuses on: statistics computation from pixel data, thread-safety, value semantics,
/// percentile calculations, and performance characteristics
final class HistogramDataTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let samplePixelData8bit: [UInt8] = Array(0...255)
    private let samplePixelData16bit: [UInt16] = [0, 1000, 2000, 10000, 30000, 50000, 65535]
    private let sampleFloatData: [Float] = [0.0, 0.1, 0.5, 0.8, 1.0, 1.2, 2.0]
    
    // MARK: - Behavior: HistogramData should compute statistics from pixel data
    
    func test_histogramData_shouldComputeBasicStatistics() throws {
        // Given: Sample pixel data
        let pixelValues = samplePixelData16bit
        
        // When: Computing histogram from pixel data
        let histogram = HistogramData(pixelValues: pixelValues, bitDepth: 16)
        
        // Then: Should provide basic statistics
        XCTAssertEqual(histogram.count, pixelValues.count, "Count should match input pixel count")
        XCTAssertEqual(histogram.minimum, 0, "Minimum should be correct")
        XCTAssertEqual(histogram.maximum, 65535, "Maximum should be correct")
        XCTAssertGreaterThan(histogram.mean, 0, "Mean should be computed")
        XCTAssertGreaterThan(histogram.standardDeviation, 0, "Standard deviation should be computed")
    }
    
    func test_histogramData_shouldComputeAccurateMeanAndStdDev() throws {
        // Given: Known data with calculable statistics
        let knownData: [UInt16] = [100, 200, 300, 400, 500]
        let expectedMean: Double = 300.0
        
        // When: Computing histogram
        let histogram = HistogramData(pixelValues: knownData, bitDepth: 16)
        
        // Then: Statistics should be accurate
        XCTAssertEqual(histogram.mean, expectedMean, accuracy: 0.01, "Mean should be accurate")
        XCTAssertEqual(histogram.count, 5, "Count should be correct")
        XCTAssertGreaterThan(histogram.standardDeviation, 0, "Standard deviation should be positive")
    }
    
    func test_histogramData_shouldHandleDifferentBitDepths() throws {
        // Given: Data at different bit depths
        let data8bit = samplePixelData8bit.map { UInt16($0) }
        let data16bit = samplePixelData16bit
        
        // When: Creating histograms for different bit depths
        let histogram8 = HistogramData(pixelValues: data8bit, bitDepth: 8)
        let histogram16 = HistogramData(pixelValues: data16bit, bitDepth: 16)
        
        // Then: Should handle different ranges appropriately
        XCTAssertEqual(histogram8.bitDepth, 8, "8-bit histogram should report correct bit depth")
        XCTAssertEqual(histogram16.bitDepth, 16, "16-bit histogram should report correct bit depth")
        XCTAssertLessThan(histogram8.maximum, histogram16.maximum, "16-bit should have larger maximum")
    }
    
    // MARK: - Behavior: HistogramData should provide percentile calculations
    
    func test_histogramData_shouldComputePercentiles() throws {
        // Given: Sorted data for predictable percentiles
        let sortedData: [UInt16] = [0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
        
        // When: Computing histogram with percentiles
        let histogram = HistogramData(pixelValues: sortedData, bitDepth: 16)
        
        // Then: Should provide accurate percentile calculations
        let median = histogram.percentile(50)
        let q25 = histogram.percentile(25)
        let q75 = histogram.percentile(75)
        
        XCTAssertEqual(median, 500, accuracy: 50, "Median should be approximately correct")
        XCTAssertLessThan(q25, median, "25th percentile should be less than median")
        XCTAssertGreaterThan(q75, median, "75th percentile should be greater than median")
    }
    
    func test_histogramData_shouldProvideStandardPercentiles() throws {
        // Given: Histogram data
        let histogram = HistogramData(pixelValues: samplePixelData16bit, bitDepth: 16)
        
        // When: Requesting standard percentiles used in image stretching
        let p1 = histogram.percentile(1)
        let p99 = histogram.percentile(99)
        let median = histogram.percentile(50)
        
        // Then: Should provide meaningful values for stretching algorithms
        XCTAssertLessThan(p1, median, "1st percentile should be less than median")
        XCTAssertGreaterThan(p99, median, "99th percentile should be greater than median")
        XCTAssertGreaterThanOrEqual(p1, histogram.minimum, "1st percentile should be >= minimum")
        XCTAssertLessThanOrEqual(p99, histogram.maximum, "99th percentile should be <= maximum")
    }
    
    // MARK: - Behavior: HistogramData should be thread-safe and value-semantic
    
    func test_histogramData_shouldBeValueSemantic() throws {
        // Given: Original histogram data
        let originalData = samplePixelData16bit
        var histogram1 = HistogramData(pixelValues: originalData, bitDepth: 16)
        let histogram2 = histogram1
        
        // When: Modifying one instance (if mutable operations exist)
        // Note: Since this is a value type, this tests that copying works correctly
        let originalMean = histogram1.mean
        
        // Then: Copies should be independent
        XCTAssertEqual(histogram1.mean, histogram2.mean, "Copied histograms should have same values")
        XCTAssertEqual(histogram1.count, histogram2.count, "Copied histograms should have same count")
    }
    
    func test_histogramData_shouldBeSendableForConcurrentUse() async throws {
        // Given: Histogram data used in concurrent processing
        let histogram = HistogramData(pixelValues: samplePixelData16bit, bitDepth: 16)
        
        // When: Accessed from multiple concurrent tasks
        let results = await withTaskGroup(of: Double.self) { group in
            // Multiple tasks computing statistics concurrently
            group.addTask { histogram.mean }
            group.addTask { histogram.standardDeviation }
            group.addTask { histogram.percentile(50) }
            group.addTask { histogram.percentile(90) }
            
            var computedValues: [Double] = []
            for await result in group {
                computedValues.append(result)
            }
            return computedValues
        }
        
        // Then: Should work safely across concurrent contexts
        XCTAssertEqual(results.count, 4, "All concurrent computations should complete")
        XCTAssertTrue(results.allSatisfy { $0 > 0 }, "All computed statistics should be positive")
    }
    
    // MARK: - Behavior: HistogramData should support Codable serialization
    
    func test_histogramData_shouldSerializeToJSON() throws {
        // Given: Histogram that needs to be persisted
        let originalHistogram = HistogramData(pixelValues: samplePixelData16bit, bitDepth: 16)
        
        // When: Encoding and decoding
        let jsonData = try JSONEncoder().encode(originalHistogram)
        let decodedHistogram = try JSONDecoder().decode(HistogramData.self, from: jsonData)
        
        // Then: Should preserve all statistical data
        XCTAssertEqual(originalHistogram.count, decodedHistogram.count, "Count should be preserved")
        XCTAssertEqual(originalHistogram.mean, decodedHistogram.mean, accuracy: 0.001, "Mean should be preserved")
        XCTAssertEqual(originalHistogram.minimum, decodedHistogram.minimum, "Minimum should be preserved")
        XCTAssertEqual(originalHistogram.maximum, decodedHistogram.maximum, "Maximum should be preserved")
        XCTAssertEqual(originalHistogram.bitDepth, decodedHistogram.bitDepth, "Bit depth should be preserved")
    }
    
    // MARK: - Behavior: HistogramData should support Equatable comparison
    
    func test_histogramData_shouldCompareCorrectlyForEquality() throws {
        // Given: Identical and different histogram data
        let data1 = samplePixelData16bit
        let data2 = samplePixelData16bit
        let data3 = samplePixelData8bit.map { UInt16($0) }
        
        let histogram1 = HistogramData(pixelValues: data1, bitDepth: 16)
        let histogram2 = HistogramData(pixelValues: data2, bitDepth: 16)
        let histogram3 = HistogramData(pixelValues: data3, bitDepth: 8)
        
        // Then: Equality should work based on computed statistics
        XCTAssertEqual(histogram1, histogram2, "Histograms from same data should be equal")
        XCTAssertNotEqual(histogram1, histogram3, "Histograms from different data should not be equal")
    }
    
    // MARK: - Behavior: HistogramData should provide histogram bins for display
    
    func test_histogramData_shouldProvideHistogramBins() throws {
        // Given: Pixel data for histogram visualization
        let pixelData = samplePixelData16bit
        let histogram = HistogramData(pixelValues: pixelData, bitDepth: 16)
        
        // When: Requesting histogram bins for display
        let binCount = 256
        let bins = histogram.bins(count: binCount)
        
        // Then: Should provide appropriate binned data
        XCTAssertEqual(bins.count, binCount, "Should provide requested number of bins")
        XCTAssertEqual(bins.reduce(0, +), pixelData.count, "Total bin counts should equal pixel count")
        XCTAssertTrue(bins.allSatisfy { $0 >= 0 }, "All bin counts should be non-negative")
    }
    
    func test_histogramData_shouldProvideNormalizedBins() throws {
        // Given: Histogram data
        let histogram = HistogramData(pixelValues: samplePixelData16bit, bitDepth: 16)
        
        // When: Requesting normalized bins
        let normalizedBins = histogram.normalizedBins(count: 100)
        
        // Then: Should provide normalized values for display
        XCTAssertEqual(normalizedBins.count, 100, "Should provide requested number of bins")
        XCTAssertTrue(normalizedBins.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }, "Normalized bins should be in [0,1] range")
        
        // Sum should be approximately 1.0 for normalized histogram
        let sum = normalizedBins.reduce(0.0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.01, "Normalized bins should sum to approximately 1.0")
    }
    
    // MARK: - Behavior: HistogramData should handle edge cases gracefully
    
    func test_histogramData_shouldHandleEmptyData() throws {
        // Given: Empty pixel data
        let emptyData: [UInt16] = []
        
        // When: Creating histogram from empty data
        let histogram = HistogramData(pixelValues: emptyData, bitDepth: 16)
        
        // Then: Should handle gracefully without crashing
        XCTAssertEqual(histogram.count, 0, "Empty data should have zero count")
        XCTAssertTrue(histogram.mean.isNaN || histogram.mean == 0, "Mean of empty data should be NaN or 0")
    }
    
    func test_histogramData_shouldHandleSingleValue() throws {
        // Given: Single pixel value (flat image)
        let singleValue: [UInt16] = Array(repeating: 1000, count: 100)
        
        // When: Creating histogram
        let histogram = HistogramData(pixelValues: singleValue, bitDepth: 16)
        
        // Then: Should handle flat distributions correctly
        XCTAssertEqual(histogram.count, 100, "Count should be correct")
        XCTAssertEqual(histogram.mean, 1000, accuracy: 0.01, "Mean should equal the single value")
        XCTAssertEqual(histogram.standardDeviation, 0, accuracy: 0.01, "Standard deviation should be zero")
        XCTAssertEqual(histogram.minimum, 1000, "Min should equal the value")
        XCTAssertEqual(histogram.maximum, 1000, "Max should equal the value")
    }
    
    // MARK: - Behavior: HistogramData should provide performance characteristics
    
    func test_histogramData_shouldComputeEfficientlyForLargeImages() throws {
        // Given: Large dataset simulating astronomical image
        let largeDataset = Array(repeating: samplePixelData16bit, count: 1000).flatMap { $0 }
        
        // When: Computing histogram (should be reasonably fast)
        let startTime = CFAbsoluteTimeGetCurrent()
        let histogram = HistogramData(pixelValues: largeDataset, bitDepth: 16)
        let computeTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete in reasonable time and provide correct results
        XCTAssertLessThan(computeTime, 1.0, "Histogram computation should be efficient")
        XCTAssertEqual(histogram.count, largeDataset.count, "Count should be correct for large dataset")
        XCTAssertGreaterThan(histogram.mean, 0, "Statistics should be computed for large dataset")
    }
}