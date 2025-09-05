import Foundation
import CoreImage

public struct StandardAstroImage: AstroImage, Sendable {
    
    public let metadata: any AstroImageMetadata
    private let ciImage: CIImage
    
    public init(imageData: Data, fileName: String, format: ImageFormat) throws {
        guard let ciImage = CIImage(data: imageData) else {
            throw StandardAstroImageError.invalidImageData
        }
        
        self.ciImage = ciImage
        
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)
        
        self.metadata = StandardImageMetadata(
            width: width,
            height: height,
            pixelFormat: .uint8, // Standard formats typically use 8-bit
            colorSpace: .sRGB,   // Standard formats typically sRGB
            creationDate: Date(),
            fileSize: imageData.count,
            fileName: fileName,
            format: format
        )
    }
    
    public init(url: URL) async throws {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let format = try ImageFormat.from(url: url)
        
        try self.init(imageData: data, fileName: fileName, format: format)
    }
    
    public func pixelData(in region: PixelRegion?) async throws -> Data {
        let context = CIContext()
        let extent = region?.ciRect ?? ciImage.extent
        
        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            throw StandardAstroImageError.pixelDataExtractionFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 3 // RGB
        let totalBytes = width * height * bytesPerPixel
        
        var pixelData = Data(count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context2D = CGContext(
            data: pixelData.withUnsafeMutableBytes { $0.baseAddress },
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let context2D = context2D else {
            throw StandardAstroImageError.pixelDataExtractionFailed
        }
        
        context2D.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelData
    }
    
    public func generateHistogram() async throws -> HistogramData {
        let pixelData = try await pixelData(in: nil)
        let width = Int(metadata.dimensions.width)
        let height = Int(metadata.dimensions.height)
        let bytesPerPixel = 3
        
        var redCounts = Array(repeating: 0, count: 256)
        var greenCounts = Array(repeating: 0, count: 256)
        var blueCounts = Array(repeating: 0, count: 256)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let red = Int(pixelData[pixelIndex])
                let green = Int(pixelData[pixelIndex + 1])
                let blue = Int(pixelData[pixelIndex + 2])
                
                redCounts[red] += 1
                greenCounts[green] += 1
                blueCounts[blue] += 1
            }
        }
        
        // Convert to UInt16 for histogram analysis
        let pixelValues: [UInt16] = pixelData.map { UInt16($0) }
        return HistogramData(pixelValues: pixelValues, bitDepth: 8)
    }
    
    public func supportsBayerDemosaic() -> Bool {
        return false // Standard images are already debayered
    }
    
    public func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
        throw AstroImageError.demosaicNotSupported
    }
}

public enum StandardAstroImageError: Error, Sendable, Equatable {
    case invalidImageData
    case pixelDataExtractionFailed
    case unsupportedFormat(String)
}

private extension ImageFormat {
    static func from(url: URL) throws -> ImageFormat {
        let pathExtension = url.pathExtension.lowercased()
        
        for format in ImageFormat.allCases {
            if format.fileExtensions.contains(pathExtension) {
                return format
            }
        }
        
        throw StandardAstroImageError.unsupportedFormat(pathExtension)
    }
}

private extension PixelRegion {
    var ciRect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}