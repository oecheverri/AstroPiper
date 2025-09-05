import Testing
import Foundation
@testable import AstroPiperCore

struct StandardImageMetadataTests {
    
    @Test func standardImageMetadataConformsToAstroImageMetadata() {
        let metadata = StandardImageMetadata.mock()
        #expect(metadata is any AstroImageMetadata)
    }
    
    @Test func standardImageMetadataPreservesBasicProperties() {
        let metadata = StandardImageMetadata(
            width: 1920,
            height: 1080,
            pixelFormat: .uint8,
            colorSpace: .sRGB,
            creationDate: Date(timeIntervalSince1970: 1640995200),
            fileSize: 2048000,
            fileName: "test_image.jpg",
            format: .jpeg
        )
        
        #expect(metadata.width == 1920)
        #expect(metadata.height == 1080)
        #expect(metadata.pixelFormat == .uint8)
        #expect(metadata.colorSpace == .sRGB)
        #expect(metadata.fileSize == 2048000)
        #expect(metadata.fileName == "test_image.jpg")
        #expect(metadata.format == .jpeg)
    }
    
    @Test func standardImageMetadataComputedProperties() {
        let metadata = StandardImageMetadata(
            width: 4000,
            height: 3000,
            pixelFormat: .uint16,
            colorSpace: .sRGB,
            creationDate: Date(),
            fileSize: 24000000,
            fileName: "large_image.tiff",
            format: .tiff
        )
        
        #expect(metadata.totalPixels == 12000000)
        #expect(abs(metadata.aspectRatio - 4.0/3.0) < 0.001)
        #expect(abs(metadata.megapixels - 12.0) < 0.1)
    }
    
    @Test func standardImageMetadataCompletenessScore() {
        let completeMetadata = StandardImageMetadata(
            width: 1920,
            height: 1080,
            pixelFormat: .uint8,
            colorSpace: .sRGB,
            creationDate: Date(),
            fileSize: 2048000,
            fileName: "complete.jpg",
            format: .jpeg
        )
        // Standard images have 0 completeness since they lack astronomical metadata
        #expect(completeMetadata.completenessScore == 0.0)
        
        let incompleteMetadata = StandardImageMetadata(
            width: 1920,
            height: 1080,
            pixelFormat: .uint8,
            colorSpace: .sRGB,
            creationDate: nil,
            fileSize: nil,
            fileName: "incomplete.jpg",
            format: .jpeg
        )
        #expect(incompleteMetadata.completenessScore >= 0.0)
    }
    
    @Test func standardImageMetadataSendable() async {
        let metadata = StandardImageMetadata.mock()
        await Task {
            let _ = metadata // Should compile without warnings
        }.value
    }
    
    @Test func standardImageMetadataCodable() throws {
        let original = StandardImageMetadata.mock()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StandardImageMetadata.self, from: data)
        
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
        #expect(decoded.fileName == original.fileName)
        #expect(decoded.format == original.format)
    }
    
    @Test func standardImageMetadataEquatable() {
        let metadata1 = StandardImageMetadata.mock()
        let metadata2 = StandardImageMetadata.mock()
        let metadata3 = StandardImageMetadata(
            width: 999,
            height: 999,
            pixelFormat: .uint8,
            colorSpace: .sRGB,
            creationDate: Date(),
            fileSize: 1000,
            fileName: "different.jpg",
            format: .jpeg
        )
        
        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)
    }
    
    @Test func imageFormatAllCases() {
        let formats: [ImageFormat] = [.jpeg, .png, .tiff]
        #expect(Set(formats) == Set(ImageFormat.allCases))
    }
    
    @Test func imageFormatFileExtensions() {
        #expect(ImageFormat.jpeg.fileExtensions.contains("jpg"))
        #expect(ImageFormat.jpeg.fileExtensions.contains("jpeg"))
        #expect(ImageFormat.png.fileExtensions.contains("png"))
        #expect(ImageFormat.tiff.fileExtensions.contains("tiff"))
        #expect(ImageFormat.tiff.fileExtensions.contains("tif"))
    }
}

private extension StandardImageMetadata {
    static func mock() -> StandardImageMetadata {
        StandardImageMetadata(
            width: 1920,
            height: 1080,
            pixelFormat: .uint8,
            colorSpace: .sRGB,
            creationDate: Date(timeIntervalSince1970: 1640995200),
            fileSize: 2048000,
            fileName: "mock_image.jpg",
            format: .jpeg
        )
    }
}