import SwiftUI
import AstroPiperCore

/// Real-time coordinate overlay for astronomical images with WCS support
/// 
/// Displays cursor position in both pixel coordinates and world coordinates (RA/Dec)
/// when WCS information is available. Provides field of view indicators, orientation
/// arrows, and angular scale references for professional astronomical analysis.
@MainActor
public struct CoordinateOverlay: View {
    
    // MARK: - Properties
    
    /// World Coordinate System information for coordinate transformations
    public let wcsInfo: WCSInfo?
    
    /// Image dimensions for coordinate calculations
    public let imageSize: CGSize
    
    /// Current cursor position in view coordinates
    public let cursorPosition: CGPoint
    
    /// Whether cursor is actively hovering over the image
    public let isCursorActive: Bool
    
    /// Current world coordinates at cursor position
    @State private var currentWorldCoords: (ra: Double?, dec: Double?) = (nil, nil)
    
    /// Current pixel coordinates at cursor position
    @State private var currentPixelCoords: (x: Double, y: Double) = (0, 0)
    
    /// Whether to show detailed coordinate information
    @State private var showDetailedInfo: Bool = false
    
    /// Pixel scale in arcseconds per pixel
    private var pixelScale: (x: Double, y: Double) {
        guard let wcs = wcsInfo else { return (0, 0) }
        return wcs.pixelScaleArcsec
    }
    
    // MARK: - Initialization
    
    /// Initialize coordinate overlay
    /// - Parameters:
    ///   - wcsInfo: World coordinate system information (nil for pixel-only mode)
    ///   - imageSize: Image dimensions in pixels
    ///   - cursorPosition: Current cursor position
    ///   - isCursorActive: Whether cursor is actively hovering
    public init(
        wcsInfo: WCSInfo?,
        imageSize: CGSize,
        cursorPosition: CGPoint = .zero,
        isCursorActive: Bool = false
    ) {
        self.wcsInfo = wcsInfo
        self.imageSize = imageSize
        self.cursorPosition = cursorPosition
        self.isCursorActive = isCursorActive
    }
    
    // MARK: - View Body
    
