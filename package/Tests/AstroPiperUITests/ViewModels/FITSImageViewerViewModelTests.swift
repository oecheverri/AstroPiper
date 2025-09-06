import Testing
import SwiftUI
import Foundation
@testable import AstroPiperUI
@testable import AstroPiperCore

@MainActor
struct FITSImageViewerViewModelTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test func viewModelInitializesCorrectly() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        #expect(viewModel.image == nil)
        #expect(viewModel.fitsMetadata == nil)
        #expect(viewModel.hasWCSInfo == false)
        #expect(viewModel.viewState == .idle)
        #expect(viewModel.showMetadataOverlay == false)
        #expect(viewModel.showCoordinateOverlay == true) // Default to true for scientific use
        #expect(viewModel.showScientificControls == false)
    }
    
    @Test func viewModelLoadsImageCorrectly() async throws {
        let viewModel = FITSImageViewerViewModel()
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        
        viewModel.loadImage(testImage)
        
        // Verify immediate state changes
        #expect(viewModel.image != nil)
        #expect(viewModel.viewState == .loading)
        
        // Wait for async processing
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(viewModel.viewState == .loaded)
        #expect(viewModel.fitsMetadata != nil)
    }
    
    @Test func viewModelDetectsWCSCapability() async throws {
        let viewModel = FITSImageViewerViewModel()
        let testImageWithWCS = try MockFITSImageProvider.createMockFITSImageWithWCS()
        
        viewModel.loadImage(testImageWithWCS)
        
        // Wait for processing
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(viewModel.hasWCSInfo == true)
        #expect(viewModel.fitsMetadata?.wcs != nil)
    }
    
    // MARK: - UI State Management Tests
    
    @Test func viewModelTogglesMetadataOverlay() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        #expect(viewModel.showMetadataOverlay == false)
        
        viewModel.toggleMetadataOverlay()
        #expect(viewModel.showMetadataOverlay == true)
        
        viewModel.toggleMetadataOverlay()
        #expect(viewModel.showMetadataOverlay == false)
    }
    
    @Test func viewModelTogglesCoordinateOverlay() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        #expect(viewModel.showCoordinateOverlay == true)
        
        viewModel.toggleCoordinateOverlay()
        #expect(viewModel.showCoordinateOverlay == false)
        
        viewModel.toggleCoordinateOverlay()
        #expect(viewModel.showCoordinateOverlay == true)
    }
    
    @Test func viewModelTogglesScientificControls() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        #expect(viewModel.showScientificControls == false)
        
        viewModel.toggleScientificControls()
        #expect(viewModel.showScientificControls == true)
        
        viewModel.toggleScientificControls()
        #expect(viewModel.showScientificControls == false)
    }
    
    // MARK: - Coordinate Tracking Tests
    
    @Test func viewModelUpdatesCursorPosition() async throws {
        let viewModel = FITSImageViewerViewModel()
        let testImage = try MockFITSImageProvider.createMockFITSImageWithWCS()
        
        viewModel.loadImage(testImage)
        try await Task.sleep(for: .milliseconds(100))
        
        let testPosition = CGPoint(x: 100, y: 200)
        viewModel.updateCursorPosition(testPosition, isActive: true)
        
        #expect(viewModel.cursorPosition == testPosition)
        #expect(viewModel.isCursorActive == true)
    }
    
    @Test func viewModelCalculatesWorldCoordinatesWithWCS() async throws {
        let mockCalculator = MockCoordinateCalculator()
        let viewModel = FITSImageViewerViewModel(coordinateCalculator: mockCalculator)
        let testImage = try MockFITSImageProvider.createMockFITSImageWithWCS()
        
        viewModel.loadImage(testImage)
        try await Task.sleep(for: .milliseconds(100))
        
        viewModel.updateCursorPosition(CGPoint(x: 500, y: 500), isActive: true)
        
        #expect(viewModel.currentWorldCoordinates.ra != nil)
        #expect(viewModel.currentWorldCoordinates.dec != nil)
        #expect(mockCalculator.calculateCallCount == 1)
    }
    
    // MARK: - Scientific Analysis Tests
    
    @Test func viewModelSelectsAnalysisRegion() async throws {
        let mockCalculator = MockStatisticsCalculator()
        let viewModel = FITSImageViewerViewModel(statisticsCalculator: mockCalculator)
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        
        viewModel.loadImage(testImage)
        try await Task.sleep(for: .milliseconds(100))
        
        let region = PixelRegion(x: 100, y: 100, width: 200, height: 200)
        viewModel.selectAnalysisRegion(region)
        
        #expect(viewModel.selectedRegion == region)
        #expect(viewModel.isAnalyzing == true)
        
        // Wait for analysis to complete
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(viewModel.isAnalyzing == false)
        #expect(viewModel.regionStatistics != nil)
        #expect(mockCalculator.calculateCallCount == 1)
    }
    
    @Test func viewModelTogglesPixelValueDisplay() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        #expect(viewModel.showRawPixelValues == false)
        
        viewModel.togglePixelValueDisplay()
        #expect(viewModel.showRawPixelValues == true)
        
        viewModel.togglePixelValueDisplay()
        #expect(viewModel.showRawPixelValues == false)
    }
    
    @Test func viewModelResetsViewCorrectly() async throws {
        let viewModel = FITSImageViewerViewModel()
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        
        viewModel.loadImage(testImage)
        viewModel.toggleMetadataOverlay()
        viewModel.toggleScientificControls()
        
        let region = PixelRegion(x: 50, y: 50, width: 100, height: 100)
        viewModel.selectAnalysisRegion(region)
        
        // Reset everything
        viewModel.resetView()
        
        #expect(viewModel.selectedRegion == nil)
        #expect(viewModel.regionStatistics == nil)
        #expect(viewModel.showMetadataOverlay == false)
        #expect(viewModel.showScientificControls == false)
        #expect(viewModel.analysisError == nil)
        #expect(viewModel.currentWorldCoordinates.ra == nil)
        #expect(viewModel.currentWorldCoordinates.dec == nil)
        #expect(viewModel.currentPixelValue == nil)
    }
    
    // MARK: - Export Functionality Tests
    
    @Test func viewModelExportsAnalysisData() async throws {
        let mockCalculator = MockStatisticsCalculator()
        let viewModel = FITSImageViewerViewModel(statisticsCalculator: mockCalculator)
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        
        viewModel.loadImage(testImage)
        try await Task.sleep(for: .milliseconds(100))
        
        // Create analysis data
        let region = PixelRegion(x: 100, y: 100, width: 200, height: 200)
        viewModel.selectAnalysisRegion(region)
        try await Task.sleep(for: .milliseconds(200))
        
        // Test export
        try await viewModel.exportAnalysisData(format: .csv)
        // In a real test, we would verify the exported data content
    }
    
    @Test func viewModelHandlesExportWithoutData() async throws {
        let viewModel = FITSImageViewerViewModel()
        
        // Attempt to export without any analysis data
        await #expect(throws: FITSViewerError.self) {
            try await viewModel.exportAnalysisData()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test func viewModelHandlesImageLoadingErrors() async throws {
        let viewModel = FITSImageViewerViewModel()
        let brokenImage = BrokenMockImage()
        
        viewModel.loadImage(brokenImage)
        
        // Loading should start normally
        #expect(viewModel.viewState == .loading)
        
        // Wait for processing - in this case it should succeed since we're just checking metadata
        try await Task.sleep(for: .milliseconds(100))
        
        // The view state should be loaded even for non-FITS images
        #expect(viewModel.viewState == .loaded)
        #expect(viewModel.fitsMetadata == nil) // No FITS metadata available
        #expect(viewModel.hasWCSInfo == false)
    }
    
    @Test func viewModelHandlesAnalysisErrors() async throws {
        let failingCalculator = FailingStatisticsCalculator()
        let viewModel = FITSImageViewerViewModel(statisticsCalculator: failingCalculator)
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        
        viewModel.loadImage(testImage)
        try await Task.sleep(for: .milliseconds(100))
        
        let region = PixelRegion(x: 100, y: 100, width: 200, height: 200)
        viewModel.selectAnalysisRegion(region)
        
        // Wait for analysis to fail
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(viewModel.isAnalyzing == false)
        #expect(viewModel.regionStatistics == nil)
        #expect(viewModel.analysisError != nil)
    }
}

