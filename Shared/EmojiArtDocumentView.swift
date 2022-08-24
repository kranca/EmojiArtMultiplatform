//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Raúl Carrancá on 02/05/22.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @Environment(\.undoManager) var undoManager
    
    @ScaledMetric private var defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            PaletteChooser()
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                OptionalImage(uiImage: document.backgroundImage)
                    .scaleEffect(zoomScale)
                    .position(convertFromEmojiCoordinates((0, 0), in: geometry)
                )
                .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: singleTapGestureOnBackground()))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        ZStack {
                            // selection and delete icon for emojis
                            if selectedEmojis.contains(emoji) {
                                ZStack {
                                    Image(systemName: "rectangle")
                                        .font(.system(size: fontSizeForSelectionSymbol(for: emoji)))
                                        .foregroundColor(.gray)
                                        .scaleEffect(zoomScale)
                                        .position(positionSelectionOn(for: emoji, in: geometry))
                                    Button(action: {
                                        for emoji in selectedEmojis {
                                            document.removeEmoji(emoji, undoManager: undoManager)
                                        }
                                        selectedEmojis.removeAll()
                                    }, label: {
                                        Image(systemName: "minus.rectangle")
                                    })
                                        .font(.system(size: fontSize(for: emoji)))
                                        .foregroundColor(.red)
                                        .scaleEffect(zoomScale)
                                        .position(positionForDeleteSymbol(for: emoji, in: geometry))
                                }
                            }
                            Text(emoji.text)
                                .font(.system(size: fontSize(for: emoji)))
                                .scaleEffect(zoomScale)
                                .position(selectedEmojis.contains(emoji) ? positionSelectionOn(for: emoji, in: geometry) : position(for: emoji, in: geometry))
                        }
                        .gesture(singleTapGesture(on: emoji).simultaneously(with: emojiPanGesture()))
                    }
                }
            }
            .clipped() // forces the view to stay within its given size so backgroung doesn't overlap with pallete
            .onDrop(of: [.utf8PlainText, .url, .image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            //.gesture(panGesture()) not recomended to use more than one .gesture on one given View
            .gesture(panGesture().simultaneously(with: zoomGesture()))
            .alert(item: $alertToShow) { alertToShow in
                // return Alert
                alertToShow.alert()
            }
            .onChange(of: document.backgroundImageFetchStatus, perform: { status in
                switch status {
                case .failed(let url):
                    showBackgroundImageFetchFailedAlert(url)
                default:
                    break
                }
            })
            .onReceive(document.$backgroundImage, perform: { image in
                if autozoom {
                    zoomToFit(image, in: geometry.size)
                }
            })
            .compactableToolbar {
                AnimatedActionButton(title: "Paste Background", systemImage: "doc.on.clipboard") {
                    pasteBackground()
                }
                if Camera.isAvailable {
                    AnimatedActionButton(title: "Take Photo", systemImage: "camera") {
                        backgroundPicker = .camera
                    }
                }
                if PhotoLibrary.isAvailable {
                    AnimatedActionButton(title: "Search Photos", systemImage: "photo") {
                        backgroundPicker = .library
                    }
                }
                #if os(iOS)
                if let undoManager = undoManager {
                    if undoManager.canUndo {
                        AnimatedActionButton(title: undoManager.undoActionName, systemImage: "arrow.uturn.backward") {
                            undoManager.undo()
                        }
                    }
                    if undoManager.canRedo {
                        AnimatedActionButton(title: undoManager.redoActionName, systemImage: "arrow.uturn.forward") {
                            undoManager.redo()
                        }
                    }
                }
                #endif
                // in case Toolbar needs to be placed in the bottom of the screen
//                ToolbarItemGroup(placement: .bottomBar) {
//
//                }
            }
            .sheet(item: $backgroundPicker) { pickerType in
                switch pickerType {
                case .camera: Camera(handlePickedImage: { image in handlePickedBackgroundImage(image) })
                case .library: PhotoLibrary(handlePickedImage: { image in handlePickedBackgroundImage(image) })
                }
            }
        }
    }
    
    // MARK: - Camera and Library handling
    
    private func handlePickedBackgroundImage(_ image: UIImage?) {
        // need to review autozoom
        autozoom = true
        if let imageData = image?.imageData {
            document.setBackground(.imageData(imageData), undoManager: undoManager)
        }
        backgroundPicker = nil
    }
    
    // needs to be an Optional so that when equal nil sheet is not active
    @State private var backgroundPicker: BackgroundPickerType?
    
    enum BackgroundPickerType: Identifiable {
        var id: BackgroundPickerType { self }
        
        // another option is to make BackgroundPickerType a String instead of Identifiable
        //var id: String { rawValue }
        
        case camera
        case library
    }
    
    // MARK: - Paste background
    
    private func pasteBackground() {
        autozoom = true
        if let imageData = Pasteboard.imageData {
            document.setBackground(.imageData(imageData), undoManager: undoManager)
        } else if let url = Pasteboard.imageURL {
            document.setBackground(.url(url), undoManager: undoManager)
        } else {
            alertToShow = IdentifiableAlert(
                title: "Paste Background",
                message: "There is no image currenlty on the pasteboard."
            )
        }
    }
    
    @State private var alertToShow: IdentifiableAlert?
    
    private func showBackgroundImageFetchFailedAlert(_ url: URL) {
        alertToShow = IdentifiableAlert(id: "fetch failed: " + url.absoluteString, alert: {
            Alert(
            title: Text("Background Image Fetch"),
            message: Text("Couldn't load image from \(url)."),
            dismissButton: .default(Text("OK"))
            )
        })
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        // .self passes down the type!
        var found = providers.loadObjects(ofType: URL.self) { url in
            autozoom = true
            document.setBackground(.url(url.imageURL), undoManager: undoManager)
        }
        #if os(iOS)
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    autozoom = true
                    document.setBackground(.imageData(data), undoManager: undoManager)
                }
            }
        }
        #endif
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale,
                        undoManager: undoManager
                    )
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
   private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @SceneStorage("EmojiArtDocumentView.steadyStateZoomScale") private var steadyStateZoomScale: CGFloat = 1 // zoom scale at the end of gesture
    @GestureState private var gestureZoomScale: CGFloat = 1 // dynamic zoom scale while gesture is being performed
    
    @State private var autozoom = false
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                //if no selection is done, perform normal zoomin on whole document
                if selectedEmojis.isEmpty {
                    gestureZoomScale = latestGestureScale
                // else scale emojis by gesture scale
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: latestGestureScale, undoManager: undoManager)
                    }
                }
            }
            .onEnded { gestureScaleAtEnd in
                //if no selection is done, perform normal zoomin on whole document
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                // else remove all selected emojis after ending scale gesture
                }
                selectedEmojis.removeAll()
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Panning
    
    @SceneStorage("EmojiArtDocumentView.steadyStatePanOffset") private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    // MARK: - Emoji selection
    @State private var selectedEmojis: Set<EmojiArtModel.Emoji> = Set.init()
    
    private func singleTapGesture(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation {
                    selectedEmojis.toggleSelection(of: emoji)
                }
            }
    }
    
    private func singleTapGestureOnBackground() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation {
                    selectedEmojis.removeAll()
                }
            }
    }
    
    // moves position of delete symbol to upper right corner of selected emojis
    private func positionForDeleteSymbol(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesDeleteSymbol((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertFromEmojiCoordinatesDeleteSymbol(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x + 50) * zoomScale + emojiPanOffset.width + panOffset.width,
            y: center.y + CGFloat(location.y - 20) * zoomScale + emojiPanOffset.height + panOffset.height
        )
    }
    
    private func fontSizeForSelectionSymbol(for emoji: EmojiArtModel.Emoji) -> CGFloat {
         CGFloat(emoji.size + 20)
     }
    
    // MARK: - Emoji Panning
    
    @State private var emojiSteadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var emojiGesturePanOffset: CGSize = CGSize.zero
    
    private var emojiPanOffset: CGSize {
        (emojiSteadyStatePanOffset + emojiGesturePanOffset) * zoomScale
    }
    
    private func emojiPanGesture() -> some Gesture {
        DragGesture()
            .updating($emojiGesturePanOffset) { latestDragGestureValue, emojiGesturePanOffset, _ in
                emojiGesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                // update new position on model for each selected emoji
                for emoji in selectedEmojis {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale, undoManager: undoManager)
                }
                selectedEmojis.removeAll()
                emojiSteadyStatePanOffset = CGSize.zero
            }
    }
    
    private func positionSelectionOn(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesSelectionOn((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertFromEmojiCoordinatesSelectionOn(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + emojiPanOffset.width + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + emojiPanOffset.height + panOffset.height
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
