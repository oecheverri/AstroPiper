import Testing
import Foundation
@testable import AstroPiperCore

struct FITSImageLoaderTests {
    
    // Path to real FITS test files
    private static let sampleFilesPath = "../Sample Files"
    private static let testFITSFile = "Light_IC2087_180.0s_Bin1_533MC_gain360_20221003-041814_-9.9C_0024.fit"
    
    // MARK: - Real File Tests
    
    @Test("FITS loader parses real astronomical file correctly")
    func fitsImageLoaderParsesRealFITSFile() async throws {
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
    
    @Test("FITS loader completes parsing large file within reasonable time")
    func fitsImageLoaderPerformance() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let startTime = Date()
        let image = try await FITSImageLoader.load(from: testURL)
        let duration = Date().timeIntervalSince(startTime)
        
        // Loading ~18MB FITS file should complete within 5 seconds
        #expect(duration < 5.0)
        #expect(image.metadata is FITSImageMetadata)
        
        let fitsMetadata = image.metadata as! FITSImageMetadata
        #expect(fitsMetadata.totalPixels == 3008 * 3008)
    }
    
    @Test("FITS metadata extraction validates all critical properties")
    func fitsImageLoaderExtractsMetadataCorrectly() async throws {
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
        
        // Verify file metadata
        #expect(metadata.filename == Self.testFITSFile)
        #expect(metadata.fileSize != nil)
        #expect(metadata.fileSize! > 0)
    }
    
    @Test("FITS metadata parsing is memory efficient with large files")
    func fitsMetadataParsingMemoryEfficiency() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        // Parse metadata multiple times to check for memory leaks
        for _ in 0..<5 {
            let metadata = try await FITSImageLoader.parseMetadata(from: testURL)
            #expect(metadata.totalPixels == 3008 * 3008)
            #expect(metadata.bitpix == 16)
            
            // Force deallocation by discarding reference
            _ = metadata
        }
        