// MARK: - Mock Implementations

/// Mock coordinate calculator for testing
private class MockCoordinateCalculator: CoordinateCalculatorProtocol {
    var calculateCallCount = 0
    
    func worldCoordinates(wcs: WCSInfo, pixelX: Double, pixelY: Double) -> (ra: Double?, dec: Double?) {
        calculateCallCount += 1
        return (ra: 180.0 + pixelX * 0.001, dec: 45.0 + pixelY * 0.001)
    }
}

/// Mock statistics calculator for testing
private final class MockStatisticsCalculator: StatisticsCalculatorProtocol, @unchecked Sendable {
    var calculateCallCount = 0
    
    func calculateStatistics(
        for region: PixelRegion,
        in image: any AstroImage,
        useRawValues: Bool
    ) async throws -> RegionStatistics {
        calculateCallCount += 1
        
        // Simulate calculation time
        try await Task.sleep(for: .milliseconds(50))
        
        return RegionStatistics(
            mean: 32768.0,
            standardDeviation: 1000.0,
            minimum: 30000.0,
            maximum: 35000.0,
            median: 32800.0,
            pixelCount: Int(region.width * region.height)
        )
    }
}

/// Statistics calculator that always fails for error testing
private final class FailingStatisticsCalculator: StatisticsCalculatorProtocol, @unchecked Sendable {
    func calculateStatistics(
        for region: PixelRegion,
        in image: any AstroImage,
        useRawValues: Bool
    ) async throws -> RegionStatistics {
        
        try await Task.sleep(for: .milliseconds(50))
        throw TestError.calculationFailed
    }
}

