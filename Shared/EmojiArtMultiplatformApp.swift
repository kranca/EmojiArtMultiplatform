//
//  EmojiArtMultiplatformApp.swift
//  Shared
//
//  Created by Raúl Carrancá on 23/08/22.
//

import SwiftUI

@main
struct EmojiArtMultiplatformApp: App {
    @StateObject var  paletteStore = PaletteStore(named: "Default")
    
    var body: some Scene {
        DocumentGroup(newDocument: { EmojiArtDocument() }) { config in
            EmojiArtDocumentView(document: config.document)
                .environmentObject(paletteStore)
        }
    }
}
