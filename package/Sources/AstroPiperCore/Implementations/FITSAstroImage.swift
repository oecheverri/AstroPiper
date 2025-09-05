import Foundation

/// FITS astronomical image implementation with scientific data handling
/// 
/// Provides AstroImage interface for FITS format files with proper handling
/// of astronomical bit depths, BZERO/BSCALE transformations, and scientific
/// imaging requirements including potential Bayer pattern support.
public struct FITSAstroImage: AstroImage, Sendable {
    
    public let metadata: any AstroImageMetadata
    private let rawImageData: Data
    
    public init(metadata: FITSImageMetadata, imageData: Data) {
        self.metadata = metadata
        self.rawImageData = imageData
    }
    
    // MARK: - AstroImage Protocol
    
    public func pixelData(in region: PixelRegion?) async throws -> Data {
        let fitsMetadata = try getFITSMetadata()
        
        if let region = region {
            return try await extractRegionData(region: region, fitsMetadata: fitsMetadata)
        } else {
            return try await processFullImageData(fitsMetadata: fitsMetadata)
        }
    }
    
    public func generateHistogram() async throws -> HistogramData {
        let fitsMetadata = try getFITSMetadata()
        let processedData = try await processFullImageData(fitsMetadata: fitsMetadata)
        
        // Convert processed data to UInt16 values for histogram
        let pixelValues = try convertToUInt16Array(
            data: processedData,
            bitpix: fitsMetadata.bitpix,
            bzero: fitsMetadata.bzero,
            bscale: fitsMetadata.bscale
        )
        
        return HistogramData(pixelValues: pixelValues, bitDepth: 16)
    }
    
    public func supportsBayerDemosaic() -> Bool {
        // Check for Bayer pattern indicators in FITS headers
        let fitsMetadata = metadata as? FITSImageMetadata
        
        // Look for common Bayer pattern keywords
        if let bayerpattern = fitsMetadata?.customValue(for: "BAYERPAT") ?? 
                             fitsMetadata?.customValue(for: "COLORTYP") {
            return !bayerpattern.isEmpty
        }
        
        // Check if this is a color camera (common indicator)
        if fitsMetadata?.customValue(for: "XBAYROFF") != nil {
            return true
        }
        
        return false
    }
    
    public func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
        guard supportsBayerDemosaic() else {
            throw AstroImageError.demosaicNotSupported
        }
        
