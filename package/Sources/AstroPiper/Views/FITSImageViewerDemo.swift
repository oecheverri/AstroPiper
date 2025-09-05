import SwiftUI
import AstroPiperCore

/// Comprehensive demonstration of FITS-aware astronomical imaging capabilities
/// 
/// This view showcases the integration of all FITS-specific UI components:
/// - FITSImageViewer with coordinate tracking and metadata overlays
/// - Real-time WCS coordinate transformations
/// - Scientific analysis tools and region statistics
/// - Professional astronomical imaging workflow
@MainActor
public struct FITSImageViewerDemo: View {
    
    // MARK: - Properties
    
    /// Sample FITS images for demonstration
    @State private var selectedImageIndex: Int = 0
    
    /// Demo FITS images
    private let demoImages: [DemoFITSImage] = [
        .deepSpaceObject,
        .wideFielaSurvey,
        .planetaryNebula
    ]
    
    private var selectedImage: DemoFITSImage {
        demoImages[selectedImageIndex]
    }
    
    // MARK: - View Body
    
    public var body: some View {
        NavigationView {
            // Sidebar with image selection
            sidebar
            
            // Main FITS viewer
            FITSImageViewer(image: selectedImage.astroImage)
                .navigationTitle("FITS Astronomical Viewer")
                .navigationSubtitle(selectedImage.title)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        demoToolbar
                    }
                }
        }
        .navigationViewStyle(.columns)
        .preferredColorScheme(.dark) // Optimal for astronomy
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var sidebar: some View {
        List {
            Section("Demo Images") {
                ForEach(Array(demoImages.enumerated()), id: \.offset) { index, image in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(image.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(image.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            HStack {
                                if image.hasWCS {
                                    Label("WCS", systemImage: "globe")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("\(image.dimensions)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .background(selectedImageIndex == index ? .selection : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Section("Features") {
                featuresList
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 250)
    }
    
    @ViewBuilder
    private var featuresList: some View {
        Label("Real-time Coordinates", systemImage: "location")
            .foregroundColor(.blue)
        
        Label("WCS Transformations", systemImage: "globe")
            .foregroundColor(.green)
        
        Label("Metadata Inspector", systemImage: "info.circle")
            .foregroundColor(.orange)
        
        Label("Scientific Analysis", systemImage: "chart.bar")
            .foregroundColor(.purple)
        
        Label("Region Statistics", systemImage: "viewfinder")
            .foregroundColor(.red)
        
        Label("FITS Header Browser", systemImage: "doc.text")
            .foregroundColor(.cyan)
    }
    
    // MARK: - Toolbar
    
    @ViewBuilder
    private var demoToolbar: some View {
        Menu {
            ForEach(Array(demoImages.enumerated()), id: \.offset) { index, image in
                Button {
                    selectedImageIndex = index
                } label: {
                    Text(image.title)
                }
            }
        } label: {
            Image(systemName: "photo.stack")
        }
        
        Button {
            // Export current analysis
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help("Export analysis data")
        
        Button {
            // Reset view
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Reset view")
    }
}

// MARK: - Demo Data

private enum DemoFITSImage {
    case deepSpaceObject
    case wideFielaSurvey
    case planetaryNebula
    
    var title: String {
        switch self {
        case .deepSpaceObject: return "IC 2087 (Helix Nebula)"
        case .wideFielaSurvey: return "Wide Field Survey"
        case .planetaryNebula: return "M57 (Ring Nebula)"
        }
    }
    
    var description: String {
        switch self {
        case .deepSpaceObject: 
            return "300s Luminance exposure with full WCS calibration and scientific metadata"
        case .wideFielaSurvey: 
            return "60s survey image with astrometric solution covering 2.5° field"
        case .planetaryNebula: 
            return "High-resolution planetary nebula with narrow-band filtering"
        }
    }
    
    var dimensions: String {
        switch self {
        case .deepSpaceObject: return "3008×3008"
        case .wideFielaSurvey: return "4096×4096"  
        case .planetaryNebula: return "2048×2048"
        }
    }
    
    var hasWCS: Bool {
        switch self {
        case .deepSpaceObject, .wideFielaSurvey: return true
        case .planetaryNebula: return false
        }
    }
    
    var astroImage: any AstroImage {
        switch self {
        case .deepSpaceObject:
            return createDeepSpaceImage()
        case .wideFielaSurvey:
            return createWideFielImage()
        case .planetaryNebula:
            return createPlanetaryNebulaImage()
        }
    }
    
    private func createDeepSpaceImage() -> any AstroImage {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 1504, y: 1504),
            referenceValue: WorldCoordinate(longitude: 312.25, latitude: -21.08), // Helix Nebula coordinates
            pixelScale: PixelScale(x: -0.001, y: 0.001), // 3.6 arcsec/pixel
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            coordinateSystem: "ICRS",
            equinox: 2000.0
        )
        
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [3008, 3008],
            bitpix: 16,
            bzero: 32768,
            bscale: 1.0,
            filename: "Light_IC2087_300s_Lum_001.fit",
            fileSize: 18_098_304, // ~18MB
            creationDate: Date().addingTimeInterval(-86400), // Yesterday
            telescope: "Celestron EdgeHD 14",
            instrument: "QSI 683wsg-8",
            observer: "Professional Astronomer",
            object: "IC 2087 (Helix Nebula)",
            dateObs: Date().addingTimeInterval(-90000), // ~25 hours ago
            exptime: 300.0,
            filter: "Luminance",
            ccdTemp: -15.0,
            ccdGain: 0.13,
            binning: ImageBinning(x: 1, y: 1),
            wcs: wcs,
            fitsHeaders: [
                "TELESCOP": "Celestron EdgeHD 14",
                "INSTRUME": "QSI 683wsg-8",
                "OBJECT": "IC 2087",
                "EXPTIME": "300.0",
                "CCD-TEMP": "-15.0",
                "GAIN": "0.13",
                "FILTER": "Luminance",
                "OBSERVAT": "Private Observatory",
                "SITE": "Dark Sky Site",
                "AIRMASS": "1.12",
                "SEEING": "2.1",
                "MOONPHSE": "0.23"
            ]
        )
        
        return DemoAstroImage(metadata: metadata)
    }
    
    private func createWideFielImage() -> any AstroImage {
        let wcs = WCSInfo(
            referencePixel: PixelCoordinate(x: 2048, y: 2048),
            referenceValue: WorldCoordinate(longitude: 45.0, latitude: 0.0),
            pixelScale: PixelScale(x: -0.0025, y: 0.0025), // 9 arcsec/pixel for wide field
            coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
            projection: "TAN",
            coordinateSystem: "ICRS",
            equinox: 2000.0
        )
        
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [4096, 4096],
            bitpix: 16,
            bzero: 32768,
            bscale: 1.0,
            filename: "Survey_Field_001.fit",
            telescope: "Canon 200mm f/2.8L",
            instrument: "Canon EOS Ra",
            object: "Survey Field #001",
            exptime: 60.0,
            filter: "Red",
            wcs: wcs,
            fitsHeaders: [
                "TELESCOP": "Canon 200mm f/2.8L",
                "INSTRUME": "Canon EOS Ra",
                "OBJECT": "Survey Field #001",
                "EXPTIME": "60.0",
                "ISO": "1600"
            ]
        )
        
        return DemoAstroImage(metadata: metadata)
    }
    
    private func createPlanetaryNebulaImage() -> any AstroImage {
        let metadata = FITSImageMetadata(
            naxis: 2,
            axisSizes: [2048, 2048],
            bitpix: 16,
            bzero: 32768,
            bscale: 1.0,
            filename: "M57_OIII_180s.fit",
            telescope: "Takahashi FSQ-106ED",
            instrument: "ZWO ASI2600MM-Pro",
            object: "M57 (Ring Nebula)",
            exptime: 180.0,
            filter: "OIII",
            ccdTemp: -10.0,
            fitsHeaders: [
                "TELESCOP": "Takahashi FSQ-106ED",
                "INSTRUME": "ZWO ASI2600MM-Pro",
                "OBJECT": "M57",
                "EXPTIME": "180.0",
                "CCD-TEMP": "-10.0",
                "FILTER": "OIII",
                "FOCALLEN": "530",
                "APTDIA": "106"
            ]
        )
        
        return DemoAstroImage(metadata: metadata)
    }
}

// MARK: - Demo Image Implementation

private struct DemoAstroImage: AstroImage {
    let fitsMetadata: FITSImageMetadata
    
    var metadata: any AstroImageMetadata { fitsMetadata }
    
    init(metadata: FITSImageMetadata) {
        self.fitsMetadata = metadata
    }
    
    func pixelData(in region: PixelRegion?) async throws -> Data {
        // Generate realistic astronomical image data
        let width = region?.width ?? fitsMetadata.dimensions.width
        let height = region?.height ?? fitsMetadata.dimensions.height
        let totalPixels = Int(width * height) * 3 // RGB for display
        
        var data = Data(capacity: totalPixels)
        
        // Create a gradient with noise to simulate astronomical data
        for y in 0..<Int(height) {
            for x in 0..<Int(width) {
                let centerX = Double(width) / 2
                let centerY = Double(height) / 2
                let distance = sqrt(pow(Double(x) - centerX, 2) + pow(Double(y) - centerY, 2))
                let maxDistance = sqrt(centerX * centerX + centerY * centerY)
                
                // Create a radial gradient with noise
                var intensity = 1.0 - (distance / maxDistance)
                intensity = max(0.1, min(0.9, intensity))
                
                // Add noise
                let noise = Double.random(in: -0.1...0.1)
                intensity = max(0, min(1, intensity + noise))
                
                let pixelValue = UInt8(intensity * 255)
                
                // RGB values (monochrome astronomical image)
                data.append(pixelValue)
                data.append(pixelValue)
                data.append(pixelValue)
            }
        }
        
        return data
    }
    
    func generateHistogram() async throws -> HistogramData {
        // Generate realistic histogram data
        let imageSize = Int(fitsMetadata.dimensions.width * fitsMetadata.dimensions.height)
        var pixelValues: [UInt16] = []
        pixelValues.reserveCapacity(imageSize)
        
        // Create histogram with typical astronomical distribution
        for _ in 0..<imageSize {
            // Most pixels are in background with some bright features
            let random = Double.random(in: 0...1)
            let pixelValue: UInt16
            
            if random < 0.8 {
                // Background pixels (low values with noise)
                pixelValue = UInt16.random(in: 31000...34000)
            } else if random < 0.95 {
                // Mid-range pixels (stars and nebula)
                pixelValue = UInt16.random(in: 35000...50000)
            } else {
                // Bright pixels (star cores)
                pixelValue = UInt16.random(in: 50000...65535)
            }
            
            pixelValues.append(pixelValue)
        }
        
        return HistogramData(pixelValues: pixelValues, bitDepth: 16)
    }
    
    func supportsBayerDemosaic() -> Bool { false }
    
    func demosaicedImage(bayerPattern: BayerPattern) async throws -> any AstroImage {
        throw AstroImageError.demosaicNotSupported
    }
}

// MARK: - Preview Support

#Preview("FITS Viewer Demo") {
    FITSImageViewerDemo()
        .frame(width: 1200, height: 800)
}