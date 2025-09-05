# AstroPiper - Comprehensive Astrophoto Viewing Application Implementation Plan

## Architecture Overview
Building a cross-platform (iOS/macOS) astrophoto viewer with these key principles:
- **Protocol-oriented design** for image format abstraction
- **POD types** (Sendable, Codable, Equatable) for all image representations
- **Swift Package-centric** architecture with minimal Xcode app shim
- **Native-only** implementation using Foundation, SwiftUI, Core Image, and ImageIO
- **TDD methodology** with behavior-focused testing

## Agent Delegation Strategy - "The Super Team"

### Research & Analysis Phase
- **Research Agent**: Study FITS/XISF specifications, Swift image processing patterns, astrophotography algorithms
- **Code Analysis Agent**: Examine current project structure, identify integration points, analyze existing patterns
- **Task Management Agent**: Break down complex features into atomic, testable units

### Development Phase (TDD Cycle)
1. **Task Management Agent**: Plan test scenarios and implementation steps
2. **File Management Agent**: Write failing tests first, then implement features
3. **Development Workflow Agent**: Run tests, ensure builds pass on both platforms
4. **Master Code Reviewer Agent**: Review architecture decisions and code quality
5. **Git Operations Agent**: Create atomic commits for each complete feature

### Quality Assurance Phase
- **Master Code Reviewer Agent**: Comprehensive code review for maintainability
- **Development Workflow Agent**: Cross-platform testing, performance validation
- **Code Analysis Agent**: Verify adherence to "one entity per file" principle

## Core Module Structure

### AstroPiperCore (Data Layer)
**Image Format Protocols & Types:**
- `AstroImage` - Master protocol for all image representations
- `AstroImageMetadata` - Universal metadata container
- `PixelFormat` - Enum for different pixel data types
- `ColorSpace` - Support for various color spaces
- `HistogramData` - Histogram computation and storage

**File Format Implementations:**
- `FITSImage` - FITS format parser (2880-byte header blocks, keyword-value pairs)
- `XISFImage` - XISF format parser (XML headers, block-based data)
- `StandardImage` - Bridge for JPEG/PNG/TIFF via ImageIO
- `RAWImage` - Raw camera file support via ImageIO

**Image Processing Engine:**
- `HistogramProcessor` - Histogram computation and stretching algorithms
- `DebayerProcessor` - Bayer pattern demosaicing (RGGB, BGGR, GRBG, GBRG)
- `StretchProcessor` - Manual and auto-stretch implementations
- `ImageRenderer` - Convert processed data to displayable formats

### AstroPiperUI (Presentation Layer)
**Core Views:**
- `AstroImageView` - Main image display with zoom/pan
- `MetadataView` - Comprehensive metadata display
- `HistogramView` - Interactive histogram visualization
- `ControlsView` - Stretch controls and processing options

**ViewModels:**
- `AstroImageViewModel` - Main image state management (@MainActor)
- `HistogramViewModel` - Histogram processing state
- `MetadataViewModel` - Metadata presentation logic

## TDD Implementation Strategy

### Test Categories (Behavior-Focused)
1. **Protocol Compliance Tests**
   - "Image types should provide consistent metadata access"
   - "All images should support histogram generation"
   - "Bayered images should offer debayering capability"

2. **File Format Tests**
   - "FITS parser should extract correct header values"
   - "XISF parser should handle monolithic file structure"
   - "Standard formats should preserve EXIF metadata"

3. **Processing Tests**
   - "Histogram stretching should preserve image dimensions"
   - "Debayering should convert single-channel to RGB correctly"
   - "Auto-stretch should enhance dim images appropriately"

4. **UI Behavior Tests**
   - "Image view should respond to zoom gestures"
   - "Metadata panel should display all available fields"
   - "Histogram controls should update image in real-time"

## Implementation Phases with Agent Assignments

### Phase 1: Foundation & Core Protocols
**Agent Assignments:**
- **Research Agent**: Study Swift image processing best practices, Core Image integration
- **Task Management Agent**: Break down protocol design into testable components
- **File Management Agent**: Implement protocols and base types with TDD
- **Development Workflow Agent**: Set up test infrastructure for both platforms
- **Git Operations Agent**: Atomic commits for each protocol implementation

**Deliverables:**
- Core protocols (`AstroImage`, `AstroImageMetadata`)
- Basic data types (`PixelFormat`, `ColorSpace`, `HistogramData`)
- Test infrastructure setup
- Initial SwiftUI framework

### Phase 2: Standard Image Support
**Agent Assignments:**
- **Code Analysis Agent**: Analyze ImageIO capabilities and limitations
- **File Management Agent**: Implement standard format support with comprehensive tests
- **Master Code Reviewer Agent**: Review architecture for extensibility
- **Development Workflow Agent**: Validate cross-platform image loading
- **Git Operations Agent**: Commit standard image support as complete feature

**Deliverables:**
- `StandardImage` implementation
- Basic metadata extraction
- Simple image viewer UI
- Cross-platform testing framework

### Phase 3: FITS Format Implementation  
**Agent Assignments:**
- **Research Agent**: Deep dive into FITS specification details
- **Task Management Agent**: Plan FITS parser implementation steps
- **File Management Agent**: TDD implementation of FITS reader
- **Development Workflow Agent**: Test with real FITS files
- **Git Operations Agent**: Commit FITS support atomically

**Deliverables:**
- Complete FITS parser
- Header keyword extraction
- Image data array handling
- Comprehensive FITS test suite

