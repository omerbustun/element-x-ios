//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A piece of content that the user has placed on top of an image whilst marking it up.
///
/// The geometry is stored relative to the image so that it survives layout changes such as
/// device rotation and can be rendered into the image at its original resolution.
struct MediaMarkupSticker: Identifiable, Equatable {
    enum Content: Equatable {
        case emoji(String)
        case text(String, colour: MediaMarkupColour)
    }
    
    let id = UUID()
    var content: Content
    /// The centre of the sticker, normalised within the image's bounds.
    var centre: CGPoint
    /// The base font size of the sticker, as a fraction of the image's width.
    var relativeFontSize: CGFloat
    var scale: CGFloat = 1
    var rotation: Angle = .zero
    
    var string: String {
        switch content {
        case .emoji(let emoji): emoji
        case .text(let text, _): text
        }
    }
    
    /// The colour of the sticker's text, or `nil` when the sticker should be rendered with its own colours.
    var colour: MediaMarkupColour? {
        switch content {
        case .emoji: nil
        case .text(_, let colour): colour
        }
    }
    
    /// The size that the sticker's font should be drawn at within a container of the given width.
    func fontSize(in containerWidth: CGFloat) -> CGFloat {
        relativeFontSize * containerWidth * scale
    }
}

/// The colours that are available when drawing on, or adding text to, an image.
enum MediaMarkupColour: String, CaseIterable, Identifiable {
    case white, black, red, orange, yellow, green, blue, purple
    
    var id: String { rawValue }
    
    var uiColor: UIColor {
        switch self {
        case .white: .white
        case .black: .black
        case .red: UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
        case .orange: UIColor(red: 0.98, green: 0.57, blue: 0.16, alpha: 1)
        case .yellow: UIColor(red: 0.98, green: 0.84, blue: 0.21, alpha: 1)
        case .green: UIColor(red: 0.25, green: 0.75, blue: 0.42, alpha: 1)
        case .blue: UIColor(red: 0.21, green: 0.55, blue: 0.93, alpha: 1)
        case .purple: UIColor(red: 0.61, green: 0.36, blue: 0.91, alpha: 1)
        }
    }
    
    var color: Color { Color(uiColor: uiColor) }
    
    var accessibilityLabel: String {
        switch self {
        case .white: UntranslatedL10n.a11yMarkupColourWhite
        case .black: UntranslatedL10n.a11yMarkupColourBlack
        case .red: UntranslatedL10n.a11yMarkupColourRed
        case .orange: UntranslatedL10n.a11yMarkupColourOrange
        case .yellow: UntranslatedL10n.a11yMarkupColourYellow
        case .green: UntranslatedL10n.a11yMarkupColourGreen
        case .blue: UntranslatedL10n.a11yMarkupColourBlue
        case .purple: UntranslatedL10n.a11yMarkupColourPurple
        }
    }
}
