//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import PencilKit
import Testing
import UIKit

@MainActor
struct MediaMarkupTests {
    @Test
    func addingAndDeletingStickers() {
        let model = makeModel()
        
        #expect(!model.hasChanges)
        #expect(!model.canUndo)
        
        let sticker = MediaMarkupSticker(content: .emoji("🚀"), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.25)
        model.addSticker(sticker)
        
        #expect(model.stickers.map(\.string) == ["🚀"])
        #expect(model.selectedStickerID == sticker.id)
        #expect(model.hasChanges)
        
        model.deleteSticker(id: sticker.id)
        
        #expect(model.stickers.isEmpty)
        #expect(model.selectedStickerID == nil)
    }
    
    @Test
    func undoRestoresTheDeletedSticker() {
        let model = makeModel()
        
        let sticker = MediaMarkupSticker(content: .text("Hello", colour: .red), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.1)
        model.addSticker(sticker)
        model.deleteSticker(id: sticker.id)
        
        model.undo()
        #expect(model.stickers.map(\.string) == ["Hello"])
        
        model.undo()
        #expect(model.stickers.isEmpty)
        #expect(!model.canUndo)
    }
    
    @Test
    func updatingAStickerDoesntAffectTheUndoStack() {
        let model = makeModel()
        
        var sticker = MediaMarkupSticker(content: .emoji("🚀"), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.25)
        model.addSticker(sticker)
        
        sticker.centre = CGPoint(x: 0.1, y: 0.2)
        sticker.scale = 2
        model.updateSticker(sticker)
        
        #expect(model.stickers.first?.centre == CGPoint(x: 0.1, y: 0.2))
        #expect(model.stickers.first?.scale == 2)
        
        model.undo()
        #expect(model.stickers.isEmpty, "The move should have been made as part of the sticker's insertion.")
    }
    
    @Test
    func changingTheCanvasSizeScalesTheDrawing() {
        let model = makeModel()
        model.updateCanvasSize(CGSize(width: 100, height: 100))
        
        model.drawingDidChange(makeDrawing(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50)))
        let revision = model.drawingRevision
        
        model.updateCanvasSize(CGSize(width: 200, height: 200))
        
        #expect(model.drawingRevision > revision, "The canvas should be told to reload the transformed drawing.")
        let bounds = model.drawing.bounds
        #expect(bounds.midX > 50, "The stroke should have been scaled up along with the canvas.")
    }
    
    @Test
    func renderingPreservesTheImageSize() throws {
        let image = makeImage(size: CGSize(width: 120, height: 80))
        let model = MediaMarkupModel(image: image)
        model.updateCanvasSize(CGSize(width: 60, height: 40))
        model.addSticker(MediaMarkupSticker(content: .emoji("🚀"), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.25))
        
        let renderedImage = try #require(model.render())
        
        #expect(renderedImage.size == image.size)
        #expect(renderedImage.scale == 1)
    }
    
    @Test
    func markupIsDrawnIntoTheRenderedImage() throws {
        let model = makeModel()
        model.updateCanvasSize(CGSize(width: 100, height: 100))
        
        let unmodifiedImage = try #require(model.render())
        
        model.addSticker(MediaMarkupSticker(content: .text("Hello", colour: .black),
                                            centre: CGPoint(x: 0.5, y: 0.5),
                                            relativeFontSize: 0.3))
        let stickeredImage = try #require(model.render())
        #expect(unmodifiedImage.pngData() != stickeredImage.pngData())
        
        model.drawingDidChange(makeDrawing(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 90)))
        let drawnOnImage = try #require(model.render())
        #expect(stickeredImage.pngData() != drawnOnImage.pngData())
    }
    
    @Test
    func stickerFontSizeScalesWithTheContainer() {
        var sticker = MediaMarkupSticker(content: .emoji("🚀"), centre: .zero, relativeFontSize: 0.25)
        #expect(sticker.fontSize(in: 400) == 100)
        
        sticker.scale = 0.5
        #expect(sticker.fontSize(in: 400) == 50)
    }
    
    // MARK: - Helpers
    
    private func makeModel() -> MediaMarkupModel {
        MediaMarkupModel(image: makeImage(size: CGSize(width: 100, height: 100)))
    }
    
    private func makeImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func makeDrawing(from startPoint: CGPoint, to endPoint: CGPoint) -> PKDrawing {
        let controlPoints = [startPoint, endPoint].enumerated().map { index, location in
            PKStrokePoint(location: location,
                          timeOffset: TimeInterval(index) / 10,
                          size: CGSize(width: 4, height: 4),
                          opacity: 1,
                          force: 1,
                          azimuth: 0,
                          altitude: .pi / 2)
        }
        
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date(timeIntervalSince1970: 0))
        
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .white), path: path)])
    }
}
