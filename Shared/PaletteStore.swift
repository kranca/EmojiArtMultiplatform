//
//  PaletteStore.swift
//  EmojiArt
//
//  Created by RaΓΊl CarrancΓ‘ on 02/08/22.
//

import Foundation

struct Palette: Identifiable, Codable, Hashable {
    var name: String
    var emojis: String
    var id: Int
    
    fileprivate init(name: String, emojis: String, id: Int) {
        self.name = name
        self.emojis = emojis
        self.id = id
    }
}

class PaletteStore: ObservableObject {
    let name: String
    
    @Published var palettes = [Palette]() {
        didSet {
            storeInUserDefaults()
        }
    }
    
    private var userDefaultKey: String {
        "PaletteStore:" + name
    }
    
    private func storeInUserDefaults() {
        UserDefaults.standard.set(try? JSONEncoder().encode(palettes), forKey: userDefaultKey)
//        UserDefaults.standard.set(palettes.map { [$0.name, $0.emojis, $0.id] }, forKey: userDefaultKey)
    }
    
    private func restoreFromUserDefaults() {
        if let jsonData = UserDefaults.standard.data(forKey: userDefaultKey),
        let decodedPalettes = try? JSONDecoder().decode(Array<Palette>.self, from: jsonData) {
            palettes = decodedPalettes
        }
//        if let palettesAsPropertyList = UserDefaults.standard.array(forKey: userDefaultKey) as? [[String]] {
//            for paletteAsArray in palettesAsPropertyList {
//                if paletteAsArray.count == 3, let id = Int(paletteAsArray[2]), !palettes.contains(where: { $0.id == id }) {
//                    let palette = Palette(name: paletteAsArray[0], emojis: paletteAsArray[1], id: id)
//                    palettes.append(palette)
//                }
//            }
//        }
        
    }
    
    init(named name: String) {
        self.name = name
        restoreFromUserDefaults()
        if palettes.isEmpty {
            insertPalette(named: "Mix", emojis: "β­οΈππ·π¦ ππ»ππΆπ²πππ₯πβ½οΈπππ²π©πππΈπ βοΈπππβ€οΈβοΈββββ οΈπΆββπ³οΈ")
            insertPalette(named: "Vehicles", emojis: "πππππππππππ»πππ")
            insertPalette(named: "Animals", emojis: "ππ£π₯π¦π¦π¦π’ππ¦πππ¦π¦π¦§π¦£ππ¦π¦πͺπ«π¦π¦π¦¬ππππππππ¦ππ¦ππ©ππββ¬")
            insertPalette(named: "Fish", emojis: "π¦π¦π¦π¦π‘π ππ¬π³ππ¦π¦­π")
            insertPalette(named: "Insects", emojis: "ππͺ±ππ¦ππππͺ°πͺ²πͺ³π¦π¦π·π¦")
        }
    }
    
    // MARK: Intent
    func palette(at index: Int) -> Palette {
        let safeIndex = min(max(index, 0), palettes.count - 1)
        return palettes[safeIndex]
    }
    
    @discardableResult
    func removePalette(at index: Int) -> Int {
        if palettes.count > 1, palettes.indices.contains(index) {
            palettes.remove(at: index)
        }
        return index % palettes.count
    }
    
    func insertPalette(named name: String, emojis: String? = nil, at index: Int = 0) {
        let unique = (palettes.max(by: { $0.id < $1.id })?.id ?? 0) + 1
        let palette = Palette(name: name, emojis: emojis ?? "", id: unique)
        let safeIndex = min(max(index, 0), palettes.count)
        palettes.insert(palette, at: safeIndex)
    }
}
