import SwiftUI
import AstroPiperCore

/// Cross-platform astronomical image viewer with zoom and pan capabilities
/// 
/// Provides a unified viewing experience for astronomical images across iOS and macOS,
/// supporting gesture-based zoom, pan, and fit-to-screen functionality.
@MainActor
public struct ImageViewer: View {
    
    // MARK: - Properties
    
    /// The astronomical image to display
    public let image: (any AstroImage)?
    
    /// Current zoom scale state
    @State public var currentZoomScale: Double = 1.0
    
    /// Minimum allowable zoom scale  
    public let minZoomScale: Double = 0.1
    
    /// Maximum allowable zoom scale
    public let maxZoomScale: Double = 5.0
    
    /// Loading state for async image operations
    @State public var isLoading: Bool = false
    
    /// Current image representation for display
    @State private var displayImage: Image?
    
    /// Error state for image loading failures
    @State private var loadError: Error?
    
    // MARK: - Initialization
    
    /// Initialize the image viewer with an astronomical image
    /// - Parameter image: The AstroImage to display, or nil for loading state
    public init(image: (any AstroImage)?) {
        self.image = image
        self.isLoading = image == nil
    }
    
    // MARK: - View Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if isLoading && image == nil {
                    ProgressView("Loading image...")
                        .foregroundColor(.white)
                } else if let loadError = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Failed to load image")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(loadError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let displayImage = displayImage {
                    ZoomableScrollView(
                        minZoomScale: minZoomScale,
                        maxZoomScale: maxZoomScale,
                        currentZoomScale: $currentZoomScale
                    ) {
                        displayImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                } else {
                    Text("No image available")
                        .foregroundColor(.gray)
                }
            }
        }
        .task {
            await loadImageForDisplay()
        }
        .onAppear {
            if displayImage == nil && image != nil {
                Task {
                    await loadImageForDisplay()
                }
            }
        }
    }
    
    // MARK: - Image Loading
    
    /// Load and prepare the astronomical image for display
    private func loadImageForDisplay() async {
        guard let image = image else {
            isLoading = false
            return
        }
        
        isLoading = true
        loadError = nil
        
        do {
            // Extract pixel data for the full image
            let pixelData = try await image.pixelData(in: nil)
            let metadata = image.metadata
            
            // Convert to displayable image
            let cgImage = try createCGImage(
                from: pixelData,
                width: Int(metadata.dimensions.width),
                height: Int(metadata.dimensions.height)
            )
            
            displayImage = Image(cgImage, scale: 1.0, label: Text("Astronomical Image"))
            currentZoomScale = 1.0
            
        } catch {
            loadError = error
            displayImage = nil
        }
        
        isLoading = false
    }
    
    /// Create a CGImage from raw pixel data
    /// - Parameters:
    ///   - pixelData: Raw RGB pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    /// - Returns: CGImage for display
    /// - Throws: ImageViewerError for conversion failures
    private func createCGImage(from pixelData: Data, width: Int, height: Int) throws -> CGImage {
        let bytesPerPixel = 3 // RGB
        let expectedSize = width * height * bytesPerPixel
        
        guard pixelData.count >= expectedSize else {
            throw ImageViewerError.invalidPixelData("Expected \(expectedSize) bytes, got \(pixelData.count)")
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        return pixelData.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                fatalError("Could not get base address of pixel data")
            }
            
            guard let provider = CGDataProvider(dataInfo: nil, data: baseAddress, size: pixelData.count, releaseData: { _, _, _ in }) else {
                fatalError("Could not create CGDataProvider")
            }
            
            guard let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: width * bytesPerPixel,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) else {
                fatalError("Could not create CGImage from pixel data")
            }
            
            return cgImage
        }
    }
    
    // MARK: - Utility Functions
    
    /// Calculate the scale needed to fit the image within the given view size
    /// - Parameter viewSize: Available view dimensions
    /// - Returns: Scale factor for fit-to-screen display
    public func calculateFitToScreenScale(viewSize: CGSize) -> Double {
        guard let image = image else { return 1.0 }
        
        let metadata = image.metadata
        let imageWidth = Double(metadata.dimensions.width)
        let imageHeight = Double(metadata.dimensions.height)
        
        let widthScale = viewSize.width / imageWidth
        let heightScale = viewSize.height / imageHeight
        
        return min(widthScale, heightScale)
    }
}

