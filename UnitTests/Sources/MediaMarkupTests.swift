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
    func undoRestoresThePreviousDrawing() {
        let model = makeModel()
        model.updateCanvasSize(CGSize(width: 100, height: 100))
        
        #expect(!model.canUndo)
        
        model.drawingDidChange(makeDrawing(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50)))
        #expect(model.drawing.strokes.count == 1)
        #expect(model.canUndo)
        
        model.undo()
        #expect(model.drawing.strokes.isEmpty)
        #expect(!model.canUndo)
    }
    
    @Test
    func undoLeavesStickersAlone() {
        let model = makeModel()
        model.updateCanvasSize(CGSize(width: 100, height: 100))
        model.drawingDidChange(makeDrawing(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50)))
        
        let sticker = MediaMarkupSticker(content: .text("Hello", colour: .red), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.1)
        model.addSticker(sticker)
        
        // Undo is for the drawing only, stickers are removed by selecting them instead.
        model.undo()
        #expect(model.drawing.strokes.isEmpty)
        #expect(model.stickers.map(\.string) == ["Hello"])
        
        model.deleteSticker(id: sticker.id)
        model.undo()
        #expect(model.stickers.isEmpty, "Deleting a sticker isn't undoable.")
    }
    
    @Test
    func updatingAStickerDoesntAffectTheDrawing() {
        let model = makeModel()
        
        var sticker = MediaMarkupSticker(content: .emoji("🚀"), centre: CGPoint(x: 0.5, y: 0.5), relativeFontSize: 0.25)
        model.addSticker(sticker)
        
        sticker.centre = CGPoint(x: 0.1, y: 0.2)
        sticker.scale = 2
        model.updateSticker(sticker)
        
        #expect(model.stickers.first?.centre == CGPoint(x: 0.1, y: 0.2))
        #expect(model.stickers.first?.scale == 2)
        #expect(!model.canUndo, "Moving a sticker isn't an undoable drawing change.")
    }
    
    @Test
    func toolSelectionDrivesThePencilKitTool() {
        let model = makeModel()
        #expect(!model.isDrawing)
        
        model.tool = .pen
        #expect(model.isDrawing)
        #expect(model.pencilKitTool is PKInkingTool)
        #expect((model.pencilKitTool as? PKInkingTool)?.inkType == .pen)
        
        model.tool = .highlighter
        #expect((model.pencilKitTool as? PKInkingTool)?.inkType == .marker)
        
        model.tool = .eraser
        #expect(model.pencilKitTool is PKEraserTool)
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
    func shapeGeometryMatchesTheDrag() throws {
        let size = CGSize(width: 200, height: 100)
        
        let line = makeShape(kind: .line)
        let linePolylines = line.polylines(in: size)
        #expect(linePolylines.count == 1)
        #expect(linePolylines[0].count == 2)
        expect(linePolylines[0][0], isCloseTo: CGPoint(x: 40, y: 20))
        expect(linePolylines[0][1], isCloseTo: CGPoint(x: 160, y: 80))
        #expect(line.ovalBounds(in: size) == nil)
        
        // An arrow is its shaft plus two barbs meeting at the end it was dragged to.
        let arrowPolylines = makeShape(kind: .arrow).polylines(in: size)
        #expect(arrowPolylines.count == 2)
        #expect(arrowPolylines[1].count == 3)
        expect(arrowPolylines[1][1], isCloseTo: CGPoint(x: 160, y: 80))
        
        // A rectangle comes out the same whichever corner the drag started from.
        let forwards = makeShape(kind: .rectangle).polylines(in: size)
        var backwards = makeShape(kind: .rectangle)
        backwards.start = CGPoint(x: 0.8, y: 0.8)
        backwards.end = CGPoint(x: 0.2, y: 0.2)
        #expect(forwards == backwards.polylines(in: size))
        #expect(forwards[0].count == 5)
        #expect(forwards[0].first == forwards[0].last)
        
        let ellipse = makeShape(kind: .ellipse)
        #expect(ellipse.polylines(in: size).isEmpty)
        let bounds = try #require(ellipse.ovalBounds(in: size))
        expect(bounds.origin, isCloseTo: CGPoint(x: 40, y: 20))
        expect(CGPoint(x: bounds.width, y: bounds.height), isCloseTo: CGPoint(x: 120, y: 60))
    }
    
    @Test
    func undoRemovesTheLastShapeWhenTheShapeToolIsSelected() {
        let model = makeModel()
        model.tool = .shape
        
        #expect(!model.canUndo)
        
        model.addShape(makeShape(kind: .arrow))
        model.addShape(makeShape(kind: .line))
        #expect(model.canUndo)
        #expect(model.shapes.count == 2)
        
        model.undo()
        #expect(model.shapes.map(\.kind) == [.arrow])
        
        model.undo()
        #expect(model.shapes.isEmpty)
        #expect(!model.canUndo)
    }
    
    @Test
    func stickerFontSizeScalesWithTheContainer() {
        var sticker = MediaMarkupSticker(content: .emoji("🚀"), centre: .zero, relativeFontSize: 0.25)
        #expect(sticker.fontSize(in: 400) == 100)
        
        sticker.scale = 0.5
        #expect(sticker.fontSize(in: 400) == 50)
    }
    
    // MARK: - Helpers
    
    /// Geometry is computed from normalised values, so the results land near the expected
    /// pixel rather than exactly on it.
    private func expect(_ point: CGPoint, isCloseTo expected: CGPoint, tolerance: CGFloat = 0.01) {
        #expect(abs(point.x - expected.x) < tolerance, "\(point.x) is not close to \(expected.x)")
        #expect(abs(point.y - expected.y) < tolerance, "\(point.y) is not close to \(expected.y)")
    }
    
    private func makeShape(kind: MediaMarkupShapeKind) -> MediaMarkupShape {
        MediaMarkupShape(kind: kind,
                         start: CGPoint(x: 0.2, y: 0.2),
                         end: CGPoint(x: 0.8, y: 0.8),
                         colour: .red,
                         relativeWidth: 0.012)
    }
    
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
