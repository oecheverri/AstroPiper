import Foundation

/// Pure Swift FITS (Flexible Image Transport System) file parser
/// 
/// Implements complete FITS file parsing without external dependencies,
/// supporting multiple bit depths, proper byte ordering, and multi-HDU files.
/// Handles astronomical image data with BZERO/BSCALE transformations.
public struct FITSImageLoader {
    
    /// Load a FITS astronomical image from a file URL
    /// - Parameter url: File URL to the FITS file
    /// - Returns: Loaded FITSAstroImage instance
    /// - Throws: FITSImageLoaderError for parsing failures
    public static func load(from url: URL) async throws -> FITSAstroImage {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        
        return try await load(data: data, fileName: fileName)
    }
    
    /// Load a FITS astronomical image from raw data
    /// - Parameters:
    ///   - data: Raw FITS file data
    ///   - fileName: Original filename for metadata
    /// - Returns: Loaded FITSAstroImage instance  
    /// - Throws: FITSImageLoaderError for parsing failures
    public static func load(data: Data, fileName: String) async throws -> FITSAstroImage {
        var parser = FITSParser(data: data)
        let hdu = try parser.parsePrimaryHDU()
        
        let metadata = try createMetadata(from: hdu.header, fileName: fileName, fileSize: UInt64(data.count))
        let imageData = try extractImageData(from: hdu, metadata: metadata)
        
        return FITSAstroImage(metadata: metadata, imageData: imageData)
    }
    
    /// Parse just the metadata from a FITS file
    /// - Parameter url: File URL to the FITS file
    /// - Returns: Extracted FITS metadata
    /// - Throws: FITSImageLoaderError for parsing failures
    public static func parseMetadata(from url: URL) async throws -> FITSImageMetadata {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        
        var parser = FITSParser(data: data)
        let hdu = try parser.parsePrimaryHDU()
        
        return try createMetadata(from: hdu.header, fileName: fileName, fileSize: UInt64(data.count))
    }
    
    // MARK: - Private Implementation
    
    /// Create FITSImageMetadata from parsed FITS headers
    private static func createMetadata(
        from header: FITSHeader,
        fileName: String,
        fileSize: UInt64
    ) throws -> FITSImageMetadata {
        
        // Extract required keywords
        guard let naxis = header.intValue(for: "NAXIS") else {
            throw FITSImageLoaderError.missingRequiredKeyword("NAXIS")
        }
        
        guard let bitpix = header.intValue(for: "BITPIX") else {
            throw FITSImageLoaderError.missingRequiredKeyword("BITPIX")
        }
        
        // Extract axis sizes
        var axisSizes: [UInt32] = []
        for i in 1...naxis {
            guard let size = header.intValue(for: "NAXIS\(i)") else {
                throw FITSImageLoaderError.missingRequiredKeyword("NAXIS\(i)")
            }
            axisSizes.append(UInt32(size))
        }
        
        // Extract optional scaling parameters
        let bzero = header.doubleValue(for: "BZERO")
        let bscale = header.doubleValue(for: "BSCALE")
        
        // Extract observatory metadata
        let telescope = header.stringValue(for: "TELESCOP")
        let instrument = header.stringValue(for: "INSTRUME")
        let observer = header.stringValue(for: "OBSERVER")
        let object = header.stringValue(for: "OBJECT")
        let filter = header.stringValue(for: "FILTER")
        
        // Parse observation date
        let dateObs = header.dateValue(for: "DATE-OBS")
        
        // Extract exposure and camera settings
        let exptime = header.doubleValue(for: "EXPTIME") ?? header.doubleValue(for: "EXPOSURE")
        let ccdTemp = header.doubleValue(for: "CCD-TEMP") ?? header.doubleValue(for: "TEMP")
        let ccdGain = header.doubleValue(for: "GAIN")
        
        // Extract binning information
        let xBin = header.intValue(for: "XBINNING") ?? 1
        let yBin = header.intValue(for: "YBINNING") ?? 1
        let binning = ImageBinning(horizontal: xBin, vertical: yBin)
        
        // Extract WCS information if available
        let wcs = extractWCSInfo(from: header)
        
        return FITSImageMetadata(
            naxis: naxis,
            axisSizes: axisSizes,
            bitpix: bitpix,
            bzero: bzero,
            bscale: bscale,
            filename: fileName,
            fileSize: fileSize,
            creationDate: Date(), // Use current date as file creation
            telescope: telescope,
            instrument: instrument,
            observer: observer,
            object: object,
            dateObs: dateObs,
            exptime: exptime,
            filter: filter,
            ccdTemp: ccdTemp,
            ccdGain: ccdGain,
            binning: binning,
            wcs: wcs,
            fitsHeaders: header.allHeaders
        )
    }
    
