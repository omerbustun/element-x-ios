//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The shapes that can be stamped onto the image by dragging from one corner to the other.
enum MediaMarkupShapeKind: CaseIterable {
    case arrow
    case line
    case rectangle
    case ellipse
}

/// A shape drawn on the image, defined by the two ends of the drag that created it.
///
/// The ends are normalised within the image so that a shape stays on the part of the image it
/// was drawn on, and can be rendered into the image at its original resolution.
struct MediaMarkupShape: Identifiable, Equatable {
    /// The length of an arrow's head, as a multiple of the stroke width.
    static let arrowHeadWidthRatio: CGFloat = 5
    /// How far each barb of an arrow's head opens away from its shaft.
    private static let arrowHeadAngle: CGFloat = 0.5
    
    let id = UUID()
    var kind: MediaMarkupShapeKind
    var start: CGPoint
    var end: CGPoint
    var colour: MediaMarkupColour
    /// The width of the shape, as a fraction of the smallest side of the image.
    var relativeWidth: CGFloat
    
    /// The straight runs making up the shape, in points.
    ///
    /// Both the editor and the exported image draw from this, so that a shape can't come out
    /// differently in the file than it looked on screen.
    func polylines(in size: CGSize) -> [[CGPoint]] {
        let startPoint = CGPoint(x: start.x * size.width, y: start.y * size.height)
        let endPoint = CGPoint(x: end.x * size.width, y: end.y * size.height)
        
        switch kind {
        case .line:
            return [[startPoint, endPoint]]
        case .arrow:
            let strokeWidth = min(size.width, size.height) * relativeWidth
            let headLength = strokeWidth * Self.arrowHeadWidthRatio
            let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
            let barbs = [angle + .pi - Self.arrowHeadAngle, angle + .pi + Self.arrowHeadAngle].map { barbAngle in
                CGPoint(x: endPoint.x + headLength * cos(barbAngle),
                        y: endPoint.y + headLength * sin(barbAngle))
            }
            return [[startPoint, endPoint], [barbs[0], endPoint, barbs[1]]]
        case .rectangle:
            let bounds = bounds(in: size)
            return [[CGPoint(x: bounds.minX, y: bounds.minY),
                     CGPoint(x: bounds.maxX, y: bounds.minY),
                     CGPoint(x: bounds.maxX, y: bounds.maxY),
                     CGPoint(x: bounds.minX, y: bounds.maxY),
                     CGPoint(x: bounds.minX, y: bounds.minY)]]
        case .ellipse:
            return []
        }
    }
    
    /// The bounds an ellipse is drawn inside, or `nil` for the shapes made of straight runs.
    func ovalBounds(in size: CGSize) -> CGRect? {
        kind == .ellipse ? bounds(in: size) : nil
    }
    
    func strokeWidth(in size: CGSize) -> CGFloat {
        min(size.width, size.height) * relativeWidth
    }
    
    private func bounds(in size: CGSize) -> CGRect {
        let minX = min(start.x, end.x) * size.width
        let minY = min(start.y, end.y) * size.height
        let maxX = max(start.x, end.x) * size.width
        let maxY = max(start.y, end.y) * size.height
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension MediaMarkupShapeKind {
    var icon: KeyPath<CompoundIcons, Image> {
        switch self {
        case .arrow: \.arrowUpRight
        case .line: \.minus
        case .rectangle: \.stop
        case .ellipse: \.circle
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .arrow: UntranslatedL10n.commonShapeArrow
        case .line: UntranslatedL10n.commonShapeLine
        case .rectangle: UntranslatedL10n.commonShapeRectangle
        case .ellipse: UntranslatedL10n.commonShapeEllipse
        }
    }
}

/// Draws the shapes already placed on the image, plus the one being dragged out.
struct MediaMarkupShapeLayer: View {
    let shapes: [MediaMarkupShape]
    let shapeInProgress: MediaMarkupShape?
    
    var body: some View {
        Canvas { context, size in
            for shape in shapes + [shapeInProgress].compactMap(\.self) {
                draw(shape, in: &context, size: size)
            }
        }
    }
    
    private func draw(_ shape: MediaMarkupShape, in context: inout GraphicsContext, size: CGSize) {
        let style = StrokeStyle(lineWidth: shape.strokeWidth(in: size), lineCap: .round, lineJoin: .round)
        let colour = shape.colour.color
        
        for polyline in shape.polylines(in: size) where polyline.count > 1 {
            var path = Path()
            path.addLines(polyline)
            context.stroke(path, with: .color(colour), style: style)
        }
        
        if let ovalBounds = shape.ovalBounds(in: size) {
            context.stroke(Path(ellipseIn: ovalBounds), with: .color(colour), style: style)
        }
    }
}
