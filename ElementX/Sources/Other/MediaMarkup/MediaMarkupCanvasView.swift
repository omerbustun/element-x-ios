//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import PencilKit
import SwiftUI

/// A transparent PencilKit canvas that sits on top of the image being marked up.
struct MediaMarkupCanvasView: UIViewRepresentable {
    let drawing: PKDrawing
    /// Changes whenever `drawing` is replaced by the model, telling the canvas to reload it.
    let revision: Int
    let tool: PKInkingTool
    let isDrawingEnabled: Bool
    let drawingDidChange: (PKDrawing) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.drawing = drawing
        
        // Set the delegate last so that the initial drawing isn't reported as a change.
        canvasView.delegate = context.coordinator
        context.coordinator.appliedRevision = revision
        
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.drawingDidChange = drawingDidChange
        canvasView.tool = tool
        canvasView.isUserInteractionEnabled = isDrawingEnabled
        
        guard context.coordinator.appliedRevision != revision else { return }
        
        context.coordinator.isReloadingDrawing = true
        canvasView.drawing = drawing
        context.coordinator.isReloadingDrawing = false
        context.coordinator.appliedRevision = revision
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(drawingDidChange: drawingDidChange)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawingDidChange: (PKDrawing) -> Void
        var appliedRevision = 0
        var isReloadingDrawing = false
        
        init(drawingDidChange: @escaping (PKDrawing) -> Void) {
            self.drawingDidChange = drawingDidChange
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isReloadingDrawing else { return }
            drawingDidChange(canvasView.drawing)
        }
    }
}