        // For now, throw not supported - demosaicing would be implemented here
        throw AstroImageError.demosaicNotSupported
    }
    
    // MARK: - FITS-Specific Implementation
    
    /// Get the metadata as FITSImageMetadata
    private func getFITSMetadata() throws -> FITSImageMetadata {
        guard let fitsMetadata = metadata as? FITSImageMetadata else {
            throw AstroImageError.customError("Invalid metadata type for FITS image")
        }
        return fitsMetadata
    }
    
    /// Process full image data with BZERO/BSCALE transformations
    private func processFullImageData(fitsMetadata: FITSImageMetadata) async throws -> Data {
        let width = Int(fitsMetadata.dimensions.width)
        let height = Int(fitsMetadata.dimensions.height)
        
        return try processImageData(
            data: rawImageData,
            width: width,
            height: height,
            bitpix: fitsMetadata.bitpix,
            bzero: fitsMetadata.bzero,
            bscale: fitsMetadata.bscale
        )
    }
    
    /// Extract and process a specific region of the image
    private func extractRegionData(
        region: PixelRegion,
        fitsMetadata: FITSImageMetadata
    ) async throws -> Data {
        let fullWidth = Int(fitsMetadata.dimensions.width)
        let fullHeight = Int(fitsMetadata.dimensions.height)
        let bytesPerPixel = fitsMetadata.bytesPerPixel
        
        // Validate region bounds
        let regionX = Int(region.x)
        let regionY = Int(region.y)  
        let regionWidth = Int(region.width)
        let regionHeight = Int(region.height)
        
        guard regionX >= 0, regionY >= 0,
              regionX + regionWidth <= fullWidth,
              regionY + regionHeight <= fullHeight else {
            throw AstroImageError.regionOutOfBounds(region)
        }
        
        // Extract region data
        var regionData = Data()
        
        for row in regionY..<(regionY + regionHeight) {
            let rowStartByte = row * fullWidth * bytesPerPixel
            let regionStartByte = rowStartByte + (regionX * bytesPerPixel)
            let regionEndByte = regionStartByte + (regionWidth * bytesPerPixel)
            
            guard regionEndByte <= rawImageData.count else {
                throw AstroImageError.dataCorruption
            }
            
            let rowData = rawImageData[regionStartByte..<regionEndByte]
            regionData.append(rowData)
        }
        
        // Process the extracted region data
        return try processImageData(
            data: regionData,
            width: regionWidth,
            height: regionHeight,
            bitpix: fitsMetadata.bitpix,
            bzero: fitsMetadata.bzero,
            bscale: fitsMetadata.bscale
        )
    }
    
    /// Apply FITS data transformations (BZERO/BSCALE) to image data
    private func processImageData(
        data: Data,
        width: Int,
        height: Int,
        bitpix: Int,
        bzero: Double?,
        bscale: Double?
    ) throws -> Data {
        
        let scale = bscale ?? 1.0
        let zero = bzero ?? 0.0
        
        // If no scaling needed, return data as-is
        if scale == 1.0 && zero == 0.0 {
            return data
        }
        
        // Apply BZERO/BSCALE transformation based on bit depth
        switch bitpix {
        case 8:
            return try transformUInt8Data(data, scale: scale, zero: zero)
        case 16:
            return try transformInt16Data(data, scale: scale, zero: zero)
        case 32:
            return try transformInt32Data(data, scale: scale, zero: zero)
        case -32:
            return try transformFloat32Data(data, scale: scale, zero: zero)
        case -64:
            return try transformFloat64Data(data, scale: scale, zero: zero)
        default:
            throw AstroImageError.invalidPixelFormat
        }
    }
    
    // MARK: - Data Transformation Methods
    
    private func transformUInt8Data(_ data: Data, scale: Double, zero: Double) throws -> Data {
        var result = Data(capacity: data.count)
        
        for byte in data {
            let rawValue = Double(byte)
            let physicalValue = scale * rawValue + zero
            let clampedValue = max(0, min(255, physicalValue))
            result.append(UInt8(clampedValue))
        }
        
        return result
    }
    
    private func transformInt16Data(_ data: Data, scale: Double, zero: Double) throws -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 2) {
            guard i + 1 < data.count else { break }
            
            let rawValue = data.withUnsafeBytes { bytes in
                Int16(bytes.load(fromByteOffset: i, as: Int16.self))
            }
            
            let physicalValue = scale * Double(rawValue) + zero
            let clampedValue = max(-32768, min(32767, physicalValue))
            
            withUnsafeBytes(of: Int16(clampedValue)) { bytes in
                result.append(contentsOf: bytes)
            }
        }
        
        return result
    }
    
    private func transformInt32Data(_ data: Data, scale: Double, zero: Double) throws -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 4) {
            guard i + 3 < data.count else { break }
            
            let rawValue = data.withUnsafeBytes { bytes in
                Int32(bytes.load(fromByteOffset: i, as: Int32.self))
            }
            
            let physicalValue = scale * Double(rawValue) + zero
            let clampedValue = max(-2147483648, min(2147483647, physicalValue))
            
            withUnsafeBytes(of: Int32(clampedValue)) { bytes in
                result.append(contentsOf: bytes)
            }
        }
        
        return result
    }
    
    private func transformFloat32Data(_ data: Data, scale: Double, zero: Double) throws -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 4) {
            guard i + 3 < data.count else { break }
            
            let rawValue = data.withUnsafeBytes { bytes in
                Float(bytes.load(fromByteOffset: i, as: Float.self))
            }
            
            let physicalValue = Float(scale * Double(rawValue) + zero)
            
            withUnsafeBytes(of: physicalValue) { bytes in
                result.append(contentsOf: bytes)
            }
        }
        
        return result
    }
    
    private func transformFloat64Data(_ data: Data, scale: Double, zero: Double) throws -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 8) {
            guard i + 7 < data.count else { break }
            
            let rawValue = data.withUnsafeBytes { bytes in
                Double(bytes.load(fromByteOffset: i, as: Double.self))
            }
            
            let physicalValue = scale * rawValue + zero
            
            withUnsafeBytes(of: physicalValue) { bytes in
                result.append(contentsOf: bytes)
            }
        }
        
        return result
    }
    
    // MARK: - Histogram Utilities
    
    /// Convert processed data to UInt16 array for histogram generation
    private func convertToUInt16Array(
        data: Data,
        bitpix: Int,
        bzero: Double?,
        bscale: Double?
    ) throws -> [UInt16] {
        
        var result: [UInt16] = []
        
        switch bitpix {
        case 8:
            for byte in data {
                result.append(UInt16(byte))
            }
            
        case 16:
            for i in stride(from: 0, to: data.count, by: 2) {
                guard i + 1 < data.count else { break }
                
                let value = data.withUnsafeBytes { bytes in
                    Int16(bytes.load(fromByteOffset: i, as: Int16.self))
                }
                
                // Convert signed to unsigned for histogram
                let unsignedValue = UInt16(bitPattern: value)
                result.append(unsignedValue)
            }
            
        case 32:
            for i in stride(from: 0, to: data.count, by: 4) {
                guard i + 3 < data.count else { break }
                
                let value = data.withUnsafeBytes { bytes in
                    Int32(bytes.load(fromByteOffset: i, as: Int32.self))
                }
                
                // Scale down to 16-bit range
                let scaledValue = UInt16(max(0, min(65535, value / 65536 + 32768)))
                result.append(scaledValue)
            }
            
        case -32:
            for i in stride(from: 0, to: data.count, by: 4) {
                guard i + 3 < data.count else { break }
                
                let value = data.withUnsafeBytes { bytes in
                    Float(bytes.load(fromByteOffset: i, as: Float.self))
                }
                
                // Scale float to 16-bit range
                let scaledValue = UInt16(max(0, min(65535, value * 65535)))
                result.append(scaledValue)
            }
            
        case -64:
            for i in stride(from: 0, to: data.count, by: 8) {
                guard i + 7 < data.count else { break }
                
                let value = data.withUnsafeBytes { bytes in
                    Double(bytes.load(fromByteOffset: i, as: Double.self))
                }
                
                // Scale double to 16-bit range
                let scaledValue = UInt16(max(0, min(65535, value * 65535)))
                result.append(scaledValue)
            }
            
        default:
            throw AstroImageError.invalidPixelFormat
        }
        
        return result
    }
}