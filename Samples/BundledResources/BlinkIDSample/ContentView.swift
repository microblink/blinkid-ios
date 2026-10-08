// Created by Toni Krešo on 21.03.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI

import BlinkIDUX

struct ContentView: View {
    @EnvironmentObject var viewModel: BlinkIDViewModel
    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
        case .home:
            HomeScreen()
        case .error(let error):
            VStack(spacing: 30) {
                Text(error)
                DeleteCachedResourcesButton()
            }
            .padding()
        case .success(let scanningResult):
            ScanningResultView(scanningResult: scanningResult)
        case .scanBuiltin(let viewModel):
            BlinkIDUXView(viewModel: viewModel)
        case .scanCustom(let viewModel):
            CustomUIScanningView(viewModel: viewModel)
        }
        
    }
    
    @ViewBuilder
    private func HomeScreen() -> some View {
        VStack(spacing: 30) {
            Button {
                Task {
                    await viewModel.performScan()
                }
            } label: {
                Text("BlinkID UI")
            }

            Button {
                Task {
                    await viewModel.performScan(customScan: true)
                }
            } label: {
                Text("Custom UI")
            }

            DeleteCachedResourcesButton()
        }
        .padding()
    }

    @ViewBuilder
    private func DeleteCachedResourcesButton() -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.deleteCachedResources()
            }
        } label: {
            Text("Delete Cached Resources")
        }
    }
}