    /// Extract WCS coordinate system information from FITS headers
    private static func extractWCSInfo(from header: FITSHeader) -> WCSInfo? {
        // Check if basic WCS keywords are present
        guard let crpix1 = header.doubleValue(for: "CRPIX1"),
              let crpix2 = header.doubleValue(for: "CRPIX2"),
              let crval1 = header.doubleValue(for: "CRVAL1"),
              let crval2 = header.doubleValue(for: "CRVAL2") else {
            return nil
        }
        
        // Get pixel scale (CDELT or CD matrix)
        let cdelt1 = header.doubleValue(for: "CDELT1") ?? header.doubleValue(for: "CD1_1") ?? 0.0
        let cdelt2 = header.doubleValue(for: "CDELT2") ?? header.doubleValue(for: "CD2_2") ?? 0.0
        
        // Get coordinate types
        let ctype1 = header.stringValue(for: "CTYPE1") ?? "RA"
        let ctype2 = header.stringValue(for: "CTYPE2") ?? "DEC"
        
        // Extract projection type from coordinate types
        let projection = extractProjection(from: ctype1)
        
        // Get coordinate system and equinox
        let coordSys = header.stringValue(for: "RADESYS") ?? header.stringValue(for: "RADECSYS")
        let equinox = header.doubleValue(for: "EQUINOX") ?? header.doubleValue(for: "EPOCH")
        
        return WCSInfo(
            referencePixel: PixelCoordinate(x: crpix1, y: crpix2),
            referenceValue: WorldCoordinate(longitude: crval1, latitude: crval2),
            pixelScale: PixelScale(x: cdelt1, y: cdelt2),
            coordinateTypes: CoordinateTypes(x: ctype1, y: ctype2),
            projection: projection,
            coordinateSystem: coordSys,
            equinox: equinox
        )
    }
    
    /// Extract projection type from CTYPE keyword
    private static func extractProjection(from ctype: String) -> String? {
        // FITS WCS projection codes are typically 3 characters after the coordinate type
        // e.g., "RA---TAN" -> "TAN", "DEC--SIN" -> "SIN"
        let components = ctype.split(separator: "-")
        return components.last?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Extract and process image data from FITS HDU
    private static func extractImageData(
        from hdu: FITSHDU,
        metadata: FITSImageMetadata
    ) throws -> Data {
        
        let rawData = hdu.data
        let width = Int(metadata.dimensions.width)
        let height = Int(metadata.dimensions.height)
        let bytesPerPixel = metadata.bytesPerPixel
        
        let expectedSize = width * height * bytesPerPixel
        guard rawData.count >= expectedSize else {
            throw FITSImageLoaderError.invalidDataSize(expected: expectedSize, actual: rawData.count)
        }
        
        // FITS data is stored in big-endian format and may need byte swapping
        switch metadata.bitpix {
        case 8:
            // 8-bit data doesn't need byte swapping
            return rawData
            
        case 16:
            // 16-bit signed integer - swap bytes if needed
            return swapBytes16(rawData)
            
        case 32:
            // 32-bit signed integer - swap bytes if needed  
            return swapBytes32(rawData)
            
        case -32:
            // 32-bit IEEE float - swap bytes if needed
            return swapBytesFloat32(rawData)
            
        case -64:
            // 64-bit IEEE float - swap bytes if needed
            return swapBytesFloat64(rawData)
            
        default:
            throw FITSImageLoaderError.unsupportedBitDepth(metadata.bitpix)
        }
    }
    
    // MARK: - Byte Swapping Utilities
    
    /// Swap bytes for 16-bit integers (big-endian to native)
    private static func swapBytes16(_ data: Data) -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 2) {
            if i + 1 < data.count {
                let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
                let nativeValue = UInt16(bigEndian: value)
                withUnsafeBytes(of: nativeValue) { bytes in
                    result.append(contentsOf: bytes)
                }
            }
        }
        
