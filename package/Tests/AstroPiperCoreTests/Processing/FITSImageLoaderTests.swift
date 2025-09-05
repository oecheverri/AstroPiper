import Testing
import Foundation
@testable import AstroPiperCore

struct FITSImageLoaderTests {
    
    // Path to real FITS test files
    private static let sampleFilesPath = "../Sample Files"
    private static let testFITSFile = "Light_IC2087_180.0s_Bin1_533MC_gain360_20221003-041814_-9.9C_0024.fit"
    
    @Test func fitsImageLoaderParsesRealFITSFile() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        // Skip if test file doesn't exist
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found: \(testURL.path)")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        #expect(image is FITSAstroImage)
        #expect(image.metadata is FITSImageMetadata)
        
        let fitsMetadata = image.metadata as! FITSImageMetadata
        #expect(fitsMetadata.naxis == 2)
        #expect(fitsMetadata.bitpix == 16)
        #expect(fitsMetadata.dimensions.width == 3008)
        #expect(fitsMetadata.dimensions.height == 3008)
    }
    
    @Test func fitsImageLoaderExtractsMetadataCorrectly() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let metadata = try await FITSImageLoader.parseMetadata(from: testURL)
        
        // Verify basic FITS properties
        #expect(metadata.naxis == 2)
        #expect(metadata.bitpix == 16)
        #expect(metadata.bzero == 32768.0)
        #expect(metadata.bscale == 1.0)
        
        // Verify image dimensions (3008x3008 from our sample file)
        #expect(metadata.dimensions.width == 3008)
        #expect(metadata.dimensions.height == 3008)
        #expect(metadata.totalPixels == 3008 * 3008)
        
        // Verify derived properties
        #expect(metadata.pixelFormat == .int16)
        #expect(metadata.colorSpace == .grayscale)
        #expect(metadata.bytesPerPixel == 2)
        #expect(metadata.isSignedInteger == true)
        #expect(metadata.isFloatingPoint == false)
    }
    
    @Test func fitsImageLoaderExtractsObservatoryMetadata() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let metadata = try await FITSImageLoader.parseMetadata(from: testURL)
        
        // Check for camera/instrument metadata from our sample files
        #expect(metadata.customValue(for: "CREATOR") == "ASIAIR PRO")
        #expect(metadata.customValue(for: "OFFSET") != nil)
        
        // Verify astronomical metadata interface
        #expect(metadata.filename?.hasSuffix(".fit") == true)
        #expect(metadata.fileSize != nil)
        #expect(metadata.customMetadata.count > 0)
    }
    
    @Test func fitsImageLoaderHandlesPhysicalValueTransformation() async throws {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 2.0,
            filename: "test.fits"
        )
        
        // Test BZERO/BSCALE transformation
        #expect(metadata.physicalValue(from: 0.0) == 32768.0)
        #expect(metadata.physicalValue(from: 1000.0) == 34768.0)  // 2.0 * 1000 + 32768
        #expect(metadata.physicalValue(from: -16384.0) == 0.0)    // 2.0 * -16384 + 32768
    }
    
    @Test func fitsAstroImageGeneratesPixelData() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        let pixelData = try await image.pixelData(in: nil)
        
        // Verify pixel data size (3008x3008 * 2 bytes per pixel)
        let expectedSize = 3008 * 3008 * 2
        #expect(pixelData.count == expectedSize)
        
        // Verify data is not all zeros (should contain actual image data)
        let nonZeroBytes = pixelData.prefix(1000).contains { $0 != 0 }
        #expect(nonZeroBytes == true)
    }
    
    @Test func fitsAstroImageGeneratesHistogram() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        let histogram = try await image.generateHistogram()
        
        #expect(histogram.bitDepth == 16)
        #expect(histogram.count > 0)
        #expect(histogram.minimum >= 0.0)
        #expect(histogram.maximum <= 65535.0)
        
        // Scientific images should have meaningful statistics
        #expect(histogram.mean > 0.0)
        #expect(histogram.standardDeviation > 0.0)
    }
    
    @Test func fitsAstroImageExtractsRegionData() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Extract a 100x100 region from the center
        let region = PixelRegion(x: 1454, y: 1454, width: 100, height: 100) // Center of 3008x3008
        let regionData = try await image.pixelData(in: region)
        
        // Verify region data size (100x100 * 2 bytes per pixel)
        #expect(regionData.count == 100 * 100 * 2)
        
        // Should contain actual image data
        let nonZeroBytes = regionData.contains { $0 != 0 }
        #expect(nonZeroBytes == true)
    }
    
    @Test func fitsAstroImageHandlesBoundsChecking() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Try to extract region outside bounds
        let outOfBoundsRegion = PixelRegion(x: 3000, y: 3000, width: 100, height: 100)
        
        await #expect(throws: AstroImageError.self) {
            let _ = try await image.pixelData(in: outOfBoundsRegion)
        }
    }
    
    @Test func fitsAstroImageDetectsBayerPattern() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Our sample files are likely monochrome, so should not support Bayer
        #expect(image.supportsBayerDemosaic() == false)
        
        // Attempting demosaic should throw error
        await #expect(throws: AstroImageError.self) {
            let _ = try await image.demosaicedImage(bayerPattern: .rggb)
        }
    }
    
    @Test func fitsImageLoaderHandlesCorruptedData() async {
        let corruptedData = Data(repeating: 0xFF, count: 1000)
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: corruptedData, fileName: "corrupt.fits")
        }
    }
    
    @Test func fitsImageLoaderValidatesRequiredKeywords() async {
        // Create minimal FITS header missing required keywords
        let headerData = "SIMPLE  =                    T / Standard FITS format                          END".padding(toLength: 2880, withPad: " ", startingAt: 0)
        let invalidData = Data(headerData.utf8)
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: invalidData, fileName: "invalid.fits")
        }
    }
}

// MARK: - TestSkip Helper

struct TestSkip: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}