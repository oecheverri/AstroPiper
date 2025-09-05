import SwiftUI
import AstroPiperCore

/// Enhanced astronomical image viewer specifically designed for FITS format files
/// 
/// Provides professional-grade features for astronomical imaging including:
/// - Real-time coordinate tracking with WCS support
/// - Scientific metadata inspection and display
/// - Raw vs. calibrated pixel value analysis
/// - Region-based statistics and measurements
/// - Export capabilities for processed data
@MainActor
public struct FITSImageViewer: View {
    
    // MARK: - Properties
    
    /// The FITS astronomical image to display
    public let image: (any AstroImage)?
    
    /// FITS-specific metadata extracted from the image
    @State public private(set) var fitsMetadata: FITSImageMetadata?
    
    /// Whether this image has World Coordinate System information
    @State public private(set) var hasWCSInfo: Bool = false
    
    /// Control visibility of metadata overlay panel
    @State public var showMetadataOverlay: Bool = false
    
    /// Control visibility of coordinate overlay
    @State public var showCoordinateOverlay: Bool = true
    
    /// Control visibility of scientific controls panel
    @State public var showScientificControls: Bool = false
    
    /// Current cursor position for coordinate tracking
    @State private var cursorPosition: CGPoint = .zero
    
    /// Whether cursor is actively hovering over image
    @State private var isCursorActive: Bool = false
    
    /// Base image viewer for core functionality
    @State private var baseImageViewer: ImageViewer
    
    // MARK: - Initialization
    
    /// Initialize FITS image viewer with an astronomical image
    /// - Parameter image: The AstroImage to display (must contain FITSImageMetadata)
    public init(image: (any AstroImage)?) {
        self.image = image
        self._baseImageViewer = State(initialValue: ImageViewer(image: image))
    }
    
    // MARK: - View Body
    
    public var body: some View {
        ZStack {
            // Base image viewer
            baseImageViewer
                .onAppear {
                    setupFITSMetadata()
                }
                .onChange(of: image) { _, newImage in
                    baseImageViewer = ImageViewer(image: newImage)
                    setupFITSMetadata()
                }
            
            // Coordinate overlay (when WCS available and enabled)
            if showCoordinateOverlay, let wcsInfo = fitsMetadata?.wcs {
                CoordinateOverlay(
                    wcsInfo: wcsInfo,
                    imageSize: CGSize(
                        width: Double(fitsMetadata?.dimensions.width ?? 0),
                        height: Double(fitsMetadata?.dimensions.height ?? 0)
                    ),
                    cursorPosition: cursorPosition,
                    isCursorActive: isCursorActive
                )
            }
            
            // Metadata inspector panel
            if showMetadataOverlay, let metadata = fitsMetadata {
                HStack {
                    Spacer()
                    MetadataInspector(metadata: metadata)
                        .frame(maxWidth: 400)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            
            // Scientific controls panel
            if showScientificControls, let astroImage = image {
                VStack {
                    Spacer()
                    ScientificControls(image: astroImage)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            
            // Control toolbar
            VStack {
                HStack {
                    fitsControlToolbar
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                cursorPosition = location
                isCursorActive = true
            case .ended:
                isCursorActive = false
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Control Toolbar
    
    @ViewBuilder
    private var fitsControlToolbar: some View {
        HStack(spacing: 12) {
            // Metadata overlay toggle
            Button {
                toggleMetadataOverlay()
            } label: {
                Image(systemName: showMetadataOverlay ? "info.circle.fill" : "info.circle")
                    .font(.title2)
            }
            .help("Toggle metadata inspector")
            .buttonStyle(.borderless)
            
            // Coordinate overlay toggle (only show if WCS available)
            if hasWCSInfo {
                Button {
                    showCoordinateOverlay.toggle()
                } label: {
                    Image(systemName: showCoordinateOverlay ? "location.circle.fill" : "location.circle")
                        .font(.title2)
                }
                .help("Toggle coordinate overlay")
                .buttonStyle(.borderless)
            }
            
            // Scientific controls toggle
            Button {
                showScientificControls.toggle()
            } label: {
                Image(systemName: showScientificControls ? "chart.bar.fill" : "chart.bar")
                    .font(.title2)
            }
            .help("Toggle scientific analysis tools")
            .buttonStyle(.borderless)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    // MARK: - Public Methods
    
    /// Toggle the metadata overlay visibility
    public func toggleMetadataOverlay() {
        showMetadataOverlay.toggle()
    }
    
    /// Toggle the coordinate overlay visibility  
    public func toggleCoordinateOverlay() {
        showCoordinateOverlay.toggle()
    }
    
    /// Toggle the scientific controls visibility
    public func toggleScientificControls() {
        showScientificControls.toggle()
    }
    
    // MARK: - Private Methods
    
    /// Extract and setup FITS-specific metadata from the image
    private func setupFITSMetadata() {
        guard let image = image else {
            fitsMetadata = nil
            hasWCSInfo = false
            return
        }
        
        if let fits = image.metadata as? FITSImageMetadata {
            fitsMetadata = fits
            hasWCSInfo = fits.wcs != nil
        } else {
            fitsMetadata = nil
            hasWCSInfo = false
        }
    }
}

// MARK: - Preview Support

#Preview("FITS Viewer with WCS") {
    let mockWCS = WCSInfo(
        referencePixel: PixelCoordinate(x: 1500, y: 1500),
        referenceValue: WorldCoordinate(longitude: 180.0, latitude: 45.0),
        pixelScale: PixelScale(x: -0.001, y: 0.001),
        coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
        projection: "TAN"
    )
    
    let mockMetadata = FITSImageMetadata(
        naxis: 2,
        axisSizes: [3008, 3008],
        bitpix: 16,
        bzero: 32768,
        bscale: 1.0,
        filename: "Light_IC2087_300s_Lum_001.fit",
        telescope: "EdgeHD 14",
        instrument: "QSI 683wsg",
        observer: "Test Observer",
        object: "IC2087",
        exptime: 300.0,
        filter: "Luminance",
        ccdTemp: -15.0,
        wcs: mockWCS,
        fitsHeaders: [
            "TELESCOP": "EdgeHD 14",
            "INSTRUME": "QSI 683wsg", 
            "OBJECT": "IC2087",
            "EXPTIME": "300.0",
            "CCD-TEMP": "-15.0"
        ]
    )
    
    let mockImage = PreviewFITSImage(metadata: mockMetadata)
    
    return FITSImageViewer(image: mockImage)
        .preferredColorScheme(.dark)
}

#Preview("FITS Viewer without WCS") {
    let mockMetadata = FITSImageMetadata(
        naxis: 2,
        axisSizes: [1024, 1024],
        bitpix: 16,
        filename: "test.fit",
        telescope: "Test Telescope",
        instrument: "Test Camera",
        object: "Test Object",
        exptime: 120.0
    )
    
    let mockImage = PreviewFITSImage(metadata: mockMetadata)
    
    return FITSImageViewer(image: mockImage)
        .preferredColorScheme(.dark)
}

// MARK: - Preview Helpers

private struct PreviewFITSImage: AstroImage {
    let fitsMetadata: FITSImageMetadata
    
    var metadata: any AstroImageMetadata { fitsMetadata }
    
    init(metadata: FITSImageMetadata) {
        self.fitsMetadata = metadata
    }
    
    func pixelData(in region: PixelRegion?) async throws -> Data {
        // Generate preview data
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