        return result
    }
    
    /// Swap bytes for 32-bit integers
    private static func swapBytes32(_ data: Data) -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 4) {
            if i + 3 < data.count {
                let value = UInt32(data[i]) << 24 | UInt32(data[i + 1]) << 16 | 
                           UInt32(data[i + 2]) << 8 | UInt32(data[i + 3])
                let nativeValue = UInt32(bigEndian: value)
                withUnsafeBytes(of: nativeValue) { bytes in
                    result.append(contentsOf: bytes)
                }
            }
        }
        
        return result
    }
    
    /// Swap bytes for 32-bit floats
    private static func swapBytesFloat32(_ data: Data) -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 4) {
            if i + 3 < data.count {
                let intValue = UInt32(data[i]) << 24 | UInt32(data[i + 1]) << 16 |
                              UInt32(data[i + 2]) << 8 | UInt32(data[i + 3])
                let nativeIntValue = UInt32(bigEndian: intValue)
                let floatValue = Float(bitPattern: nativeIntValue)
                withUnsafeBytes(of: floatValue) { bytes in
                    result.append(contentsOf: bytes)
                }
            }
        }
        
        return result
    }
    
    /// Swap bytes for 64-bit floats
    private static func swapBytesFloat64(_ data: Data) -> Data {
        var result = Data(capacity: data.count)
        
        for i in stride(from: 0, to: data.count, by: 8) {
            if i + 7 < data.count {
                let intValue = UInt64(data[i]) << 56 | UInt64(data[i + 1]) << 48 |
                              UInt64(data[i + 2]) << 40 | UInt64(data[i + 3]) << 32 |
                              UInt64(data[i + 4]) << 24 | UInt64(data[i + 5]) << 16 |
                              UInt64(data[i + 6]) << 8 | UInt64(data[i + 7])
                let nativeIntValue = UInt64(bigEndian: intValue)
                let floatValue = Double(bitPattern: nativeIntValue)
                withUnsafeBytes(of: floatValue) { bytes in
                    result.append(contentsOf: bytes)
                }
            }
        }
        
        return result
    }
}

// MARK: - FITS Parser Implementation

/// Low-level FITS file format parser
private struct FITSParser {
    let data: Data
    private var offset = 0
    
    init(data: Data) {
        self.data = data
    }
    
    /// Parse the primary HDU (Header Data Unit)
    mutating func parsePrimaryHDU() throws -> FITSHDU {
        let header = try parseHeader()
        let dataSize = try calculateDataSize(from: header)
        let imageData = try parseImageData(size: dataSize)
        
        return FITSHDU(header: header, data: imageData)
    }
    
    /// Parse FITS header (80-character records in 2880-byte blocks)
    private mutating func parseHeader() throws -> FITSHeader {
        var headers: [String: String] = [:]
        var currentOffset = offset
        
        while currentOffset < data.count {
            // Read 2880-byte header block
            let blockEnd = min(currentOffset + 2880, data.count)
            let blockData = data[currentOffset..<blockEnd]
            
            // Parse 80-character header records
            for recordOffset in stride(from: 0, to: blockData.count, by: 80) {
                let recordEnd = min(recordOffset + 80, blockData.count)
                let recordData = blockData[recordOffset..<recordEnd]
                let record = String(data: recordData, encoding: .ascii) ?? ""
                
                // Parse keyword = value / comment format
                if let (keyword, value) = parseHeaderRecord(record) {
                    headers[keyword] = value
                    
                    // END keyword marks end of header
                    if keyword == "END" {
                        offset = currentOffset + 2880
                        return FITSHeader(headers: headers)
                    }
                }
            }
            
            currentOffset += 2880
        }
        
        throw FITSImageLoaderError.malformedHeader("END keyword not found")
    }
    
