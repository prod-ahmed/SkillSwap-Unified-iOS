//
//  AnnonceImageStore.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 16/11/2025.
//


import UIKit

final class AnnonceImageStore {
    static let shared = AnnonceImageStore()
    private init() {}

    private let folderName = "annonce_images"

    private var folderURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    

    func loadImage(for id: String) -> UIImage? {
        let url = folderURL.appendingPathComponent("\(id).png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func saveImage(_ data: Data, for id: String) {
        let url = folderURL.appendingPathComponent("\(id).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save annonce image:", error)
        }
    }

    func deleteImage(for id: String) {
        let url = folderURL.appendingPathComponent("\(id).png")
        try? FileManager.default.removeItem(at: url)
    }
}