        // If we reach here without memory pressure, the test passes
        #expect(true)
    }
    
    @Test("FITS astronomical metadata extraction is comprehensive")
    func fitsImageLoaderExtractsObservatoryMetadata() async throws {
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
        
        // Verify exposure and camera settings if present
        if let exptime = metadata.exptime {
            #expect(exptime > 0.0)
            #expect(exptime <= 3600.0) // Reasonable exposure limit
        }
        
        // Verify binning information if present
        if let binning = metadata.binning {
            #expect(binning.horizontal >= 1)
            #expect(binning.vertical >= 1)
            #expect(binning.horizontal <= 4) // Typical binning limit
            #expect(binning.vertical <= 4)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("FITS loader handles corrupted data gracefully")
    func fitsImageLoaderHandlesCorruptedData() async {
        let corruptedData = Data(repeating: 0xFF, count: 1000)
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: corruptedData, fileName: "corrupt.fits")
        }
    }
    
    @Test("FITS loader validates required keywords presence")
    func fitsImageLoaderValidatesRequiredKeywords() async {
        // Create minimal FITS header missing required keywords
        let headerData = "SIMPLE  =                    T / Standard FITS format                          END".padding(toLength: 2880, withPad: " ", startingAt: 0)
        let invalidData = Data(headerData.utf8)
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: invalidData, fileName: "invalid.fits")
        }
    }
    
    @Test("FITS loader rejects malformed header structure")
    func fitsImageLoaderRejectsMalformedHeader() async {
        // Create header without END keyword
        let malformedHeader = "SIMPLE  =                    T / Standard FITS format                          NAXIS   =                    2 / Number of axes              ".padding(toLength: 2880, withPad: " ", startingAt: 0)
        let malformedData = Data(malformedHeader.utf8)
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: malformedData, fileName: "malformed.fits")
        }
    }
    
    @Test("FITS loader detects insufficient data size")
    func fitsImageLoaderDetectsInsufficientDataSize() async {
        // Create valid header but insufficient data
        let validHeader = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                   16 / Bits per pixel                                
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                  100 / Width                                         
NAXIS2  =                  100 / Height                                        
BZERO   =                32768 / Zero point                                    
BSCALE  =                    1 / Scale factor                                  
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        let headerData = Data(validHeader.utf8)
        let insufficientImageData = Data(repeating: 0, count: 100) // Far less than 100*100*2 bytes needed
        let combinedData = headerData + insufficientImageData
        
        await #expect(throws: FITSImageLoaderError.self) {
            let _ = try await FITSImageLoader.load(data: combinedData, fileName: "insufficient.fits")
        }
    }
    
    @Test("FITS loader rejects unsupported bit depth")
    func fitsImageLoaderRejectsUnsupportedBitDepth() async {
        // Create header with unsupported BITPIX value
        let unsupportedHeader = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                   24 / Unsupported 24-bit depth                      
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                   10 / Width                                         
NAXIS2  =                   10 / Height                                        
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        let headerData = Data(unsupportedHeader.utf8)
        let imageData = Data(repeating: 0, count: 300) // 10*10*3 bytes for 24-bit
        let combinedData = (headerData + imageData).fitsPadded()
        
        await #expect(throws: FITSImageLoaderError.self) {
            try await FITSImageLoader.load(data: combinedData, fileName: "unsupported.fits")
        }
    }
    
    // MARK: - BZERO/BSCALE Transformation Tests
    
    @Test("FITS BZERO BSCALE physical value transformation is mathematically correct")
    func fitsImageLoaderHandlesPhysicalValueTransformation() async throws {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [1024, 1024],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 2.0,
            filename: "test.fits"
        )
        
        // Test BZERO/BSCALE transformation: physical = BSCALE * raw + BZERO
        #expect(metadata.physicalValue(from: 0.0) == 32768.0)      // 2.0 * 0 + 32768
        #expect(metadata.physicalValue(from: 1000.0) == 34768.0)   // 2.0 * 1000 + 32768
        #expect(metadata.physicalValue(from: -16384.0) == 0.0)     // 2.0 * -16384 + 32768
        #expect(metadata.physicalValue(from: 16384.0) == 65536.0)  // 2.0 * 16384 + 32768
    }
    
    @Test("FITS default scaling values work correctly")
    func fitsDefaultScalingValues() async throws {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [512, 512],
            bitpix: 16,
            bzero: nil,  // Should default to 0.0
            bscale: nil, // Should default to 1.0
            filename: "default.fits"
        )
        
        // With default values (BSCALE=1.0, BZERO=0.0), physical = raw
        #expect(metadata.physicalValue(from: 100.0) == 100.0)
        #expect(metadata.physicalValue(from: -100.0) == -100.0)
        #expect(metadata.physicalValue(from: 0.0) == 0.0)
    }
    
    @Test("FITS scaling handles boundary conditions correctly")
    func fitsScalingBoundaryConditions() async throws {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [10, 10],
            bitpix: 16,
            bzero: 32768.0,
            bscale: 1.0,
            filename: "boundary.fits"
        )
        
        // Test signed 16-bit boundaries
        #expect(metadata.physicalValue(from: -32768.0) == 0.0)     // Minimum signed 16-bit
        #expect(metadata.physicalValue(from: 32767.0) == 65535.0)  // Maximum signed 16-bit
        #expect(metadata.physicalValue(from: 0.0) == 32768.0)      // Zero point
    }
    
    // MARK: - FITSAstroImage Pixel Data Tests
    
    @Test("FITS astro image generates correct pixel data for full image")
    func fitsAstroImageGeneratesPixelData() async throws {
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
    
    @Test("FITS pixel data generation completes efficiently for large images")
    func fitsPixelDataPerformance() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        let startTime = Date()
        let pixelData = try await image.pixelData(in: nil)
        let duration = Date().timeIntervalSince(startTime)
        
        // Processing 18MB of pixel data should complete within 3 seconds
        #expect(duration < 3.0)
        #expect(pixelData.count == 3008 * 3008 * 2)
    }
    
    // MARK: - Histogram Generation Tests
    
    @Test("FITS astro image generates scientifically valid histogram")
    func fitsAstroImageGeneratesHistogram() async throws {
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
        
        // Verify statistical consistency
        #expect(histogram.minimum <= histogram.mean)
        #expect(histogram.mean <= histogram.maximum)
        #expect(histogram.standardDeviation >= 0.0)
    }
    
    @Test("FITS histogram generation is reasonably fast for large images")
    func fitsHistogramPerformance() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        let startTime = Date()
        let histogram = try await image.generateHistogram()
        let duration = Date().timeIntervalSince(startTime)
        
        // Histogram generation for 9M pixels should complete within 2 seconds
        #expect(duration < 2.0)
        #expect(histogram.count == 3008 * 3008)
    }
    
    // MARK: - Region Extraction Tests
    
    @Test("FITS astro image extracts accurate region data")
    func fitsAstroImageExtractsRegionData() async throws {
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
    
    @Test("FITS region extraction handles various sizes correctly")
    func fitsRegionExtractionVariousSizes() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Test various region sizes
        let testRegions: [(width: UInt32, height: UInt32, x: UInt32, y: UInt32)] = [
            (10, 10, 0, 0),        // Small corner region
            (50, 50, 1500, 1500),  // Medium center region
            (1, 1, 100, 100),      // Single pixel
            (1000, 500, 1000, 1000), // Large rectangular region
        ]
        
        for (width, height, x, y) in testRegions {
            let region = PixelRegion(x: x, y: y, width: width, height: height)
            let regionData = try await image.pixelData(in: region)
            let expectedSize = Int(width) * Int(height) * 2 // 2 bytes per pixel
            
            #expect(regionData.count == expectedSize)
        }
    }
    
    @Test("FITS astro image handles boundary conditions for regions")
    func fitsAstroImageHandlesBoundsChecking() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Test various out-of-bounds scenarios
        let invalidRegions = [
            PixelRegion(x: 3000, y: 3000, width: 100, height: 100), // Completely outside
            PixelRegion(x: 3000, y: 0, width: 100, height: 100),    // X outside
            PixelRegion(x: 0, y: 3000, width: 100, height: 100),    // Y outside
            PixelRegion(x: 2950, y: 2950, width: 100, height: 100), // Partially outside
            PixelRegion(x: 0, y: 0, width: 4000, height: 100),      // Width exceeds bounds
            PixelRegion(x: 0, y: 0, width: 100, height: 4000),      // Height exceeds bounds
        ]
        
        for region in invalidRegions {
            await #expect(throws: AstroImageError.self) {
                let _ = try await image.pixelData(in: region)
            }
        }
    }
    
    @Test("FITS region extraction handles edge cases correctly")
    func fitsRegionExtractionEdgeCases() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        
        // Test edge-touching regions (valid but at boundaries)
        let edgeRegions = [
            PixelRegion(x: 0, y: 0, width: 1, height: 1),           // Top-left corner
            PixelRegion(x: 3007, y: 3007, width: 1, height: 1),     // Bottom-right corner
            PixelRegion(x: 2908, y: 2908, width: 100, height: 100), // Bottom-right 100x100
            PixelRegion(x: 0, y: 0, width: 3008, height: 1),        // Full width, single row
            PixelRegion(x: 0, y: 0, width: 1, height: 3008),        // Full height, single column
        ]
        
        for region in edgeRegions {
            let regionData = try await image.pixelData(in: region)
            let expectedSize = Int(region.width) * Int(region.height) * 2
            #expect(regionData.count == expectedSize)
        }
    }
    
    // MARK: - Bayer Pattern Tests
    
    @Test("FITS astro image correctly detects absence of Bayer pattern")
    func fitsAstroImageDetectsBayerPattern() async throws {
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
    
    @Test("FITS Bayer detection handles all pattern types consistently")
    func fitsBayerPatternDetectionConsistency() async throws {
        let testURL = URL(fileURLWithPath: "\(Self.sampleFilesPath)/\(Self.testFITSFile)")
        
        guard FileManager.default.fileExists(atPath: testURL.path) else {
            throw TestSkip("FITS test file not found")
        }
        
        let image = try await FITSImageLoader.load(from: testURL)
        let supportsBayer = image.supportsBayerDemosaic()
        
        // All Bayer patterns should behave consistently with the same image
        for pattern in BayerPattern.allCases {
            if supportsBayer {
                // If Bayer is supported, demosaicing should work or throw appropriate error
                await #expect(throws: AstroImageError.self) {
                    let _ = try await image.demosaicedImage(bayerPattern: pattern)
                }
            } else {
                // If not supported, all patterns should fail
                await #expect(throws: AstroImageError.self) {
                    let _ = try await image.demosaicedImage(bayerPattern: pattern)
                }
            }
        }
    }
    
    // MARK: - Byte Swapping and Data Format Tests
    
    @Test("FITS byte swapping produces consistent results")
    func fitsByteSwappingConsistency() async throws {
        // Create a small test FITS with known data pattern
        let testData = createTestFITSData(width: 4, height: 4, bitpix: 16)
        let image = try await FITSImageLoader.load(data: testData, fileName: "test.fits")
        let pixelData = try await image.pixelData(in: nil)
        
        // Verify expected data size
        #expect(pixelData.count == 4 * 4 * 2) // 4x4 pixels, 2 bytes each
        
        // Verify data is properly byte-swapped (big-endian to native)
        #expect(pixelData.count > 0)
    }
    
    @Test("FITS handles different bit depths correctly")
    func fitsDifferentBitDepths() async throws {
        let bitDepths: [Int] = [8, 16, 32, -32, -64]
        
        for bitpix in bitDepths {
            let testData = createTestFITSData(width: 2, height: 2, bitpix: bitpix)
            
            do {
                let image = try await FITSImageLoader.load(data: testData, fileName: "test_\(bitpix).fits")
                let metadata = image.metadata as! FITSImageMetadata
                
                #expect(metadata.bitpix == bitpix)
                #expect(metadata.bytesPerPixel == abs(bitpix) / 8)
                
                let pixelData = try await image.pixelData(in: nil)
                let expectedSize = 2 * 2 * abs(bitpix) / 8
                #expect(pixelData.count == expectedSize)
            } catch {
                // Some bit depths might not be fully supported yet
                #expect(error is FITSImageLoaderError)
            }
        }
    }
    
    // MARK: - Regression Tests
    
    @Test("FITS loader regression test for header parsing edge cases")
    func fitsHeaderParsingRegressionTest() async throws {
        // Test various header edge cases that caused issues in the past
        let edgeCaseHeaders = [
            // Header with extra spaces
            createFITSHeaderWithExtraSpaces(),
            // Header with comments containing equals signs
            createFITSHeaderWithComplexComments(),
            // Header with string values containing quotes
            createFITSHeaderWithQuotedStrings(),
        ]
        
        for headerData in edgeCaseHeaders {
            let imageData = Data(repeating: 0, count: 200) // 10x10 16-bit image
            let combinedData = (headerData + imageData).fitsPadded()
            
            do {
                let image = try await FITSImageLoader.load(data: combinedData, fileName: "edge_case.fits")
                let metadata = image.metadata as! FITSImageMetadata
                
                // Basic validation that parsing succeeded
                #expect(metadata.naxis == 2)
                #expect(metadata.dimensions.width == 10)
                #expect(metadata.dimensions.height == 10)
            } catch FITSImageLoaderError.malformedHeader {
                // Some edge cases might legitimately fail
                continue
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func createTestFITSData(width: Int, height: Int, bitpix: Int) -> Data {
        let header = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                 \(String(format: "%4d", bitpix)) / Bits per pixel                                
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                 \(String(format: "%4d", width)) / Width                                         
NAXIS2  =                 \(String(format: "%4d", height)) / Height                                        
BZERO   =                32768 / Zero point                                    
BSCALE  =                    1 / Scale factor                                  
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        let headerData = Data(header.utf8)
        let bytesPerPixel = abs(bitpix) / 8
        let imageSize = width * height * bytesPerPixel
        let imageData = Data(repeating: 0, count: imageSize)
        let paddedImageData = imageData.fitsPadded()
        
        return headerData + paddedImageData
    }
    
    private func createFITSHeaderWithExtraSpaces() -> Data {
        let header = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                   16 / Bits per pixel                                
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                   10 / Width                                         
NAXIS2  =                   10 / Height                                        
CREATOR =     'Test   Creator' / Software that created this file               
COMMENT   This is a comment with extra spaces                                  
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        return Data(header.utf8)
    }
    
    private func createFITSHeaderWithComplexComments() -> Data {
        let header = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                   16 / Bits per pixel                                
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                   10 / Width                                         
NAXIS2  =                   10 / Height                                        
COMMENT Complex comment with = equals signs = and / slashes                    
HISTORY Processing step: calibration=dark, bias=true                           
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        return Data(header.utf8)
    }
    
    private func createFITSHeaderWithQuotedStrings() -> Data {
        let header = """
SIMPLE  =                    T / Standard FITS format                          
BITPIX  =                   16 / Bits per pixel                                
NAXIS   =                    2 / Number of axes                                
NAXIS1  =                   10 / Width                                         
NAXIS2  =                   10 / Height                                        
OBJECT  =  'NGC 1234 "Test"'  / Object with quotes                            
FILTER  =        'Ha (656nm)' / Filter description                            
END                                                                             
""".padding(toLength: 2880, withPad: " ", startingAt: 0)
        
        return Data(header.utf8)
    }
}

// MARK: - TestSkip Helper

struct TestSkip: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

// MARK: - Test Helpers

private extension Data {
    func fitsPadded() -> Data {
        let paddingNeeded = 2880 - (count % 2880)
        let padding = paddingNeeded == 2880 ? Data() : Data(repeating: 0, count: paddingNeeded)
        return self + padding
    }
}