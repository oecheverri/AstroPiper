import Testing
import Foundation
@testable import AstroPiperCore

struct StandardAstroImageTests {
    
    @Test func standardAstroImageConformsToAstroImage() async throws {
        let image = try StandardAstroImage.mock()
        #expect(image is any AstroImage)
    }
    
    @Test func standardAstroImageProvidesMetadata() throws {
        let image = try StandardAstroImage.mock()
        let metadata = image.metadata
        
        #expect(metadata is StandardImageMetadata)
        #expect(Int(metadata.dimensions.width) == 100)
        #expect(Int(metadata.dimensions.height) == 100)
    }
    
    @Test func standardAstroImagePixelDataForFullRegion() async throws {
        let image = try StandardAstroImage.mock()
        let pixelData = try await image.pixelData(in: nil)
        
        // RGB image: 100x100x3 = 30,000 bytes
        #expect(pixelData.count == 30000)
    }
    
    @Test func standardAstroImagePixelDataForSubregion() async throws {
        let image = try StandardAstroImage.mock()
        let region = PixelRegion(x: 10, y: 10, width: 20, height: 20)
        let pixelData = try await image.pixelData(in: region)
        
        // Subregion: 20x20x3 = 1,200 bytes
        #expect(pixelData.count == 1200)
    }
    
    @Test func standardAstroImageGeneratesHistogram() async throws {
        let image = try StandardAstroImage.mock()
        let histogram = try await image.generateHistogram()
        
        #expect(histogram.bitDepth == 8)
        #expect(histogram.count > 0)
        #expect(histogram.minimum >= 0.0)
        #expect(histogram.maximum <= 255.0)
    }
    
    @Test func standardAstroImageInitializationFromData() throws {
        let testData = TestImageData.createSolidColorImage(
            width: 50, 
            height: 50, 
            red: 128, 
            green: 64, 
            blue: 192
        )
        
        let image = try StandardAstroImage(
            imageData: testData,
            fileName: "test.jpg",
            format: .jpeg
        )
        
        #expect(Int(image.metadata.dimensions.width) == 50)
        #expect(Int(image.metadata.dimensions.height) == 50)
        #expect(image.metadata.filename == "test.jpg")
    }
    
    @Test func standardAstroImageInitializationFromURL() async throws {
        let testURL = try TestImageData.createTemporaryImageFile()
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        let image = try await StandardAstroImage(url: testURL)
        
        #expect(Int(image.metadata.dimensions.width) == 100)
        #expect(Int(image.metadata.dimensions.height) == 100)
        #expect(image.metadata.filename?.hasSuffix(".jpg") == true)
    }
    
    @Test func standardAstroImageSendable() async throws {
        let image = try StandardAstroImage.mock()
        await Task {
            let _ = image // Should compile without warnings
        }.value
    }
    
    @Test func standardAstroImageErrorHandling() async {
        #expect(throws: StandardAstroImageError.self) {
            let _ = try StandardAstroImage(
                imageData: Data(), // Empty data should fail
                fileName: "empty.jpg",
                format: .jpeg
            )
        }
    }
}

private extension StandardAstroImage {
    static func mock() throws -> StandardAstroImage {
        let testData = TestImageData.createSolidColorImage(
            width: 100,
            height: 100,
            red: 255,
            green: 128,
            blue: 0
        )
        return try StandardAstroImage(
            imageData: testData,
            fileName: "mock.jpg",
            format: .jpeg
        )
    }
}

private struct TestImageData {
    static func createSolidColorImage(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> Data {
        let bytesPerPixel = 3
        let totalBytes = width * height * bytesPerPixel
        var data = Data(capacity: totalBytes)
        
        for _ in 0..<(width * height) {
            data.append(red)
            data.append(green)
            data.append(blue)
        }
        
        return data
    }
    
    static func createTemporaryImageFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).jpg")
        
        let imageData = createSolidColorImage(width: 100, height: 100, red: 200, green: 100, blue: 50)
        try imageData.write(to: testURL)
        
        return testURL
    }
}