    public var body: some View {
        ZStack {
            // Orientation compass (top-left)
            VStack {
                HStack {
                    orientationCompass
                        .padding()
                    Spacer()
                }
                Spacer()
            }
            
            // Coordinate information panel (top-right)
            VStack {
                HStack {
                    Spacer()
                    coordinateInfoPanel
                        .padding()
                }
                Spacer()
            }
            
            // Scale reference (bottom-left)  
            VStack {
                Spacer()
                HStack {
                    scaleReference
                        .padding()
                    Spacer()
                }
            }
            
            // Field of view indicator (bottom-right)
            if wcsInfo != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        fieldOfViewInfo
                            .padding()
                    }
                }
            }
        }
        .onChange(of: cursorPosition) { _, newPosition in
            updateCoordinates(for: newPosition)
        }
        .onChange(of: isCursorActive) { _, active in
            if !active {
                currentWorldCoords = (nil, nil)
            }
        }
        .onTapGesture {
            showDetailedInfo.toggle()
        }
    }
    
    // MARK: - Coordinate Info Panel
    
    @ViewBuilder
    private var coordinateInfoPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Pixel coordinates (always available)
            HStack {
                Text("Pixel:")
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f, %.0f", currentPixelCoords.x, currentPixelCoords.y))
                    .font(.system(.body, design: .monospaced))
            }
            
            // World coordinates (WCS required)
            if let ra = currentWorldCoords.ra, let dec = currentWorldCoords.dec {
                HStack {
                    Text("RA:")
                        .foregroundColor(.secondary)
                    Text(formatRA(ra))
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("Dec:")
                        .foregroundColor(.secondary)
                    Text(formatDec(dec))
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            // Detailed info when expanded
            if showDetailedInfo {
                Divider()
                detailedCoordinateInfo
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isCursorActive ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.2), value: isCursorActive)
    }
    
    @ViewBuilder
    private var detailedCoordinateInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ra = currentWorldCoords.ra, let dec = currentWorldCoords.dec {
                HStack {
                    Text("RA (°):")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", ra))
                        .font(.system(.caption, design: .monospaced))
                }
                
                HStack {
                    Text("Dec (°):")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", dec))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            HStack {
                Text("Scale:")
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f\"/pix", pixelScale.x))
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }
    
    // MARK: - Orientation Compass
    
    @ViewBuilder
    private var orientationCompass: some View {
        VStack(spacing: 2) {
            // North arrow
            VStack(spacing: 0) {
                Image(systemName: "arrow.up")
                    .font(.caption)
                Text("N")
                    .font(.caption2)
            }
            
            HStack(spacing: 8) {
                // West arrow
                HStack(spacing: 0) {
                    Image(systemName: "arrow.left")
                        .font(.caption)
                    Text("W")
                        .font(.caption2)
                }
                
                Spacer()
                
                // East arrow
                HStack(spacing: 0) {
                    Text("E")
                        .font(.caption2)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
            }
        }
        .foregroundColor(.white)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(0.8)
    }
    
    // MARK: - Scale Reference
    
    @ViewBuilder
    private var scaleReference: some View {
        if wcsInfo != nil {
            VStack(alignment: .leading, spacing: 4) {
                // Scale bar showing angular size
                HStack {
                    Rectangle()
                        .frame(width: 60, height: 2)
                        .foregroundColor(.white)
                    
                    Text(scaleBarLabel)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Text("Angular Scale")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(0.7)
        }
    }
    
    private var scaleBarLabel: String {
        let scaleArcmin = pixelScale.x * 60.0 / 60.0 // Scale for 60 pixel bar in arcminutes
        
        if scaleArcmin >= 1.0 {
            return String(format: "%.1f'", scaleArcmin)
        } else {
            let scaleArcsec = scaleArcmin * 60.0
            return String(format: "%.0f\"", scaleArcsec)
        }
    }
    
    // MARK: - Field of View Info
    
    @ViewBuilder
    private var fieldOfViewInfo: some View {
        if let wcs = wcsInfo {
            let fov = wcs.fieldOfView(imageWidth: imageSize.width, imageHeight: imageSize.height)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Field of View")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f° × %.2f°", fov.width, fov.height))
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text(String(format: "Diagonal: %.2f°", fov.diagonal))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(0.7)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get world coordinates for a given view point
    /// - Parameter point: View coordinate point
    /// - Returns: World coordinates (RA/Dec) if WCS available
    public func worldCoordinates(for point: CGPoint) -> (ra: Double?, dec: Double?) {
        guard let wcs = wcsInfo else { return (nil, nil) }
        
        // Convert view coordinates to image pixel coordinates
        let pixelX = point.x * imageSize.width / point.x // This needs proper view-to-image scaling
        let pixelY = point.y * imageSize.height / point.y
        
        let worldCoords = wcs.worldCoordinates(for: pixelX, y: pixelY)
        return (ra: worldCoords.longitude, dec: worldCoords.latitude)
    }
    
    /// Get pixel coordinates for a given view point
    /// - Parameter point: View coordinate point
    /// - Returns: Pixel coordinates in image space
    public func pixelCoordinates(for point: CGPoint) -> (x: Double, y: Double) {
        // For now, return direct coordinates - proper scaling would be implemented based on zoom level
        return (x: point.x, y: point.y)
    }
    
    // MARK: - Private Methods
    
    /// Update coordinate displays based on cursor position
    private func updateCoordinates(for position: CGPoint) {
        guard isCursorActive else { return }
        
        // Update pixel coordinates
        currentPixelCoords = pixelCoordinates(for: position)
        
        // Update world coordinates if WCS available
        currentWorldCoords = worldCoordinates(for: position)
    }
    
    /// Format RA in hours:minutes:seconds
    private func formatRA(_ ra: Double) -> String {
        let hours = ra / 15.0 // Convert degrees to hours
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60.0)
        let s = ((hours - Double(h)) * 60.0 - Double(m)) * 60.0
        return String(format: "%02dh%02dm%04.1fs", h, m, s)
    }
    
    /// Format Dec in degrees:minutes:seconds
    internal func formatDec(_ dec: Double) -> String {
        let sign = dec >= 0 ? "+" : "-"
        let absDec = abs(dec)
        let d = Int(absDec)
        let m = Int((absDec - Double(d)) * 60.0)
        let s = ((absDec - Double(d)) * 60.0 - Double(m)) * 60.0
        return String(format: "%@%02d°%02d'%04.1f\"", sign, d, m, s)
    }
}

// MARK: - Preview Support

#Preview("Coordinate Overlay with WCS") {
    let mockWCS = WCSInfo(
        referencePixel: PixelCoordinate(x: 1500, y: 1500),
        referenceValue: WorldCoordinate(longitude: 180.0, latitude: 45.0),
        pixelScale: PixelScale(x: -0.001, y: 0.001),
        coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
        projection: "TAN"
    )
    
    return ZStack {
        Color.black
        
        CoordinateOverlay(
            wcsInfo: mockWCS,
            imageSize: CGSize(width: 3008, height: 3008),
            cursorPosition: CGPoint(x: 200, y: 150),
            isCursorActive: true
        )
    }
    .preferredColorScheme(.dark)
    .frame(width: 800, height: 600)
}

#Preview("Coordinate Overlay without WCS") {
    return ZStack {
        Color.black
        
        CoordinateOverlay(
            wcsInfo: nil,
            imageSize: CGSize(width: 1024, height: 1024),
            cursorPosition: CGPoint(x: 100, y: 200),
            isCursorActive: true
        )
    }
    .preferredColorScheme(.dark)
    .frame(width: 800, height: 600)
}