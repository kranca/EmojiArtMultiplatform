//
//  ContentView.swift
//  Shared
//
//  Created by Raúl Carrancá on 23/08/22.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: EmojiArtMultiplatformDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(EmojiArtMultiplatformDocument()))
    }
}
