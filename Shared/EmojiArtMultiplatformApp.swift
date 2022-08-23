//
//  EmojiArtMultiplatformApp.swift
//  Shared
//
//  Created by Raúl Carrancá on 23/08/22.
//

import SwiftUI

@main
struct EmojiArtMultiplatformApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: EmojiArtMultiplatformDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
