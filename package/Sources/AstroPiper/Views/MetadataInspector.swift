import SwiftUI
import AstroPiperCore

/// Comprehensive metadata inspector for FITS astronomical images
/// 
/// Provides tabbed interface for exploring different categories of FITS metadata:
/// - Observatory: Telescope, instrument, observer information
/// - Exposure: Imaging parameters, timing, temperature, gain
/// - WCS: World coordinate system and astrometric calibration
/// - Headers: Complete FITS header keyword browser with search/filter
@MainActor
public struct MetadataInspector: View {
    
    // MARK: - Properties
    
    /// FITS metadata to inspect
    public let metadata: FITSImageMetadata
    
    /// Currently selected tab
    @State public var selectedTab: TabType = .observatory
    
    /// Search text for filtering headers
    @State public var headerSearchText: String = ""
    
    /// Available tabs based on metadata content
    public var availableTabs: Set<TabType> {
        var tabs: Set<TabType> = [.observatory, .exposure, .headers]
        
        if metadata.wcs != nil {
            tabs.insert(.wcs)
        }
        
        return tabs
    }
    
    /// Filtered headers based on search text
    public var filteredHeaders: [(key: String, value: String)] {
        let headers = metadata.fitsHeaders
        
        if headerSearchText.isEmpty {
            return headers.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
        } else {
            return headers
                .filter { $0.key.localizedCaseInsensitiveContains(headerSearchText) || 
                         $0.value.localizedCaseInsensitiveContains(headerSearchText) }
                .sorted { $0.key < $1.key }
                .map { (key: $0.key, value: $0.value) }
        }
    }
    
    // MARK: - Tab Types
    
    public enum TabType: CaseIterable, Hashable {
        case observatory
        case exposure
        case wcs
        case headers
        
        var title: String {
            switch self {
            case .observatory: return "Observatory"
            case .exposure: return "Exposure"
            case .wcs: return "WCS"
            case .headers: return "Headers"
            }
        }
        
        var icon: String {
            switch self {
            case .observatory: return "telescope"
            case .exposure: return "camera"
            case .wcs: return "globe"
            case .headers: return "text.alignleft"
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize metadata inspector
    /// - Parameter metadata: FITS metadata to inspect
    public init(metadata: FITSImageMetadata) {
        self.metadata = metadata
    }
    
    // MARK: - View Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            tabSelector
            
            Divider()
            
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .observatory:
                        observatoryTab
                    case .exposure:
                        exposureTab
                    case .wcs:
                        wcsTab
                    case .headers:
                        headersTab
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 600)
    }
    
    // MARK: - Tab Selector
    
    private var sortedAvailableTabs: [TabType] {
        Array(availableTabs).sorted { tabOrder($0) < tabOrder($1) }
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(sortedAvailableTabs, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func tabButton(for tab: TabType) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.title)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTab == tab ? Color.gray.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    
    private func tabOrder(_ tab: TabType) -> Int {
        switch tab {
        case .observatory: return 0
        case .exposure: return 1
        case .wcs: return 2
        case .headers: return 3
        }
    }
    
    // MARK: - Observatory Tab
    
    @ViewBuilder
    private var observatoryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Observatory Information")
            
            infoRow("Telescope", metadata.telescope)
            infoRow("Instrument", metadata.instrument)
            infoRow("Observer", metadata.observer)
            infoRow("Object", metadata.object)
            
            if let dateObs = metadata.dateObs {
                let formatter = ISO8601DateFormatter()
                infoRow("Observation Date", formatter.string(from: dateObs))
            }
            
            // Additional observatory metadata from custom headers
            if let observatory = metadata.customValue(for: "OBSERVAT") {
                infoRow("Observatory", observatory)
            }
            
            if let site = metadata.customValue(for: "SITE") {
                infoRow("Site", site)
            }
        }
    }
    
    // MARK: - Exposure Tab
    
    @ViewBuilder
    private var exposureTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Exposure Settings")
            
            if let exptime = metadata.exptime {
                infoRow("Exposure Time", String(format: "%.1f s", exptime))
            }
            
            infoRow("Filter", metadata.filter)
            
            if let ccdTemp = metadata.ccdTemp {
                infoRow("CCD Temperature", String(format: "%.1f°C", ccdTemp))
            }
            
            if let ccdGain = metadata.ccdGain {
                infoRow("CCD Gain", String(format: "%.1f", ccdGain))
            }
            
            if let binning = metadata.binning {
                infoRow("Binning", "\(binning.horizontal)×\(binning.vertical)")
            }
            
            Divider()
            
            sectionHeader("Image Properties")
            
            infoRow("Dimensions", "\(metadata.dimensions.width) × \(metadata.dimensions.height)")
            infoRow("Bit Depth", "\(metadata.bitpix)-bit")
            
            if let bzero = metadata.bzero, let bscale = metadata.bscale {
                infoRow("BZERO", String(format: "%.0f", bzero))
                infoRow("BSCALE", String(format: "%.0f", bscale))
            }
            
