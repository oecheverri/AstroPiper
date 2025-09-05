import SwiftUI
import AstroPiperCore

/// Scientific analysis controls for astronomical images
/// 
/// Provides professional tools for quantitative image analysis including:
/// - Region-based statistics (mean, std dev, min, max, median)  
/// - Raw vs. calibrated pixel value display modes
/// - Pixel value inspection at cursor position
/// - Region selection and measurement tools
/// - Data export capabilities for further analysis
@MainActor
public struct ScientificControls: View {
    
    // MARK: - Properties
    
    /// The astronomical image for analysis
    public let image: any AstroImage
    
    /// Whether to show raw or calibrated pixel values
    @State public var showRawPixelValues: Bool = false
    
    /// Currently selected analysis region
    @State private var selectedRegion: PixelRegion?
    
    /// Statistics for the selected region
    @State private var regionStatistics: RegionStatistics?
    
    /// Whether statistics calculation is in progress
    @State private var isCalculatingStats: Bool = false
    
    /// Error state for analysis operations
    @State private var analysisError: Error?
    
    /// Whether to show detailed statistics panel
    @State private var showDetailedStats: Bool = false
    
    /// Current pixel value at cursor (for real-time display)
    @State private var currentPixelValue: Double?
    
    // MARK: - Computed Properties
    
    private var fitsMetadata: FITSImageMetadata? {
        image.metadata as? FITSImageMetadata
    }
    
    private var supportsRawValues: Bool {
        fitsMetadata?.bzero != nil || fitsMetadata?.bscale != nil
    }
    
    // MARK: - Initialization
    
    /// Initialize scientific controls
    /// - Parameter image: The astronomical image to analyze
    public init(image: any AstroImage) {
        self.image = image
    }
    
    // MARK: - View Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Control header
            controlHeader
            
            // Main control panels
            HStack(alignment: .top, spacing: 16) {
                // Left panel - Display controls
                VStack(alignment: .leading, spacing: 12) {
                    displayControls
                    
                    if let stats = regionStatistics {
                        statisticsPanel(stats)
                    }
                }
                .frame(maxWidth: 200)
                
                // Right panel - Region tools
                VStack(alignment: .leading, spacing: 12) {
                    regionTools
                    
                    if showDetailedStats, let stats = regionStatistics {
                        detailedStatisticsPanel(stats)
                    }
                }
                .frame(maxWidth: 200)
            }
            
