//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import PencilKit
import SwiftUI

/// The way the editor was opened from the media upload preview, which decides both the tool it
/// starts on and, for a sticker, the picker it opens with.
enum MediaMarkupEntryPoint: Identifiable {
    case emoji
    case text
    case draw
    
    var id: Self {
        self
    }
    
    var tool: MediaMarkupModel.Tool {
        switch self {
        case .emoji, .text: .stickers
        case .draw: .pen
        }
    }
}

/// The state of the image markup editor: the strokes drawn by the user, the stickers they've
/// placed on top of the image and whether the pen is currently active.
@Observable
final class MediaMarkupModel {
    enum Tool: CaseIterable {
        /// Placing and moving stickers, rather than drawing.
        case stickers
        case pen
        case highlighter
        case eraser
        case shape
    }
    
    /// The smallest and largest stroke widths offered by the pen slider, in canvas points.
    static let strokeWidthRange: ClosedRange<CGFloat> = 2...30
    
    /// The width of a shape, as a fraction of the smallest side of the image.
    static let shapeRelativeWidthRange: ClosedRange<CGFloat> = 0.004...0.06
    
    let image: UIImage
    
    private(set) var drawing = PKDrawing()
    /// Incremented whenever the drawing is replaced by the model so that the canvas knows to reload it.
    private(set) var drawingRevision = 0
    
    private(set) var stickers: [MediaMarkupSticker] = []
    var selectedStickerID: MediaMarkupSticker.ID?
    
    private(set) var shapes: [MediaMarkupShape] = []
    var shapeKind: MediaMarkupShapeKind = .arrow
    
    var tool: Tool = .stickers
    var strokeColour: MediaMarkupColour = .white
    var strokeWidth: CGFloat = 8
    
    /// The size of the image as it is currently laid out on screen.
    private(set) var canvasSize: CGSize = .zero
    
    /// Only the drawing is undoable. Stickers are removed by selecting them instead.
    private var undoStack: [PKDrawing] = []
    
    init(image: UIImage) {
        self.image = image
    }
    
    /// Undo works on whatever the selected tool draws. Stickers aren't undoable, they're
    /// removed by selecting them instead.
    var canUndo: Bool {
        tool == .shape ? !shapes.isEmpty : !undoStack.isEmpty
    }
    
    var hasChanges: Bool {
        !drawing.strokes.isEmpty || !stickers.isEmpty || !shapes.isEmpty
    }
    
    var isDrawing: Bool {
        tool != .stickers
    }
    
    /// Whether PencilKit should take the drags, rather than the shape layer.
    var isUsingPencilKit: Bool {
        tool == .pen || tool == .highlighter || tool == .eraser
    }
    
    var pencilKitTool: PKTool {
        switch tool {
        // Shapes are drawn by their own layer, so PencilKit is left holding the pen.
        case .stickers, .shape, .pen: PKInkingTool(.pen, color: strokeColour.uiColor, width: strokeWidth)
        case .highlighter: PKInkingTool(.marker, color: strokeColour.uiColor, width: strokeWidth * 2)
        // Vector erasing removes whole strokes, which matches how undo works and avoids
        // leaving invisible fragments behind in the exported image.
        case .eraser: PKEraserTool(.vector)
        }
    }
    
    // MARK: - Editing
    
    /// Removes the last thing the selected tool drew.
    func undo() {
        if tool == .shape {
            guard !shapes.isEmpty else { return }
            shapes.removeLast()
        } else {
            guard let previousDrawing = undoStack.popLast() else { return }
            replaceDrawing(previousDrawing)
        }
    }
    
    /// Stores a drawing that the canvas has just produced, without asking it to reload.
    func drawingDidChange(_ drawing: PKDrawing) {
        undoStack.append(self.drawing)
        self.drawing = drawing
    }
    
    func addSticker(_ sticker: MediaMarkupSticker) {
        stickers.append(sticker)
        selectedStickerID = sticker.id
    }
    
    func updateSticker(_ sticker: MediaMarkupSticker) {
        guard let index = stickers.firstIndex(where: { $0.id == sticker.id }) else { return }
        stickers[index] = sticker
    }
    
    func addShape(_ shape: MediaMarkupShape) {
        shapes.append(shape)
    }
    
    func deleteSticker(id: MediaMarkupSticker.ID) {
        guard stickers.contains(where: { $0.id == id }) else { return }
        
        stickers.removeAll { $0.id == id }
        
        if selectedStickerID == id {
            selectedStickerID = nil
        }
    }
    
    /// Adapts the drawing to a new layout, keeping the strokes in the same place on the image.
    func updateCanvasSize(_ newSize: CGSize) {
        defer { canvasSize = newSize }
        
        guard canvasSize.width > 0, newSize.width > 0, canvasSize != newSize else { return }
        
        let scale = newSize.width / canvasSize.width
        replaceDrawing(drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale)))
    }
    
    // MARK: - Output
    
    /// Draws the strokes and stickers into the image at its original resolution.
    func render() -> UIImage? {
        MediaMarkupRenderer.render(image: image,
                                   drawing: drawing,
                                   canvasSize: canvasSize,
                                   shapes: shapes,
                                   stickers: stickers)
    }
    
    // MARK: - Private
    
    private func replaceDrawing(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        drawingRevision += 1
    }
}
