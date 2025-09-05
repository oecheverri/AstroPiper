import Testing
import SwiftUI
import Foundation
@testable import AstroPiper
@testable import AstroPiperCore

@MainActor
struct FITSImageViewerTests {
    
    // MARK: - Basic FITS Viewer Tests
    
    @Test func fitsImageViewerInitializesWithFITSImage() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let viewer = FITSImageViewer(image: testImage)
        
        #expect(viewer.image != nil)
        #expect(viewer.fitsMetadata != nil)
    }
    
    @Test func fitsImageViewerDetectsWCSCapability() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImageWithWCS()
        let viewer = FITSImageViewer(image: testImage)
        
        #expect(viewer.hasWCSInfo == true)
    }
    
    @Test func fitsImageViewerShowsMetadataOverlay() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let viewer = FITSImageViewer(image: testImage)
        
        #expect(viewer.showMetadataOverlay == false) // Default state
        
        // Test toggling
        viewer.toggleMetadataOverlay()
        #expect(viewer.showMetadataOverlay == true)
    }
    
    // MARK: - Coordinate System Tests
    
    @Test func coordinateOverlayTracksMousePosition() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImageWithWCS()
        let overlay = CoordinateOverlay(
            wcsInfo: testImage.fitsMetadata.wcs!,
            imageSize: CGSize(width: 1000, height: 1000)
        )
        
        // Test coordinate conversion
        let worldCoords = overlay.worldCoordinates(for: CGPoint(x: 500, y: 500))
        #expect(worldCoords.ra != nil)
        #expect(worldCoords.dec != nil)
    }
    
    @Test func coordinateOverlayDisplaysPixelValues() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let overlay = CoordinateOverlay(
            wcsInfo: nil,
            imageSize: CGSize(width: 1000, height: 1000)
        )
        
        let pixelCoords = overlay.pixelCoordinates(for: CGPoint(x: 100, y: 200))
        #expect(pixelCoords.x == 100)
        #expect(pixelCoords.y == 200)
    }
    
    // MARK: - Metadata Inspector Tests
    
    @Test func metadataInspectorShowsObservatoryTab() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let inspector = MetadataInspector(metadata: testImage.fitsMetadata)
        
        #expect(inspector.availableTabs.contains(.observatory))
        #expect(inspector.selectedTab == .observatory) // Default
    }
    
    @Test func metadataInspectorShowsWCSTabWhenAvailable() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImageWithWCS()
        let inspector = MetadataInspector(metadata: testImage.fitsMetadata)
        
        #expect(inspector.availableTabs.contains(.wcs))
    }
    
    @Test func metadataInspectorFiltersHeaders() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let inspector = MetadataInspector(metadata: testImage.fitsMetadata)
        
        inspector.headerSearchText = "TELESCOP"
        let filteredHeaders = inspector.filteredHeaders
        
        #expect(filteredHeaders.count <= testImage.fitsMetadata.fitsHeaders.count)
        #expect(filteredHeaders.allSatisfy { $0.key.contains("TELESCOP") })
    }
    
    // MARK: - Scientific Controls Tests
    
    @Test func scientificControlsCalculatesRegionStatistics() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let controls = ScientificControls(image: testImage)
        
        let region = PixelRegion(x: 100, y: 100, width: 200, height: 200)
        let stats = try await controls.calculateRegionStatistics(region: region)
        
        #expect(stats.mean >= 0)
        #expect(stats.standardDeviation >= 0)
        #expect(stats.minimum <= stats.maximum)
    }
    
    @Test func scientificControlsTogglesPixelValueDisplay() async throws {
        let testImage = try MockFITSImageProvider.createMockFITSImage()
        let controls = ScientificControls(image: testImage)
        
        #expect(controls.showRawPixelValues == false) // Default shows calibrated
        
        controls.togglePixelValueDisplay()
        #expect(controls.showRawPixelValues == true)
    }
}

// MARK: - Test Utilities

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
            object: "NGC1234",
            exptime: 300.0,
            filter: "Luminance"
        )
        
        // Create mock pixel data (16-bit signed integers)
        let pixelCount = 1000 * 1000
        var pixelData = Data(capacity: pixelCount * 2)
        
        for _ in 0..<pixelCount {
            let value = Int16.random(in: -32768...32767)
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
            pixelScale: PixelScale(x: -0.001, y: 0.001), // 3.6 arcsec/pixel
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
            object: "NGC1234",
            exptime: 300.0,
            filter: "Luminance",
            wcs: wcsInfo
        )
        
        // Create mock pixel data
        let pixelCount = 1000 * 1000
        var pixelData = Data(capacity: pixelCount * 2)
        
        for _ in 0..<pixelCount {
            let value = Int16.random(in: -32768...32767)
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
        // For testing, return RGB data (3 bytes per pixel)
        let width = Int(fitsMetadata.dimensions.width)
        let height = Int(fitsMetadata.dimensions.height)
        let totalPixels = width * height * 3
        return Data(repeating: 128, count: totalPixels)
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