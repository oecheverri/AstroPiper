import SwiftUI
import AstroPiperCore
import Combine

/// View model for FITS image viewer with scientific analysis capabilities
/// 
/// Manages state and business logic for FITS astronomical image viewing including:
/// - Image loading and processing
/// - Coordinate transformations and WCS calculations
/// - Scientific analysis and statistics
/// - Region selection and measurement
/// - Export and data management
@MainActor
public final class FITSImageViewerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current FITS image being viewed
    @Published public var image: (any AstroImage)?
    
    /// FITS-specific metadata
    @Published public private(set) var fitsMetadata: FITSImageMetadata?
    
    /// Whether image has WCS coordinate information
    @Published public private(set) var hasWCSInfo: Bool = false
    
    /// Current viewing state
    @Published public var viewState: ViewState = .idle
    
    /// UI overlay visibility states
    @Published public var showMetadataOverlay: Bool = false
    @Published public var showCoordinateOverlay: Bool = true
    @Published public var showScientificControls: Bool = false
    
    /// Current cursor position for coordinate tracking
    @Published public var cursorPosition: CGPoint = .zero
    @Published public var isCursorActive: Bool = false
    
    /// Selected analysis region
    @Published public var selectedRegion: PixelRegion?
    
    /// Region analysis results
    @Published public private(set) var regionStatistics: RegionStatistics?
    
    /// Analysis state
    @Published public private(set) var isAnalyzing: Bool = false
    
    /// Current world coordinates at cursor (when available)
    @Published public private(set) var currentWorldCoordinates: (ra: Double?, dec: Double?) = (nil, nil)
    
    /// Current pixel value at cursor
    @Published public private(set) var currentPixelValue: Double?
    
    /// Display mode for pixel values
    @Published public var showRawPixelValues: Bool = false
    
    /// Error states
    @Published public private(set) var loadingError: Error?
    @Published public private(set) var analysisError: Error?
    
    // MARK: - View State
    
    public enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case failed(Error)
        
        public static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let coordinateCalculator: CoordinateCalculatorProtocol
    private let statisticsCalculator: StatisticsCalculatorProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize FITS image viewer model
    /// - Parameters:
    ///   - coordinateCalculator: Service for coordinate calculations
    ///   - statisticsCalculator: Service for statistical analysis
    public init(
        coordinateCalculator: CoordinateCalculatorProtocol = CoordinateCalculator(),
        statisticsCalculator: StatisticsCalculatorProtocol = StatisticsCalculator()
    ) {
        self.coordinateCalculator = coordinateCalculator
        self.statisticsCalculator = statisticsCalculator
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Load a FITS image for viewing
    /// - Parameter image: The AstroImage to display
    public func loadImage(_ image: any AstroImage) {
        self.image = image
        viewState = .loading
        loadingError = nil
        
        Task {
            await processImage(image)
        }
    }
    
    /// Toggle metadata overlay visibility
    public func toggleMetadataOverlay() {
        showMetadataOverlay.toggle()
    }
    
    /// Toggle coordinate overlay visibility
    public func toggleCoordinateOverlay() {
        showCoordinateOverlay.toggle()
    }
    
    /// Toggle scientific controls visibility
    public func toggleScientificControls() {
        showScientificControls.toggle()
    }
    
    /// Update cursor position and calculate coordinates
    /// - Parameters:
    ///   - position: Cursor position in view coordinates
    ///   - isActive: Whether cursor is actively over the image
    public func updateCursorPosition(_ position: CGPoint, isActive: Bool) {
        cursorPosition = position
        isCursorActive = isActive
        
        if isActive {
            calculateCurrentCoordinates(at: position)
        } else {
            currentWorldCoordinates = (nil, nil)
            currentPixelValue = nil
        }
    }
    
    /// Set region for scientific analysis
    /// - Parameter region: Pixel region to analyze
    public func selectAnalysisRegion(_ region: PixelRegion) {
        selectedRegion = region
        Task {
            await calculateRegionStatistics()
        }
    }
    
    /// Toggle between raw and calibrated pixel value display
    public func togglePixelValueDisplay() {
        showRawPixelValues.toggle()
        
        // Recalculate current pixel value with new mode
        if isCursorActive {
            calculateCurrentCoordinates(at: cursorPosition)
        }
    }
    
    /// Export current analysis data
    /// - Parameter format: Export format
    public func exportAnalysisData(format: ExportFormat = .csv) async throws {
        guard let stats = regionStatistics else {
            throw FITSViewerError.noDataToExport
        }
        
        let exportData = generateExportData(stats: stats, format: format)
        
        // Copy to clipboard for now - in real implementation would save to file
        await copyToClipboard(exportData)
    }
    
    /// Reset all analysis and overlays
    public func resetView() {
        selectedRegion = nil
        regionStatistics = nil
        showMetadataOverlay = false
        showScientificControls = false
        analysisError = nil
        currentWorldCoordinates = (nil, nil)
        currentPixelValue = nil
    }
    
    // MARK: - Private Methods
    
    /// Setup reactive bindings
    private func setupBindings() {
        // Reset region statistics when region changes
        $selectedRegion
            .sink { [weak self] _ in
                self?.regionStatistics = nil
                self?.analysisError = nil
            }
            .store(in: &cancellables)
    }
    
    /// Process loaded image and extract metadata
    private func processImage(_ image: any AstroImage) async {
        // Extract FITS metadata
        if let fits = image.metadata as? FITSImageMetadata {
            fitsMetadata = fits
            hasWCSInfo = fits.wcs != nil
        } else {
            fitsMetadata = nil
            hasWCSInfo = false
        }
        
        viewState = .loaded
    }
    
    /// Calculate coordinates and pixel value at cursor position
    private func calculateCurrentCoordinates(at position: CGPoint) {
        guard image != nil else { return }
        
        // Convert view coordinates to image pixel coordinates
        let imageCoords = convertToImageCoordinates(position)
        
        // Calculate world coordinates if WCS available
        if let wcs = fitsMetadata?.wcs {
            let worldCoords = coordinateCalculator.worldCoordinates(
                wcs: wcs,
                pixelX: imageCoords.x,
                pixelY: imageCoords.y
            )
            currentWorldCoordinates = worldCoords
        }
        
        // Get pixel value at position
        Task {
            currentPixelValue = await getPixelValue(at: imageCoords)
        }
    }
    
    /// Convert view coordinates to image pixel coordinates
    private func convertToImageCoordinates(_ viewPosition: CGPoint) -> (x: Double, y: Double) {
        // This would need proper view-to-image coordinate transformation
        // based on current zoom level and pan offset
        return (x: viewPosition.x, y: viewPosition.y)
    }
    
    /// Get pixel value at specified image coordinates
    private func getPixelValue(at coordinates: (x: Double, y: Double)) async -> Double? {
        guard let image = image,
              let fits = fitsMetadata else { return nil }
        
        do {
            // Extract single pixel region
            let region = PixelRegion(
                x: UInt32(max(0, coordinates.x)),
                y: UInt32(max(0, coordinates.y)),
                width: 1,
                height: 1
            )
            
            let pixelData = try await image.pixelData(in: region)
            
            // Extract value based on bit depth
            let rawValue = extractPixelValue(from: pixelData, bitpix: fits.bitpix)
            
            // Apply FITS scaling if needed
            if showRawPixelValues {
                return rawValue
            } else {
                return fits.physicalValue(from: rawValue)
            }
        } catch {
            return nil
        }
    }
    
    /// Extract pixel value from data based on bit depth
    private func extractPixelValue(from data: Data, bitpix: Int) -> Double {
        guard !data.isEmpty else { return 0 }
        
        switch bitpix {
        case 8:
            return Double(data[0])
        case 16:
            return data.withUnsafeBytes { bytes in
                Double(Int16(bytes.load(as: Int16.self)))
            }
        case 32:
            return data.withUnsafeBytes { bytes in
                Double(Int32(bytes.load(as: Int32.self)))
            }
        case -32:
            return data.withUnsafeBytes { bytes in
                Double(Float(bytes.load(as: Float.self)))
            }
        case -64:
            return data.withUnsafeBytes { bytes in
                Double(bytes.load(as: Double.self))
            }
        default:
            return 0
        }
    }
    
    /// Calculate statistics for selected region
    private func calculateRegionStatistics() async {
        guard let region = selectedRegion,
              let image = image else { return }
        
        isAnalyzing = true
        analysisError = nil
        
        do {
            let calculator = statisticsCalculator
            let stats = try await calculator.calculateStatistics(
                for: region,
                in: image,
                useRawValues: showRawPixelValues
            )
            regionStatistics = stats
        } catch {
            analysisError = error
        }
        
        isAnalyzing = false
    }
    
    /// Generate export data string
    private func generateExportData(stats: RegionStatistics, format: ExportFormat) -> String {
        switch format {
        case .csv:
            return """
            Statistic,Value
            Mean,\(stats.mean)
            Standard Deviation,\(stats.standardDeviation)
            Minimum,\(stats.minimum)
            Maximum,\(stats.maximum)
            Median,\(stats.median ?? 0)
            Pixel Count,\(stats.pixelCount ?? 0)
            Signal-to-Noise Ratio,\(stats.mean / stats.standardDeviation)
            """
        case .json:
            return """
            {
                "mean": \(stats.mean),
                "standardDeviation": \(stats.standardDeviation),
                "minimum": \(stats.minimum),
                "maximum": \(stats.maximum),
                "median": \(stats.median ?? 0),
                "pixelCount": \(stats.pixelCount ?? 0),
                "snr": \(stats.mean / stats.standardDeviation)
            }
            """
        }
    }
    
    /// Copy text to system clipboard
    private func copyToClipboard(_ text: String) async {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Supporting Types

/// Export format options
public enum ExportFormat {
    case csv
    case json
}

/// FITS viewer specific errors
public enum FITSViewerError: Error, LocalizedError {
    case noDataToExport
    case coordinateCalculationFailed
    case invalidImageData
    
    public var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "No analysis data available for export"
        case .coordinateCalculationFailed:
            return "Failed to calculate coordinates"
        case .invalidImageData:
            return "Image data is invalid or corrupted"
        }
    }
}

