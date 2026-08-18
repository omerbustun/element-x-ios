//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import PencilKit
import SwiftUI

/// The state of the image markup editor: the strokes drawn by the user, the stickers they've
/// placed on top of the image and whether the pen is currently active.
@Observable
final class MediaMarkupModel {
    private struct Snapshot {
        let drawing: PKDrawing
        let stickers: [MediaMarkupSticker]
    }
    
    /// The smallest and largest stroke widths offered by the pen slider, in canvas points.
    static let strokeWidthRange: ClosedRange<CGFloat> = 2...30
    
    let image: UIImage
    
    private(set) var drawing = PKDrawing()
    /// Incremented whenever the drawing is replaced by the model so that the canvas knows to reload it.
    private(set) var drawingRevision = 0
    
    private(set) var stickers: [MediaMarkupSticker] = []
    var selectedStickerID: MediaMarkupSticker.ID?
    
    var isDrawing = false
    var strokeColour: MediaMarkupColour = .white
    var strokeWidth: CGFloat = 8
    
    /// The size of the image as it is currently laid out on screen.
    private(set) var canvasSize: CGSize = .zero
    
    private var undoStack: [Snapshot] = []
    
    init(image: UIImage) {
        self.image = image
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    
    var hasChanges: Bool { !drawing.strokes.isEmpty || !stickers.isEmpty }
    
    var inkingTool: PKInkingTool { PKInkingTool(.pen, color: strokeColour.uiColor, width: strokeWidth) }
    
    // MARK: - Editing
    
    /// Records the current state so that it can be restored by ``undo()``.
    func recordUndoSnapshot() {
        undoStack.append(Snapshot(drawing: drawing, stickers: stickers))
    }
    
    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        
        stickers = snapshot.stickers
        selectedStickerID = nil
        replaceDrawing(snapshot.drawing)
    }
    
    /// Stores a drawing that the canvas has just produced, without asking it to reload.
    func drawingDidChange(_ drawing: PKDrawing) {
        recordUndoSnapshot()
        self.drawing = drawing
    }
    
    func addSticker(_ sticker: MediaMarkupSticker) {
        recordUndoSnapshot()
        stickers.append(sticker)
        selectedStickerID = sticker.id
    }
    
    /// Updates a sticker whilst it is being manipulated. This doesn't record an undo snapshot,
    /// the gesture handler does that once, when the gesture begins.
    func updateSticker(_ sticker: MediaMarkupSticker) {
        guard let index = stickers.firstIndex(where: { $0.id == sticker.id }) else { return }
        stickers[index] = sticker
    }
    
    func deleteSticker(id: MediaMarkupSticker.ID) {
        guard stickers.contains(where: { $0.id == id }) else { return }
        
        recordUndoSnapshot()
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
        MediaMarkupRenderer.render(image: image, drawing: drawing, canvasSize: canvasSize, stickers: stickers)
    }
    
    // MARK: - Private
    
    private func replaceDrawing(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        drawingRevision += 1
    }
}
