//
//  PromoImageStore.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 16/11/2025.
//

import UIKit

final class PromoImageStore {
    static let shared = PromoImageStore()
    private init() {}

    // URL du fichier local pour une promo donnée
    private func fileURL(for promoID: String) -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else {
            return nil
        }
        // un nom simple : promo-<id>.jpg
        return docs.appendingPathComponent("promo-\(promoID).jpg")
    }

    // Sauvegarder l'image
    func saveImageData(_ data: Data, for promoID: String) {
        guard let url = fileURL(for: promoID) else { return }
        do {
            try data.write(to: url, options: .atomic)
            print("✅ Image enregistrée localement :", url.path)
        } catch {
            print("❌ Erreur en écrivant l’image :", error)
        }
    }

    // Charger l'image
    func loadImage(for promoID: String) -> UIImage? {
        guard let url = fileURL(for: promoID),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("❌ Erreur en lisant l’image :", error)
            return nil
        }
    }
}

