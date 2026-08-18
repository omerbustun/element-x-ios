//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import PencilKit
import SwiftUI
import UIKit

/// Flattens the markup made by the user into the image they were editing.
enum MediaMarkupRenderer {
    /// Draws `drawing` and `stickers` on top of `image` at the image's original resolution.
    /// - Parameter canvasSize: The size that the image (and therefore the drawing) was laid out at on screen.
    static func render(image: UIImage, drawing: PKDrawing, canvasSize: CGSize, stickers: [MediaMarkupSticker]) -> UIImage? {
        let outputSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: outputSize))
            
            if !drawing.strokes.isEmpty, canvasSize.width > 0, canvasSize.height > 0 {
                let scale = outputSize.width / canvasSize.width
                drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
                    .draw(in: CGRect(origin: .zero, size: outputSize))
            }
            
            for sticker in stickers {
                draw(sticker, in: context.cgContext, outputSize: outputSize)
            }
        }
    }
    
    // MARK: - Private
    
    private static func draw(_ sticker: MediaMarkupSticker, in context: CGContext, outputSize: CGSize) {
        let fontSize = sticker.fontSize(in: outputSize.width)
        
        guard fontSize > 0, !sticker.string.isEmpty else { return }
        
        let string = NSAttributedString(string: sticker.string, attributes: attributes(for: sticker, fontSize: fontSize))
        // Matches the `fixedSize` used on screen so that long text isn't wrapped differently here.
        let bounds = string.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin],
                                         context: nil)
        
        context.saveGState()
        context.translateBy(x: sticker.centre.x * outputSize.width, y: sticker.centre.y * outputSize.height)
        context.rotate(by: sticker.rotation.radians)
        
        string.draw(with: CGRect(x: -bounds.width / 2, y: -bounds.height / 2, width: bounds.width, height: bounds.height),
                    options: [.usesLineFragmentOrigin],
                    context: nil)
        
        context.restoreGState()
    }
    
    private static func attributes(for sticker: MediaMarkupSticker, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        // Keep light stickers legible on light images, matching the shadow used on screen.
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = fontSize / 12
        shadow.shadowOffset = CGSize(width: 0, height: fontSize / 32)
        
        var attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize),
                                                         .paragraphStyle: paragraphStyle,
                                                         .shadow: shadow]
        
        if let colour = sticker.colour {
            attributes[.foregroundColor] = colour.uiColor
        }
        
        return attributes
    }
}
