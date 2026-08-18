//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SwiftUI

/// An editor that lets the user draw on an image and decorate it with emojis and text.
struct MediaMarkupView: View {
    /// The provider used to pick emoji stickers. Emojis are unavailable when this is `nil`.
    let emojiProvider: EmojiProviderProtocol?
    let markupDidFinish: (UIImage) -> Void
    let markupWasCancelled: () -> Void
    
    @State private var model: MediaMarkupModel
    @State private var emojiPicker: EmojiPickerPresentation?
    @State private var textEntry: TextEntry?
    @FocusState private var isTextEntryFocussed: Bool
    
    init(image: UIImage,
         emojiProvider: EmojiProviderProtocol?,
         markupDidFinish: @escaping (UIImage) -> Void,
         markupWasCancelled: @escaping () -> Void) {
        self.emojiProvider = emojiProvider
        self.markupDidFinish = markupDidFinish
        self.markupWasCancelled = markupWasCancelled
        _model = State(initialValue: MediaMarkupModel(image: image))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                canvas
                controls
            }
            
            if let textEntry = Binding($textEntry) {
                textEntryOverlay(textEntry)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $emojiPicker) { presentation in
            MediaMarkupEmojiPickerSheet(viewModel: presentation.viewModel) { emojiPicker = nil }
        }
    }
    
    // MARK: - Canvas
    
    private var canvas: some View {
        GeometryReader { geometry in
            let canvasSize = imageSize(fitting: geometry.size)
            
            ZStack {
                Image(uiImage: model.image)
                    .resizable()
                    .onTapGesture { model.selectedStickerID = nil }
                
                MediaMarkupCanvasView(drawing: model.drawing,
                                      revision: model.drawingRevision,
                                      tool: model.inkingTool,
                                      isDrawingEnabled: model.isDrawing,
                                      drawingDidChange: model.drawingDidChange)
                    .allowsHitTesting(model.isDrawing)
                
                if canvasSize.width > 0 {
                    ForEach(model.stickers) { sticker in
                        MediaMarkupStickerView(sticker: sticker,
                                               containerSize: canvasSize,
                                               isSelected: model.selectedStickerID == sticker.id,
                                               gestureDidBegin: model.recordUndoSnapshot,
                                               stickerDidChange: model.updateSticker,
                                               selectSticker: { model.selectedStickerID = sticker.id },
                                               deleteSticker: { model.deleteSticker(id: sticker.id) })
                    }
                    // Let the pen draw over the top of a sticker rather than dragging it around.
                    .allowsHitTesting(!model.isDrawing)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onChange(of: canvasSize, initial: true) { model.updateCanvasSize(canvasSize) }
        }
    }
    
    /// The size that the image occupies once it has been scaled to fit within `availableSize`.
    private func imageSize(fitting availableSize: CGSize) -> CGSize {
        let originalSize = model.image.size
        
        guard originalSize.width > 0, originalSize.height > 0, availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }
        
        let scale = min(availableSize.width / originalSize.width, availableSize.height / originalSize.height)
        
        return CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
    }
    
    // MARK: - Chrome
    
    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: markupWasCancelled) {
                CompoundIcon(\.close)
            }
            .accessibilityLabel(L10n.actionCancel)
            
            Spacer()
            
            Button { model.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel(UntranslatedL10n.actionUndo)
            .disabled(!model.canUndo)
        }
        .font(.compound.bodyLG)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var controls: some View {
        VStack(spacing: 16) {
            if model.isDrawing {
                penOptions
            }
            
            HStack(spacing: 24) {
                toolButton(icon: \.edit, label: UntranslatedL10n.commonDraw, isSelected: model.isDrawing) {
                    model.selectedStickerID = nil
                    model.isDrawing.toggle()
                }
                
                if emojiProvider != nil {
                    toolButton(icon: \.reaction, label: UntranslatedL10n.commonAddEmoji) {
                        presentEmojiPicker()
                    }
                }
                
                toolButton(icon: \.textFormatting, label: UntranslatedL10n.commonAddText) {
                    presentTextEntry()
                }
                
                Spacer()
                
                Button(L10n.actionDone, action: finish)
                    .buttonStyle(.compound(.primary, size: .medium))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var penOptions: some View {
        VStack(spacing: 12) {
            Slider(value: $model.strokeWidth, in: MediaMarkupModel.strokeWidthRange)
                .tint(.white)
                .accessibilityLabel(UntranslatedL10n.a11yMarkupPenSize)
            
            colourPalette(selection: $model.strokeColour)
        }
    }
    
    private func toolButton(icon: KeyPath<CompoundIcons, Image>,
                            label: String,
                            isSelected: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CompoundIcon(icon)
                .foregroundStyle(isSelected ? .black : .white)
                .padding(8)
                .background(isSelected ? Color.white : .clear, in: .circle)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private func colourPalette(selection: Binding<MediaMarkupColour>) -> some View {
        HStack(spacing: 12) {
            ForEach(MediaMarkupColour.allCases) { colour in
                Button { selection.wrappedValue = colour } label: {
                    Circle()
                        .fill(colour.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: selection.wrappedValue == colour ? 3 : 1)
                        }
                }
                .accessibilityLabel(colour.accessibilityLabel)
                .accessibilityAddTraits(selection.wrappedValue == colour ? [.isSelected] : [])
            }
        }
    }
    
    // MARK: - Text
    
    private func textEntryOverlay(_ textEntry: Binding<TextEntry>) -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { commitTextEntry() }
            
            VStack(spacing: 32) {
                Spacer()
                
                TextField("", text: textEntry.text, prompt: Text(UntranslatedL10n.commonAddText), axis: .vertical)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(textEntry.wrappedValue.colour.color)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isTextEntryFocussed)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                colourPalette(selection: textEntry.colour)
                
                Button(L10n.actionDone, action: commitTextEntry)
                    .buttonStyle(.compound(.primary))
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 24)
        }
        .task { isTextEntryFocussed = true }
    }
    
    private func presentTextEntry() {
        model.isDrawing = false
        model.selectedStickerID = nil
        textEntry = TextEntry(colour: model.strokeColour)
    }
    
    private func commitTextEntry() {
        guard let textEntry else { return }
        
        self.textEntry = nil
        isTextEntryFocussed = false
        
        let text = textEntry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return }
        
        model.addSticker(MediaMarkupSticker(content: .text(text, colour: textEntry.colour),
                                            centre: CGPoint(x: 0.5, y: 0.5),
                                            relativeFontSize: 0.1))
    }
    
    // MARK: - Emojis
    
    private func presentEmojiPicker() {
        guard let emojiProvider else { return }
        
        model.isDrawing = false
        model.selectedStickerID = nil
        
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let viewModel = EmojiPickerScreenViewModel(mode: .sticker,
                                                   selectedEmojis: [],
                                                   emojiProvider: emojiProvider,
                                                   continuation: continuation)
        emojiPicker = EmojiPickerPresentation(viewModel: viewModel)
        
        Task {
            for await emoji in stream {
                model.addSticker(MediaMarkupSticker(content: .emoji(emoji),
                                                    centre: CGPoint(x: 0.5, y: 0.5),
                                                    relativeFontSize: 0.25))
            }
            
            emojiPicker = nil
        }
    }
    
    // MARK: - Completion
    
    private func finish() {
        guard model.hasChanges else {
            markupWasCancelled()
            return
        }
        
        guard let image = model.render() else {
            MXLog.error("Failed rendering the marked up image.")
            markupWasCancelled()
            return
        }
        
        markupDidFinish(image)
    }
}

private struct TextEntry {
    var text = ""
    var colour: MediaMarkupColour
}

private struct EmojiPickerPresentation: Identifiable {
    let id = UUID()
    let viewModel: EmojiPickerScreenViewModel
}

/// Wraps the emoji picker so that its own dismissal is forwarded back to the markup editor.
private struct MediaMarkupEmojiPickerSheet: View {
    let viewModel: EmojiPickerScreenViewModel
    let dismiss: () -> Void
    
    var body: some View {
        EmojiPickerScreen(context: viewModel.context)
            .onReceive(viewModel.actions) { _ in
                viewModel.stop()
                dismiss()
            }
    }
}

// MARK: - Previews

struct MediaMarkupView_Previews: PreviewProvider {
    static let image = Bundle.main.url(forResource: "preview_image", withExtension: "jpg")
        .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) } ?? UIImage()
    
    static var previews: some View {
        MediaMarkupView(image: image, emojiProvider: EmojiProvider(appSettings: .volatile())) { _ in } markupWasCancelled: { }
            .previewDisplayName("Markup")
        
        MediaMarkupView(image: image, emojiProvider: nil) { _ in } markupWasCancelled: { }
            .previewDisplayName("Without emojis")
    }
}