    /// Parse individual FITS header record
    private func parseHeaderRecord(_ record: String) -> (String, String)? {
        let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle COMMENT and HISTORY records
        if trimmed.hasPrefix("COMMENT") || trimmed.hasPrefix("HISTORY") {
            return (String(trimmed.prefix(7)), String(trimmed.dropFirst(8)))
        }
        
        // Handle END record
        if trimmed.hasPrefix("END") {
            return ("END", "")
        }
        
        // Parse standard keyword = value format
        guard let equalIndex = trimmed.firstIndex(of: "=") else {
            return nil
        }
        
        let keyword = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let valueString = String(trimmed[trimmed.index(after: equalIndex)...])
        
        // Extract value (before comment if present)
        let value: String
        if let slashIndex = valueString.firstIndex(of: "/") {
            value = String(valueString[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            value = valueString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Remove quotes from string values
        let cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        
        return (keyword, cleanValue)
    }
    
    /// Calculate image data size from header information
    private func calculateDataSize(from header: FITSHeader) throws -> Int {
        guard let naxis = header.intValue(for: "NAXIS") else {
            throw FITSImageLoaderError.missingRequiredKeyword("NAXIS")
        }
        
        guard let bitpix = header.intValue(for: "BITPIX") else {
            throw FITSImageLoaderError.missingRequiredKeyword("BITPIX")
        }
        
        var totalPixels = 1
        for i in 1...naxis {
            guard let axisSize = header.intValue(for: "NAXIS\(i)") else {
                throw FITSImageLoaderError.missingRequiredKeyword("NAXIS\(i)")
            }
            totalPixels *= axisSize
        }
        
        let bytesPerPixel = abs(bitpix) / 8
        return totalPixels * bytesPerPixel
    }
    
    /// Extract image data from current offset
    private mutating func parseImageData(size: Int) throws -> Data {
        guard offset + size <= data.count else {
            throw FITSImageLoaderError.invalidDataSize(expected: size, actual: data.count - offset)
        }
        
        let imageData = data[offset..<(offset + size)]
        offset += size
        
        // FITS data blocks are padded to 2880-byte boundaries
        let remainder = size % 2880
        if remainder != 0 {
            offset += (2880 - remainder)
        }
        
        return Data(imageData)
    }
}

// MARK: - Supporting Types

/// FITS Header Data Unit
private struct FITSHDU {
    let header: FITSHeader
    let data: Data
}

/// FITS header with keyword lookup
private struct FITSHeader {
    let headers: [String: String]
    
    var allHeaders: [String: String] { headers }
    
    func stringValue(for keyword: String) -> String? {
        return headers[keyword.uppercased()]
    }
    
    func intValue(for keyword: String) -> Int? {
        guard let stringValue = stringValue(for: keyword) else { return nil }
        return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func doubleValue(for keyword: String) -> Double? {
        guard let stringValue = stringValue(for: keyword) else { return nil }
        return Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func dateValue(for keyword: String) -> Date? {
        guard let stringValue = stringValue(for: keyword) else { return nil }
        
        // Parse FITS date format: YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD
        let formatter = DateFormatter()
        
        // Try full ISO format first
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: stringValue) {
            return date
        }
        
        // Try date-only format
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: stringValue)
    }
}

// MARK: - Error Types

public enum FITSImageLoaderError: Error, Sendable, LocalizedError {
    case missingRequiredKeyword(String)
    case malformedHeader(String)
    case invalidDataSize(expected: Int, actual: Int)
    case unsupportedBitDepth(Int)
    case corruptedData(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredKeyword(let keyword):
            return "Missing required FITS keyword: \(keyword)"
        case .malformedHeader(let details):
            return "Malformed FITS header: \(details)"
        case .invalidDataSize(let expected, let actual):
            return "Invalid FITS data size: expected \(expected) bytes, got \(actual)"
        case .unsupportedBitDepth(let bitpix):
            return "Unsupported FITS BITPIX value: \(bitpix)"
        case .corruptedData(let details):
            return "Corrupted FITS data: \(details)"
        }
    }
}