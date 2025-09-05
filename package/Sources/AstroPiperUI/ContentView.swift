//
//  ContentView.swift
//  AstroPiper
//
//  Created by Oscar Echeverri on 2025-09-03.
//

import SwiftUI

public struct ContentView: View {
    
    public init() {}
    
    public var body: some View {
        VStack {
            Image(systemName: "star.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .padding()
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
