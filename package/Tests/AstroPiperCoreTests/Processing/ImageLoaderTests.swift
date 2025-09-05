import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import AstroPiperCore

struct ImageLoaderTests {
    
    @Test func imageLoaderLoadsJPEGFromURL() async throws {
        let testURL = try TestImageHelper.createTestJPEG()
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        let image = try await ImageLoader.load(from: testURL)
        
        #expect(image is StandardAstroImage)
        #expect(Int(image.metadata.dimensions.width) > 0)
        #expect(Int(image.metadata.dimensions.height) > 0)
    }
    
    @Test func imageLoaderLoadsJPEGFromData() async throws {
        let testData = try TestImageHelper.createTestJPEGData()
        
        let image = try await ImageLoader.load(data: testData, fileName: "test.jpg")
        
        #expect(image is StandardAstroImage)
        #expect(Int(image.metadata.dimensions.width) > 0)
        #expect(Int(image.metadata.dimensions.height) > 0)
    }
    
    @Test func imageLoaderExtractsMetadata() async throws {
        let testURL = try TestImageHelper.createTestJPEG()
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        let metadata = try await MetadataExtractor.extractMetadata(from: testURL)
        
        #expect(metadata.pixelFormat == .uint8)
        #expect(metadata.colorSpace == .sRGB)
        #expect(metadata.filename?.hasSuffix(".jpg") == true)
    }
    
    @Test func imageLoaderHandlesUnsupportedFormat() async {
        let testURL = URL(fileURLWithPath: "/tmp/test.unsupported")
        
        await #expect(throws: ImageLoaderError.self) {
            try await ImageLoader.load(from: testURL)
        }
    }
    
    @Test func imageLoaderHandlesCorruptedData() async {
        let corruptedData = Data(repeating: 0xFF, count: 100)
        
        await #expect(throws: ImageLoaderError.self) {
            try await ImageLoader.load(data: corruptedData, fileName: "corrupt.jpg")
        }
    }
}

private struct TestImageHelper {
    static func createTestJPEG() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).jpg")
        
        let testData = try createTestJPEGData()
        try testData.write(to: testURL)
        
        return testURL
    }
    
    static func createTestJPEGData() throws -> Data {
        // Create a simple 1x1 JPEG in memory using Core Graphics
        let width = 100
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ImageLoaderError.imageCreationFailed
        }
        
        // Draw a gradient
        context.setFillColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let cgImage = context.makeImage() else {
            throw ImageLoaderError.imageCreationFailed
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw ImageLoaderError.imageCreationFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageLoaderError.imageCreationFailed
        }
        
        return mutableData as Data
    }
}