// MARK: - Supporting Views

/// Cross-platform zoomable scroll view for image viewing
public struct ZoomableScrollView<Content: View>: View {
    
    // MARK: - Properties
    
    /// Minimum zoom scale
    public let minZoomScale: Double
    
    /// Maximum zoom scale  
    public let maxZoomScale: Double
    
    /// Current zoom scale binding
    @Binding public var currentZoomScale: Double
    
    /// Content to display within the scrollable area
    private let content: Content
    
    // MARK: - Platform-specific State
    
    #if os(iOS)
    @State private var offset: CGSize = .zero
    @State private var scale: Double = 1.0
    #endif
    
    // MARK: - Initialization
    
    /// Initialize zoomable scroll view
    /// - Parameters:
    ///   - minZoomScale: Minimum allowed zoom scale
    ///   - maxZoomScale: Maximum allowed zoom scale 
    ///   - currentZoomScale: Binding to current zoom scale
    ///   - content: View content to make zoomable
    public init(
        minZoomScale: Double = 0.1,
        maxZoomScale: Double = 5.0,
        currentZoomScale: Binding<Double> = .constant(1.0),
        @ViewBuilder content: () -> Content
    ) {
        self.minZoomScale = minZoomScale
        self.maxZoomScale = maxZoomScale
        self._currentZoomScale = currentZoomScale
        self.content = content()
    }
    
    // MARK: - View Body
    
    public var body: some View {
        #if os(macOS)
        // macOS: Use native ScrollView with zoom gestures
        ScrollView([.horizontal, .vertical]) {
            content
                .scaleEffect(currentZoomScale)
                .onAppear {
                    currentZoomScale = max(minZoomScale, min(maxZoomScale, currentZoomScale))
                }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = currentZoomScale * value
                    currentZoomScale = max(minZoomScale, min(maxZoomScale, newScale))
                }
        )
        #else
        // iOS: Use gesture-based zoom and pan
        GeometryReader { geometry in
            content
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        // Magnification gesture for zooming
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = scale * value
                                scale = max(minZoomScale, min(maxZoomScale, newScale))
                                currentZoomScale = scale
                            },
                        
                        // Drag gesture for panning
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                            }
                            .onEnded { _ in
                                // Constrain offset to keep content visible
                                constrainOffset(in: geometry)
                            }
                    )
                )
                .onAppear {
                    scale = max(minZoomScale, min(maxZoomScale, currentZoomScale))
                }
        }
        #endif
    }
    
    #if os(iOS)
    /// Constrain the pan offset to keep content within reasonable bounds
    /// - Parameter geometry: Available geometry for bounds calculation
    private func constrainOffset(in geometry: GeometryProxy) {
        let maxOffset = CGSize(
            width: geometry.size.width * 0.5,
            height: geometry.size.height * 0.5
        )
        
        offset = CGSize(
            width: max(-maxOffset.width, min(maxOffset.width, offset.width)),
            height: max(-maxOffset.height, min(maxOffset.height, offset.height))
        )
    }
    #endif
}

// MARK: - Error Types

public enum ImageViewerError: Error, LocalizedError {
    case invalidPixelData(String)
    case imageConversionFailed
    case unsupportedFormat
    
    public var errorDescription: String? {
        switch self {
        case .invalidPixelData(let details):
            return "Invalid pixel data: \(details)"
        case .imageConversionFailed:
            return "Failed to convert image data for display"
        case .unsupportedFormat:
            return "Unsupported image format for display"
        }
    }
}