//
//  ContentView.swift
//  AstroPiper
//
//  Created by Claude Code on 2025-09-05.
//

import SwiftUI
import AstroPiperUI
import AstroPiperCore
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedImage: (any AstroImage)?
    @State private var isLoading = false
    @State private var loadingError: Error?
    @State private var showingFilePicker = false
    
    var body: some View {
        Group {
            if let image = selectedImage {
                // Full-screen FITS viewer when image is loaded
                if let fitsImage = image as? FITSAstroImage {
                    FITSImageViewer(image: fitsImage)
                } else {
                    ImageViewer(image: image)
                }
            } else if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading FITS image...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            } else {
                // Welcome state with header
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("AstroPiper")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Professional Astronomical Image Viewer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Welcome content
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("Load a FITS Image")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("Select a FITS file to view astronomical images with professional tools")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Select FITS File")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        if let error = loadingError {
                            Text("Error: \(error.localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .navigationTitle(selectedImage != nil ? "AstroPiper" : "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Select File") {
                    showingFilePicker = true
                }
                .disabled(isLoading)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType.data,
                UTType(filenameExtension: "fits") ?? .data,
                UTType(filenameExtension: "fit") ?? .data,
                UTType(filenameExtension: "fts") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing the security-scoped resource
                    if url.startAccessingSecurityScopedResource() {
                        loadFITSImage(from: url)
                        // Note: We'll stop accessing when done loading
                    } else {
                        loadingError = NSError(domain: "AstroPiper", code: 403, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to gain access to the selected file"
                        ])
                    }
                }
            case .failure(let error):
                loadingError = error
            }
        }
    }
    
    private func loadFITSImage(from url: URL) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingError = nil
        
        Task {
            do {
                // Load FITS file from selected URL
                let image = try await FITSImageLoader.load(from: url)
                
                await MainActor.run {
                    selectedImage = image
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                    isLoading = false
                }
            }
            
            // Stop accessing the security-scoped resource when done
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - UTType Extension for FITS Files

extension UTType {
    static let fitsFile: UTType = {
        // Try to create a proper FITS UTType
        if let fitsType = UTType(filenameExtension: "fits") {
            return fitsType
        }
        if let fitType = UTType(filenameExtension: "fit") {
            return fitType
        }
        // Create a custom UTType for FITS files
        return UTType(exportedAs: "org.fits.astronomical-image", 
                     conformingTo: .data)
    }()
}

#Preview {
    ContentView()
}