### Phase 4: XISF Format Implementation
**Agent Assignments:**
- **Research Agent**: Study XISF XML structure and data blocks
- **Task Management Agent**: Break down XML parsing and data extraction
- **File Management Agent**: Implement XISF parser with full test coverage
- **Development Workflow Agent**: Validate with sample XISF files
- **Git Operations Agent**: Atomic commit for XISF support

**Deliverables:**
- XISF monolithic file parser
- XML header processing
- Block-based data extraction
- XISF format test coverage

### Phase 5: Image Processing Pipeline
**Agent Assignments:**
- **Research Agent**: Study debayering algorithms and histogram techniques
- **Task Management Agent**: Plan processing pipeline with performance considerations
- **File Management Agent**: Implement processors with behavior-focused tests
- **Master Code Reviewer Agent**: Review algorithms for correctness and efficiency
- **Development Workflow Agent**: Performance testing on large images
- **Git Operations Agent**: Commit each processor independently

**Deliverables:**
- `HistogramProcessor` with stretching algorithms
- `DebayerProcessor` for all Bayer patterns
- `StretchProcessor` with manual and auto modes
- Performance benchmarks and optimizations

### Phase 6: SwiftUI Interface
**Agent Assignments:**
- **Code Analysis Agent**: Analyze SwiftUI best practices for image display
- **File Management Agent**: Build responsive UI with comprehensive interaction tests
- **Development Workflow Agent**: Test touch/mouse interactions on both platforms
- **Master Code Reviewer Agent**: Review for accessibility and performance
- **Git Operations Agent**: Commit UI components individually

**Deliverables:**
- Advanced `AstroImageView` with zoom/pan
- Interactive `HistogramView`
- Comprehensive `MetadataView`
- Responsive control interfaces

### Phase 7: Integration & Polish
**Agent Assignments:**
- **Task Management Agent**: Coordinate final integration testing
- **Development Workflow Agent**: End-to-end testing across all supported formats
- **Master Code Reviewer Agent**: Final architecture and code quality review
- **Code Analysis Agent**: Verify adherence to all project principles
- **Git Operations Agent**: Final integration commits

**Deliverables:**
- Complete application integration
- Performance optimization
- Accessibility compliance
- Documentation and examples

## File Organization (One Entity Per File)
```
Sources/AstroPiperCore/
├── Protocols/
│   ├── AstroImage.swift
│   ├── AstroImageMetadata.swift
├── Models/
│   ├── PixelFormat.swift
│   ├── ColorSpace.swift
│   ├── HistogramData.swift
├── Parsers/
│   ├── FITSParser.swift
│   ├── XISFParser.swift
│   ├── StandardImageParser.swift
├── Processing/
│   ├── HistogramProcessor.swift
│   ├── DebayerProcessor.swift
│   ├── StretchProcessor.swift
└── Tests/
    ├── ImageProtocolTests.swift
    ├── FITSParserTests.swift
    ├── ProcessingTests.swift

Sources/AstroPiperUI/
├── Views/
│   ├── AstroImageView.swift
│   ├── MetadataView.swift
│   ├── HistogramView.swift
├── ViewModels/
│   ├── AstroImageViewModel.swift
│   ├── HistogramViewModel.swift
└── Tests/
    ├── ViewModelTests.swift
    ├── UIBehaviorTests.swift
```

## Technical Specifications

### Supported Formats
1. **FITS (Flexible Image Transport System)**
   - 2880-byte header blocks
   - Keyword-value pair metadata
   - Multiple data types (8/16/32-bit integers, 32/64-bit floats)
   - Multi-extension support

2. **XISF (Extensible Image Serialization Format)**
   - XML-based headers
   - Monolithic file structure (8-byte signature + header + data)
   - Block-based data organization
   - Advanced metadata support

3. **Standard Formats**
   - JPEG, PNG, TIFF via ImageIO
   - RAW camera formats via ImageIO
   - EXIF metadata preservation

### Processing Capabilities
- **Histogram Analysis**: Real-time computation for stretch operations
- **Auto-stretch Algorithms**: Percentile-based and standard deviation methods
- **Manual Stretch Controls**: Curves, levels, gamma adjustment
- **Debayering Support**: RGGB, BGGR, GRBG, GBRG pattern demosaicing

### Performance Targets
- Smooth interaction with images up to 100MP
- Sub-second loading for standard formats
- Efficient memory usage with streaming for large files
- 60fps UI interaction on supported devices

## Success Criteria
- **Cross-platform compatibility**: Identical behavior on iOS and macOS
- **Format support**: FITS, XISF, JPEG, PNG, TIFF, common RAW formats
- **Performance**: Smooth interaction with large astronomical images
- **Test coverage**: Comprehensive behavior-focused tests for all major functionality
- **Code quality**: Clean architecture reviewed by Master Code Reviewer Agent
- **Atomic development**: Each commit represents complete, compileable feature
- **Accessibility**: Full VoiceOver and Dynamic Type support
- **Documentation**: Complete API documentation and usage examples

## Development Principles
- **TDD First**: Write failing tests before implementation
- **Behavior Testing**: Focus on what the code does, not how
- **Agent Expertise**: Leverage The Super Team's specialized knowledge
- **Atomic Commits**: Each commit is self-contained and buildable
- **Protocol-Oriented**: Favor protocols over inheritance
- **Performance Aware**: Consider memory and CPU impact of all decisions
- **Cross-Platform**: Ensure identical behavior across target platforms

This plan provides a comprehensive roadmap for building a professional-grade astrophoto viewing application while maintaining high code quality standards and leveraging the full capabilities of The Super Team.