            infoRow("Pixel Format", metadata.pixelFormat.description)
            infoRow("Color Space", metadata.colorSpace.description)
        }
    }
    
    // MARK: - WCS Tab
    
    @ViewBuilder
    private var wcsTab: some View {
        if let wcs = metadata.wcs {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("World Coordinate System")
                
                // Reference coordinates
                let refCoords = wcs.referenceCoordinates
                infoRow("Reference RA", String(format: "%.6f°", refCoords.rightAscension))
                infoRow("Reference Dec", String(format: "%.6f°", refCoords.declination))
                infoRow("Epoch", String(format: "%.1f", refCoords.epoch))
                
                Divider()
                
                // Pixel scale and field of view
                let pixelScale = wcs.pixelScaleArcsec
                infoRow("Pixel Scale X", String(format: "%.3f arcsec/pixel", pixelScale.x))
                infoRow("Pixel Scale Y", String(format: "%.3f arcsec/pixel", pixelScale.y))
                
                let fov = wcs.fieldOfView(
                    imageWidth: Double(metadata.dimensions.width),
                    imageHeight: Double(metadata.dimensions.height)
                )
                infoRow("Field of View", String(format: "%.3f° × %.3f°", fov.width, fov.height))
                
                Divider()
                
                // Coordinate system details
                infoRow("Projection", wcs.projection ?? "Unknown")
                infoRow("Coordinate Types", "\(wcs.coordinateTypes.x), \(wcs.coordinateTypes.y)")
                infoRow("Coordinate System", wcs.coordinateSystem ?? "Unknown")
                
                if let equinox = wcs.equinox {
                    infoRow("Equinox", String(format: "%.1f", equinox))
                }
                
                Divider()
                
                // Validation status
                sectionHeader("Validation")
                let issues = wcs.validate()
                if issues.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("WCS validation passed")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                } else {
                    ForEach(issues, id: \.self) { issue in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(issue)
                                .foregroundColor(.orange)
                        }
                        .font(.caption)
                    }
                }
            }
        } else {
            VStack {
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No WCS Information")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("This image does not contain World Coordinate System information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    // MARK: - Headers Tab
    
    @ViewBuilder
    private var headersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search headers...", text: $headerSearchText)
                    .textFieldStyle(.roundedBorder)
                
                if !headerSearchText.isEmpty {
                    Button {
                        headerSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Results count
            Text("\(filteredHeaders.count) of \(metadata.fitsHeaders.count) headers")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Headers list
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(filteredHeaders, id: \.key) { header in
                    headerRow(key: header.key, value: header.value)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let value = value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label + ":")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func headerRow(key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(key)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                Spacer()
                
                Button {
                    copyToClipboard("\(key) = \(value)")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .opacity(0.7)
            }
            
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - Utility Methods
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Extensions

extension PixelFormat {
    var description: String {
        switch self {
        case .uint8: return "8-bit unsigned"
        case .uint16: return "16-bit unsigned"
        case .uint32: return "32-bit unsigned"
        case .int16: return "16-bit signed"
        case .int32: return "32-bit signed"
        case .float32: return "32-bit float"
        case .float64: return "64-bit float"
        }
    }
}

extension ColorSpace {
    var description: String {
        switch self {
        case .sRGB: return "sRGB"
        case .displayP3: return "Display P3"
        case .grayscale: return "Grayscale"
        case .linear: return "Linear"
        case .cie1931XYZ: return "CIE 1931 XYZ"
        case .rec2020: return "Rec. 2020"
        }
    }
}

// MARK: - Preview Support

#Preview("Metadata Inspector - Observatory") {
    let mockMetadata = FITSImageMetadata(
        naxis: 2,
        axisSizes: [3008, 3008],
        bitpix: 16,
        bzero: 32768,
        bscale: 1.0,
        filename: "Light_IC2087_300s_Lum_001.fit",
        telescope: "Celestron EdgeHD 14",
        instrument: "QSI 683wsg-8",
        observer: "John Astronomer",
        object: "IC2087 (Helix Nebula)",
        dateObs: Date(),
        exptime: 300.0,
        filter: "Luminance",
        ccdTemp: -15.0,
        ccdGain: 0.13,
        binning: ImageBinning(horizontal: 1, vertical: 1),
        fitsHeaders: [
            "TELESCOP": "Celestron EdgeHD 14",
            "INSTRUME": "QSI 683wsg-8",
            "OBJECT": "IC2087",
            "EXPTIME": "300.0",
            "CCD-TEMP": "-15.0",
            "OBSERVAT": "Private Observatory",
            "SITE": "Backyard"
        ]
    )
    
    MetadataInspector(metadata: mockMetadata)
        .preferredColorScheme(.dark)
}

#Preview("Metadata Inspector - WCS") {
    let mockWCS = WCSInfo(
        referencePixel: PixelCoordinate(x: 1504, y: 1504),
        referenceValue: WorldCoordinate(longitude: 312.25, latitude: -21.08),
        pixelScale: PixelScale(x: -0.001, y: 0.001),
        coordinateTypes: CoordinateTypes(x: "RA---TAN", y: "DEC--TAN"),
        projection: "TAN",
        coordinateSystem: "ICRS",
        equinox: 2000.0
    )
    
    let mockMetadata = FITSImageMetadata(
        naxis: 2,
        axisSizes: [3008, 3008],
        bitpix: 16,
        filename: "test_wcs.fit",
        wcs: mockWCS
    )
    
    MetadataInspector(metadata: mockMetadata)
        .preferredColorScheme(.dark)
        .onAppear {
            // Start with WCS tab selected in preview
        }
}