            // Error display
            if let error = analysisError {
                errorPanel(error)
            }
        }
        .padding()
        .frame(maxWidth: 420, maxHeight: 300)
    }
    
    // MARK: - Control Header
    
    @ViewBuilder
    private var controlHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Scientific Analysis")
                    .font(.headline)
            }
            
            Spacer()
            
            Button {
                showDetailedStats.toggle()
            } label: {
                Image(systemName: showDetailedStats ? "chevron.down" : "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - Display Controls
    
    @ViewBuilder
    private var displayControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Mode")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if supportsRawValues {
                Button {
                    togglePixelValueDisplay()
                } label: {
                    HStack {
                        Image(systemName: showRawPixelValues ? "checkmark.square" : "square")
                        Text("Show Raw Values")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)
            }
            
            // Current pixel value display
            if let pixelValue = currentPixelValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showRawPixelValues ? "Raw Pixel Value:" : "Calibrated Value:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatPixelValue(pixelValue))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    
    // MARK: - Region Tools
    
    @ViewBuilder
    private var regionTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Region")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let region = selectedRegion {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Region: \(Int(region.x)), \(Int(region.y))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Size: \(Int(region.width)) × \(Int(region.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        Task {
                            await calculateStatistics(for: region)
                        }
                    } label: {
                        if isCalculatingStats {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Calculating...")
                            }
                        } else {
                            Text("Update Statistics")
                        }
                    }
                    .font(.caption)
                    .disabled(isCalculatingStats)
                }
                .padding(8)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("Select a region on the image to begin analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    // MARK: - Statistics Panels
    
    @ViewBuilder
    private func statisticsPanel(_ stats: RegionStatistics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Region Statistics")
                .font(.subheadline)
                .fontWeight(.medium)
            
            statisticRow("Mean:", stats.mean)
            statisticRow("Std Dev:", stats.standardDeviation)
            statisticRow("Min:", stats.minimum)
            statisticRow("Max:", stats.maximum)
        }
        .padding(8)
        .background(.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private func detailedStatisticsPanel(_ stats: RegionStatistics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Detailed Analysis")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let median = stats.median {
                statisticRow("Median:", median)
            }
            
            statisticRow("Range:", stats.maximum - stats.minimum)
            statisticRow("SNR:", stats.mean / stats.standardDeviation)
            
            if let count = stats.pixelCount {
                Text("Pixel Count: \(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Export button
            Button {
                exportStatistics(stats)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private func statisticRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            Text(formatStatisticValue(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func errorPanel(_ error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("Analysis Error")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                analysisError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Public Methods
    
    /// Toggle between raw and calibrated pixel value display
    public func togglePixelValueDisplay() {
        showRawPixelValues.toggle()
    }
    
    /// Set the analysis region and calculate statistics
    /// - Parameter region: Pixel region to analyze
    public func setAnalysisRegion(_ region: PixelRegion) {
        selectedRegion = region
        Task {
            await calculateStatistics(for: region)
        }
    }
    
    /// Calculate statistics for the given region
    /// - Parameter region: Pixel region to analyze
    /// - Returns: Statistical analysis results
    public func calculateRegionStatistics(region: PixelRegion) async throws -> RegionStatistics {
        isCalculatingStats = true
        analysisError = nil
        
        do {
            // Extract pixel data for the region
            let pixelData = try await image.pixelData(in: region)
            
            // Convert to values for analysis
            let values = try extractPixelValues(from: pixelData, region: region)
            
            // Calculate statistics
            let stats = RegionStatistics(
                mean: values.mean,
                standardDeviation: values.standardDeviation,
                minimum: values.min() ?? 0,
                maximum: values.max() ?? 0,
                median: values.median,
                pixelCount: values.count
            )
            
            return stats
        } catch {
            analysisError = error
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Calculate statistics for the specified region
    private func calculateStatistics(for region: PixelRegion) async {
        do {
            let stats = try await calculateRegionStatistics(region: region)
            regionStatistics = stats
        } catch {
            analysisError = error
        }
        
        isCalculatingStats = false
    }
    
    /// Extract pixel values from raw data
    private func extractPixelValues(from data: Data, region: PixelRegion) throws -> [Double] {
        guard let fits = fitsMetadata else {
            throw ScientificAnalysisError.invalidImageFormat
        }
        
        var values: [Double] = []
        let regionSize = Int(region.width * region.height)
        
        // Extract values based on FITS bit depth
        switch fits.bitpix {
        case 8:
            for byte in data.prefix(regionSize) {
                let rawValue = Double(byte)
                let physicalValue = showRawPixelValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(physicalValue)
            }
            
        case 16:
            for i in stride(from: 0, to: min(data.count, regionSize * 2), by: 2) {
                let rawValue = data.withUnsafeBytes { bytes in
                    Double(Int16(bytes.load(fromByteOffset: i, as: Int16.self)))
                }
                let physicalValue = showRawPixelValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(physicalValue)
            }
            
        case 32:
            for i in stride(from: 0, to: min(data.count, regionSize * 4), by: 4) {
                let rawValue = data.withUnsafeBytes { bytes in
                    Double(Int32(bytes.load(fromByteOffset: i, as: Int32.self)))
                }
                let physicalValue = showRawPixelValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(physicalValue)
            }
            
        case -32:
            for i in stride(from: 0, to: min(data.count, regionSize * 4), by: 4) {
                let rawValue = data.withUnsafeBytes { bytes in
                    Double(Float(bytes.load(fromByteOffset: i, as: Float.self)))
                }
                let physicalValue = showRawPixelValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(physicalValue)
            }
            
        default:
            throw ScientificAnalysisError.unsupportedBitDepth(fits.bitpix)
        }
        
        return values
    }
    
    /// Format pixel value for display
    private func formatPixelValue(_ value: Double) -> String {
        if let fits = fitsMetadata {
            switch fits.bitpix {
            case -32, -64:
                return String(format: "%.6f", value)
            default:
                return String(format: "%.0f", value)
            }
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    /// Format statistic value for display
    private func formatStatisticValue(_ value: Double) -> String {
        if abs(value) < 0.001 || abs(value) > 99999 {
            return String(format: "%.2e", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    /// Export statistics data
    private func exportStatistics(_ stats: RegionStatistics) {
        // Implementation would export to CSV or similar format
        // For now, copy to clipboard
        let exportData = """
        Region Statistics Export
        Mean: \(stats.mean)
        Standard Deviation: \(stats.standardDeviation)
        Minimum: \(stats.minimum)
        Maximum: \(stats.maximum)
        Median: \(stats.median ?? 0)
        Pixel Count: \(stats.pixelCount ?? 0)
        Signal-to-Noise Ratio: \(stats.mean / stats.standardDeviation)
        """
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportData, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = exportData
        #endif
    }
}

// MARK: - Supporting Types

/// Statistical analysis results for a pixel region
public struct RegionStatistics: Sendable {
    public let mean: Double
    public let standardDeviation: Double
    public let minimum: Double
    public let maximum: Double
    public let median: Double?
    public let pixelCount: Int?
    
    public init(
        mean: Double,
        standardDeviation: Double,
        minimum: Double,
        maximum: Double,
        median: Double? = nil,
        pixelCount: Int? = nil
    ) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.minimum = minimum
        self.maximum = maximum
        self.median = median
        self.pixelCount = pixelCount
    }
}

/// Errors related to scientific analysis
public enum ScientificAnalysisError: Error, LocalizedError {
    case invalidImageFormat
    case unsupportedBitDepth(Int)
    case regionOutOfBounds
    case calculationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Image format not suitable for scientific analysis"
        case .unsupportedBitDepth(let bitpix):
            return "Unsupported bit depth: \(bitpix)"
        case .regionOutOfBounds:
            return "Selected region is outside image bounds"
        case .calculationFailed(let details):
            return "Calculation failed: \(details)"
        }
    }
}

// MARK: - Array Extensions

private extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        let mean = self.mean
        let squaredDiffs = map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.mean)
    }
    
    var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
}

// MARK: - Preview Support

#Preview("Scientific Controls") {
    let mockMetadata = FITSImageMetadata(
        naxis: 2,
        axisSizes: [1000, 1000],
        bitpix: 16,
        bzero: 32768,
        bscale: 1.0,
        filename: "test.fit"
    )
    
    let mockImage = PreviewScientificImage(metadata: mockMetadata)
    
    return ScientificControls(image: mockImage)
        .preferredColorScheme(.dark)
        .padding()
}

private struct PreviewScientificImage: AstroImage {
    let fitsMetadata: FITSImageMetadata
    
    var metadata: any AstroImageMetadata { fitsMetadata }
    
    init(metadata: FITSImageMetadata) {
        self.fitsMetadata = metadata
    }
    
    func pixelData(in region: PixelRegion?) async throws -> Data {
        // Generate preview data with realistic values
        let count = region?.width ?? fitsMetadata.dimensions.width
        let height = region?.height ?? fitsMetadata.dimensions.height
        let totalPixels = Int(count * height) * 2 // 16-bit data
        
        var data = Data(capacity: totalPixels)
        for _ in 0..<Int(count * height) {
            let value = Int16.random(in: 1000...30000) // Realistic astronomical data range
            withUnsafeBytes(of: value) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
    
    func generateHistogram() async throws -> HistogramData {
        let mockPixels = Array(repeating: UInt16(32768), count: Int(fitsMetadata.dimensions.width * fitsMetadata.dimensions.height))
        return HistogramData(pixelValues: mockPixels, bitDepth: 16)
    }
    
    func supportsBayerDemosaic() -> Bool { false }
    
    func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
        throw AstroImageError.demosaicNotSupported
    }
}