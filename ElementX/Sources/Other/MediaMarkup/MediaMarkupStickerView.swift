//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// A sticker laid out on top of the image, which can be dragged, pinched and rotated.
struct MediaMarkupStickerView: View {
    let sticker: MediaMarkupSticker
    let containerSize: CGSize
    let isSelected: Bool
    let stickerDidChange: (MediaMarkupSticker) -> Void
    let selectSticker: () -> Void
    let deleteSticker: () -> Void
    
    @State private var baseCentre: CGPoint?
    @State private var baseScale: CGFloat?
    @State private var baseRotation: Angle?
    
    private static let scaleRange: ClosedRange<CGFloat> = 0.2...8
    
    private var fontSize: CGFloat { sticker.fontSize(in: containerSize.width) }
    
    var body: some View {
        Text(sticker.string)
            .font(.system(size: fontSize))
            .foregroundStyle(sticker.colour?.color ?? .white)
            .multilineTextAlignment(.center)
            .fixedSize()
            .shadow(color: .black.opacity(0.35), radius: fontSize / 12, y: fontSize / 32)
            .padding(4)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .rotationEffect(sticker.rotation)
            .overlay(alignment: .topLeading) {
                if isSelected {
                    deleteButton
                }
            }
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .simultaneousGesture(TapGesture().onEnded(selectSticker))
            .position(x: sticker.centre.x * containerSize.width,
                      y: sticker.centre.y * containerSize.height)
    }
    
    private var deleteButton: some View {
        Button(action: deleteSticker) {
            CompoundIcon(\.close, size: .xSmall, relativeTo: .compound.bodySM)
                .foregroundStyle(.black)
                .padding(4)
                .background(.white, in: .circle)
        }
        .accessibilityLabel(L10n.actionRemove)
        .offset(x: -10, y: -10)
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if baseCentre == nil {
                    beginGesture()
                    baseCentre = sticker.centre
                }
                
                guard let baseCentre, containerSize.width > 0, containerSize.height > 0 else { return }
                
                var updatedSticker = sticker
                updatedSticker.centre = CGPoint(x: (baseCentre.x + value.translation.width / containerSize.width).clamped(to: 0...1),
                                                y: (baseCentre.y + value.translation.height / containerSize.height).clamped(to: 0...1))
                stickerDidChange(updatedSticker)
            }
            .onEnded { _ in baseCentre = nil }
    }
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if baseScale == nil {
                    beginGesture()
                    baseScale = sticker.scale
                }
                
                guard let baseScale else { return }
                
                var updatedSticker = sticker
                updatedSticker.scale = (baseScale * value.magnification).clamped(to: Self.scaleRange)
                stickerDidChange(updatedSticker)
            }
            .onEnded { _ in baseScale = nil }
    }
    
    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                if baseRotation == nil {
                    beginGesture()
                    baseRotation = sticker.rotation
                }
                
                guard let baseRotation else { return }
                
                var updatedSticker = sticker
                updatedSticker.rotation = Angle(radians: baseRotation.radians + value.rotation.radians)
                stickerDidChange(updatedSticker)
            }
            .onEnded { _ in baseRotation = nil }
    }
    
    private func beginGesture() {
        guard baseCentre == nil, baseScale == nil, baseRotation == nil else { return }
        selectSticker()
    }
}