// MARK: - Service Protocols

/// Protocol for coordinate calculations
public protocol CoordinateCalculatorProtocol {
    func worldCoordinates(wcs: WCSInfo, pixelX: Double, pixelY: Double) -> (ra: Double?, dec: Double?)
}

/// Protocol for statistical calculations
public protocol StatisticsCalculatorProtocol {
    func calculateStatistics(
        for region: PixelRegion,
        in image: any AstroImage,
        useRawValues: Bool
    ) async throws -> RegionStatistics
}

// MARK: - Default Implementations

/// Default coordinate calculator implementation
public struct CoordinateCalculator: CoordinateCalculatorProtocol {
    public init() {}
    
    public func worldCoordinates(wcs: WCSInfo, pixelX: Double, pixelY: Double) -> (ra: Double?, dec: Double?) {
        let coords = wcs.worldCoordinates(for: pixelX, y: pixelY)
        return (ra: coords.longitude, dec: coords.latitude)
    }
}

/// Default statistics calculator implementation
public struct StatisticsCalculator: StatisticsCalculatorProtocol {
    public init() {}
    
    public func calculateStatistics(
        for region: PixelRegion,
        in image: any AstroImage,
        useRawValues: Bool
    ) async throws -> RegionStatistics {
        
        // Extract pixel data for the region
        let pixelData = try await image.pixelData(in: region)
        
        // Convert to double array based on image format
        let values = try extractValues(from: pixelData, image: image, useRawValues: useRawValues)
        
        // Calculate statistics
        let mean = values.mean
        let stdDev = values.standardDeviation
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let median = values.median
        
        return RegionStatistics(
            mean: mean,
            standardDeviation: stdDev,
            minimum: min,
            maximum: max,
            median: median,
            pixelCount: values.count
        )
    }
    
    private func extractValues(from data: Data, image: any AstroImage, useRawValues: Bool) throws -> [Double] {
        guard let fits = image.metadata as? FITSImageMetadata else {
            throw FITSViewerError.invalidImageData
        }
        
        var values: [Double] = []
        
        switch fits.bitpix {
        case 8:
            for byte in data {
                let rawValue = Double(byte)
                let value = useRawValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(value)
            }
        case 16:
            for i in stride(from: 0, to: data.count, by: 2) {
                guard i + 1 < data.count else { break }
                let rawValue = data.withUnsafeBytes { bytes in
                    Double(Int16(bytes.load(fromByteOffset: i, as: Int16.self)))
                }
                let value = useRawValues ? rawValue : fits.physicalValue(from: rawValue)
                values.append(value)
            }
        default:
            throw FITSViewerError.invalidImageData
        }
        
        return values
    }
}

// MARK: - Array Extensions

private extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let mean = self.mean
        let squaredDiffs = map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.reduce(0, +) / Double(count - 1))
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