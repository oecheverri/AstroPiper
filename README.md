# AstroPiper 🌟

A comprehensive astrophotography viewing application for iOS and macOS, designed to handle professional astronomical image formats with advanced processing capabilities.

## Features

### 🖼️ Universal Image Support
- **FITS Format**: Full support for Flexible Image Transport System files
- **XISF Format**: Extensible Image Serialization Format compatibility  
- **Standard Formats**: JPEG, PNG, TIFF, and RAW camera files
- **Protocol-Oriented**: Consistent interface across all image types

### 🔬 Advanced Processing
- **Histogram Analysis**: Real-time computation and visualization
- **Auto-Stretch**: Intelligent histogram stretching for dim images
- **Manual Controls**: Precise curve, level, and gamma adjustments
- **Debayering**: On-demand color interpolation from Bayer patterns

### 📱 Cross-Platform UI
- **SwiftUI Interface**: Native experience on both iOS and macOS
- **Responsive Design**: Adapts to different screen sizes and orientations
- **Touch & Mouse**: Full support for both interaction methods
- **Accessibility**: Complete VoiceOver and Dynamic Type support

### 📊 Metadata Display
- **Comprehensive Views**: All available image metadata
- **Format-Specific**: Specialized displays for FITS keywords and XISF properties
- **EXIF Support**: Standard camera metadata for conventional images

## Architecture

### Swift Package Structure
```
AstroPiperKit/
├── AstroPiperCore/     # Data models and processing
│   ├── Protocols/      # Image abstraction layer
│   ├── Parsers/        # File format implementations
│   ├── Processing/     # Image analysis and manipulation
│   └── Models/         # Data types and structures
└── AstroPiperUI/       # User interface components
    ├── Views/          # SwiftUI interface elements
    └── ViewModels/     # State management (@MainActor)
```

### Design Principles
- **Protocol-Oriented**: Clean abstraction between formats
- **Value Semantics**: POD types (Sendable, Codable, Equatable)
- **Test-Driven**: Comprehensive behavior-focused testing
- **Performance-First**: Optimized for large astronomical images
- **One Entity Per File**: Clean, maintainable code organization

## Requirements

- **iOS**: 18.0+ / **macOS**: 15.0+
- **Swift**: 6.0+
- **Xcode**: 16.0+

## Installation

### Development Setup
1. Clone the repository
2. Open `app/AstroPiper.xcodeproj` in Xcode
3. Build and run for your target platform

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AstroPiper.git", from: "1.0.0")
]
```

## Usage

### Basic Image Loading
```swift
import AstroPiperCore

// Universal image loading
let image = try await AstroImageLoader.load(from: url)

// Access metadata
print("Dimensions: \\(image.dimensions)")
print("Pixel Format: \\(image.pixelFormat)")
print("Is Bayered: \\(image.isBayered)")

// Generate histogram
let histogram = await image.histogram()
```

### Processing Pipeline
```swift
// Debayer if needed
let processed = await image.isBayered ? 
    await image.debayeredImage() ?? image : image

// Apply histogram stretch
let stretched = await StretchProcessor.autoStretch(processed)
```

### SwiftUI Integration
```swift
import AstroPiperUI

struct ContentView: View {
    var body: some View {
        AstroImageView(image: astroImage)
            .overlay(alignment: .trailing) {
                MetadataView(metadata: astroImage.metadata)
            }
    }
}
```

## Supported Formats

### FITS (Flexible Image Transport System)
- 2880-byte header blocks with keyword-value metadata
- Multiple data types: 8/16/32-bit integers, 32/64-bit floats  
- Multi-extension file support
- Full astronomical metadata preservation

### XISF (Extensible Image Serialization Format)
- XML-based header structure
- Monolithic file organization
- Advanced property and metadata system
- Efficient block-based data storage

### Standard Image Formats
- JPEG, PNG, TIFF via ImageIO
- RAW camera formats (CR2, NEF, ARW, etc.)
- EXIF metadata extraction and display
- Color space and ICC profile support

## Development

### Test-Driven Development
All features are developed using TDD methodology with behavior-focused tests:

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter AstroPiperCoreTests
```

### Building
```bash
# Build for all platforms
swift build

# Build iOS app
cd app && xcodebuild -scheme AstroPiper -destination 'generic/platform=iOS'

# Build macOS app  
cd app && xcodebuild -scheme AstroPiper -destination 'generic/platform=macOS'
```

## Performance

### Optimizations
- **Streaming**: Large files loaded incrementally
- **Tiled Rendering**: Efficient display of high-resolution images
- **Background Processing**: Heavy operations off main thread
- **Memory Management**: Careful resource cleanup

### Benchmarks
- Supports images up to 100MP smoothly
- Sub-second loading for standard formats
- Real-time histogram computation
- 60fps UI interactions

## Contributing

1. **Fork** the repository
2. **Create** a feature branch following TDD principles
3. **Write** tests before implementation
4. **Ensure** cross-platform compatibility
5. **Submit** a pull request with atomic commits

### Code Style
- Follow Swift conventions and idioms
- One primary entity per file
- Comprehensive documentation for public APIs
- Prefer value types and protocol-oriented design

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- **FITS Standard**: [International Astronomical Union](https://fits.gsfc.nasa.gov/)
- **XISF Specification**: [PixInsight Development Team](https://pixinsight.com/)
- **Swift Community**: For excellent cross-platform frameworks

## Roadmap

### Version 1.0
- [x] Core architecture and protocols
- [x] FITS format support
- [x] XISF format support  
- [x] Basic processing pipeline
- [x] Cross-platform UI

### Version 1.1
- [ ] Advanced stretch algorithms
- [ ] Batch processing capabilities
- [ ] Image comparison tools
- [ ] Export functionality

### Version 2.0
- [ ] Image stacking support
- [ ] Advanced calibration tools
- [ ] Plugin architecture
- [ ] Cloud storage integration

---

Built with ❤️ for the astrophotography community