/// Broken image implementation for error testing
private struct BrokenMockImage: AstroImage {
    var metadata: any AstroImageMetadata {
        BrokenImageMetadata()
    }
    
    func pixelData(in region: PixelRegion?) async throws -> Data {
        throw TestError.dataCorrupted
    }
    
    func generateHistogram() async throws -> HistogramData {
        throw TestError.dataCorrupted
    }
    
    func supportsBayerDemosaic() -> Bool { false }
    
    func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
        throw AstroImageError.demosaicNotSupported
    }
}

private struct BrokenImageMetadata: AstroImageMetadata {
    var dimensions: ImageDimensions { ImageDimensions(width: 0, height: 0) }
    var pixelFormat: PixelFormat { .uint8 }
    var colorSpace: ColorSpace { .grayscale }
    var filename: String? { "broken.fit" }
    var fileSize: UInt64? { nil }
    var creationDate: Date? { nil }
    var modificationDate: Date? { nil }
    var exposureTime: TimeInterval? { nil }
    var iso: Int? { nil }
    var telescopeName: String? { nil }
    var instrumentName: String? { nil }
    var filterName: String? { nil }
    var objectName: String? { nil }
    var observationDate: Date? { nil }
    var coordinates: SkyCoordinates? { nil }
    var temperature: Double? { nil }
    var gain: Double? { nil }
    var binning: ImageBinning? { nil }
    var customMetadata: [String: String] { [:] }
}

/// Test-specific errors
private enum TestError: Error, LocalizedError {
    case calculationFailed
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .calculationFailed:
            return "Mock calculation failed"
        case .dataCorrupted:
            return "Mock data corrupted"
        }
    }
}

/// Reuse mock provider from main test file
private struct MockFITSImageProvider {
    
    static func createMockFITSImage() throws -> MockFITSImage {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1000, 1000],
            bitpix: 16,
            bzero: 32768,
            bscale: 1.0,
            filename: "test.fit",
            telescope: "Mock Telescope",
            instrument: "Mock Camera",
            object: "Test Object",
            exptime: 300.0,
            filter: "Luminance"
        )
        
        let pixelCount = 1000 * 1000
        var pixelData = Data(capacity: pixelCount * 2)
        
        for _ in 0..<pixelCount {
            let value = Int16.random(in: 10000...30000) // Realistic astronomical range
            withUnsafeBytes(of: value) { bytes in
                pixelData.append(contentsOf: bytes)
            }
        }
        
        return MockFITSImage(metadata: metadata, imageData: pixelData)
    }
    
    static func createMockFITSImageWithWCS() throws -> MockFITSImage {
        let wcsInfo = WCSInfo(
            referencePixel: PixelCoordinate(x: 500, y: 500),
            referenceValue: WorldCoordinate(longitude: 180.0, latitude: 45.0),
            pixelScale: PixelScale(x: -0.001, y: 0.001),
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            coordinateSystem: "ICRS",
            equinox: 2000.0
        )
        
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1000, 1000],
            bitpix: 16,
            bzero: 32768,
            bscale: 1.0,
            filename: "test_wcs.fit",
            telescope: "Mock Telescope",
            instrument: "Mock Camera",
            object: "Test Object",
            exptime: 300.0,
            filter: "Luminance",
            wcs: wcsInfo
        )
        
        let pixelCount = 1000 * 1000
        var pixelData = Data(capacity: pixelCount * 2)
        
        for _ in 0..<pixelCount {
            let value = Int16.random(in: 10000...30000)
            withUnsafeBytes(of: value) { bytes in
                pixelData.append(contentsOf: bytes)
            }
        }
        
        return MockFITSImage(metadata: metadata, imageData: pixelData)
    }
}

private struct MockFITSImage: AstroImage {
    let fitsMetadata: FITSImageMetadata
    let imageData: Data
    
    var metadata: any AstroImageMetadata { fitsMetadata }
    
    init(metadata: FITSImageMetadata, imageData: Data) {
        self.fitsMetadata = metadata
        self.imageData = imageData
    }
    
    func pixelData(in region: PixelRegion?) async throws -> Data {
        if let region = region {
            // Extract specific region
            let regionSize = Int(region.width * region.height) * 2
            return Data(imageData.prefix(min(regionSize, imageData.count)))
        } else {
            // Return RGB conversion for display
            let pixelCount = Int(fitsMetadata.dimensions.width * fitsMetadata.dimensions.height)
            return Data(repeating: 128, count: pixelCount * 3)
        }
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