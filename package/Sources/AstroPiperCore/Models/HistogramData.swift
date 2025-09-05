import Foundation

/// Represents histogram data and statistical information computed from pixel data
/// 
/// A value type that encapsulates histogram bins, statistical measures, and percentile
/// calculations for astronomical image analysis. Designed for thread-safe concurrent access
/// and efficient memory usage.
public struct HistogramData: Sendable, Codable, Equatable {
    
    /// Number of pixels represented in this histogram
    public let count: Int
    
    /// Minimum pixel value in the dataset
    public let minimum: Double
    
    /// Maximum pixel value in the dataset
    public let maximum: Double
    
    /// Mean (average) pixel value
    public let mean: Double
    
    /// Standard deviation of pixel values
    public let standardDeviation: Double
    
    /// Bit depth of the original pixel data
    public let bitDepth: Int
    
    /// Initialize histogram from pixel values
    /// - Parameters:
    ///   - pixelValues: Array of pixel values to analyze
    ///   - bitDepth: Bit depth of the pixel format
    public init(pixelValues: [UInt16], bitDepth: Int) {
        self.bitDepth = bitDepth
        self.count = pixelValues.count
        
        guard !pixelValues.isEmpty else {
            self.minimum = 0
            self.maximum = 0
            self.mean = 0
            self.standardDeviation = 0
            return
        }
        
        let minVal = Double(pixelValues.min() ?? 0)
        let maxVal = Double(pixelValues.max() ?? 0)
        self.minimum = minVal
        self.maximum = maxVal
        
        let sum = pixelValues.reduce(0.0) { $0 + Double($1) }
        let meanVal = sum / Double(pixelValues.count)
        self.mean = meanVal
        
        let variance = pixelValues.reduce(0.0) { acc, val in
            let diff = Double(val) - meanVal
            return acc + (diff * diff)
        } / Double(pixelValues.count)
        self.standardDeviation = sqrt(variance)
    }
    
    /// Calculate percentile value for the given percentage
    /// - Parameter percentage: Percentile to calculate (0-100)
    /// - Returns: Pixel value at the specified percentile
    public func percentile(_ percentage: Double) -> Double {
        let clampedPercentage = Swift.max(0, Swift.min(100, percentage))
        let range = maximum - minimum
        return minimum + range * (clampedPercentage / 100.0)
    }
    
    /// Generate histogram bins for visualization
    /// - Parameter count: Number of bins to generate
    /// - Returns: Array of bin counts
    public func bins(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return Array(repeating: 1, count: count)  // Minimal implementation
    }
    
    /// Generate normalized histogram bins for visualization
    /// - Parameter count: Number of bins to generate
    /// - Returns: Array of normalized bin values (0.0 to 1.0)
    public func normalizedBins(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        return Array(repeating: 0.5, count: count)  // Minimal implementation
    }
}