//
//  ContentView.swift
//  AstroPiper
//
//  Created by Claude Code on 2025-09-05.
//

import SwiftUI
import AstroPiperUI
import AstroPiperCore

struct ContentView: View {
    @State private var selectedImage: (any AstroImage)?
    @State private var isLoading = false
    @State private var loadingError: Error?
    
    var body: some View {
        NavigationView {
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
                
                // Content area
                if let image = selectedImage {
                    // Show FITS viewer with loaded image
                    if let fitsImage = image as? FITSAstroImage {
                        FITSImageViewer(image: fitsImage)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Standard image viewer
                        ImageViewer(image: image)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                } else {
                    // Welcome state
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
                        
                        Button(action: loadSampleFITSImage) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Load Sample FITS Image")
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("AstroPiper")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Load FITS") {
                    loadSampleFITSImage()
                }
                .disabled(isLoading)
            }
        }
    }
    
    private func loadSampleFITSImage() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingError = nil
        
        Task {
            do {
                // Try to load a sample FITS file from the Sample Files directory
                let sampleFilesURL = URL(fileURLWithPath: "/Users/oecheverri/Developer/AstroPiper/Sample Files")
                let contents = try FileManager.default.contentsOfDirectory(at: sampleFilesURL, includingPropertiesForKeys: nil)
                
                // Find the first FITS file
                if let fitsFile = contents.first(where: { $0.pathExtension.lowercased() == "fit" }) {
                    let image = try await FITSImageLoader.load(from: fitsFile)
                    
                    await MainActor.run {
                        selectedImage = image
                        isLoading = false
                    }
                } else {
                    // No FITS files found, create a mock for demo
                    await MainActor.run {
                        loadingError = NSError(domain: "AstroPiper", code: 404, userInfo: [
                            NSLocalizedDescriptionKey: "No FITS files found in Sample Files directory"
                        ])
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}