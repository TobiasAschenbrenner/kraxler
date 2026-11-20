import CryptoKit
import Foundation
import ImageIO
import OSLog

@MainActor
final class OfflineTopoStore {
    enum StorageError: Error {
        case invalidImage
        case invalidDownloadID
    }

    private let directory: URL
    private let session: URLSession
    private let fileManager: FileManager
    private var protectedDownloadIDs: Set<String> = []
    private let logger = Logger(subsystem: "com.tobiasaschenbrenner.kraxler", category: "OfflineTopos")

    init(directory: URL? = nil, session: URLSession = .shared, fileManager: FileManager = .default) {
        self.directory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "OfflineTopos", directoryHint: .isDirectory)
        self.session = session
        self.fileManager = fileManager
    }

    func prepareDownload(
        routes: [ClimbingRoute],
        progress: (Double) -> Void = { _ in }
    ) async throws -> String? {
        let imageURLs = Set(routes.flatMap { $0.topos ?? [] }.map(\.imageUrl))
            .sorted { $0.absoluteString < $1.absoluteString }
        guard !imageURLs.isEmpty else { progress(1); return nil }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var root = directory
        try root.setResourceValues(values)
        let downloadID = UUID().uuidString
        let folder = try folder(for: downloadID)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        protectedDownloadIDs.insert(downloadID)

        do {
            for (index, url) in imageURLs.enumerated() {
                try Task.checkCancellation()
                guard url.scheme == "https", url.user == nil, url.password == nil else {
                    throw StorageError.invalidImage
                }
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                let (temporaryFile, response) = try await session.download(for: request)
                defer { try? fileManager.removeItem(at: temporaryFile) }
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      response.url?.scheme == "https",
                      response.mimeType?.hasPrefix("image/") == true else {
                    throw StorageError.invalidImage
                }
                try validateImage(at: temporaryFile)
                try fileManager.moveItem(at: temporaryFile, to: imageURL(for: url, in: folder))
                progress(Double(index + 1) / Double(imageURLs.count))
            }
            return downloadID
        } catch {
            try? remove(downloadID: downloadID)
            throw error
        }
    }

    func finishDownload(_ downloadID: String?) {
        if let downloadID { protectedDownloadIDs.remove(downloadID) }
    }

    func localURL(for imageURL: URL, downloadID: String) -> URL? {
        guard let folder = try? folder(for: downloadID) else { return nil }
        let file = self.imageURL(for: imageURL, in: folder)
        return fileManager.fileExists(atPath: file.path) ? file : nil
    }

    func containsImages(for routes: [ClimbingRoute], downloadID: String?) -> Bool {
        let images = routes.flatMap { $0.topos ?? [] }
        guard !images.isEmpty else { return true }
        guard let downloadID else { return false }
        return images.allSatisfy { localURL(for: $0.imageUrl, downloadID: downloadID) != nil }
    }

    func remove(downloadID: String) throws {
        let folder = try folder(for: downloadID)
        if fileManager.fileExists(atPath: folder.path) { try fileManager.removeItem(at: folder) }
        protectedDownloadIDs.remove(downloadID)
    }

    func pruneDownloads(retaining downloadIDs: Set<String>) {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            for folder in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                let id = folder.lastPathComponent
                guard UUID(uuidString: id) != nil,
                      !downloadIDs.contains(id), !protectedDownloadIDs.contains(id) else { continue }
                try remove(downloadID: id)
            }
        } catch {
            logger.error("Could not remove unused offline images: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func folder(for downloadID: String) throws -> URL {
        guard UUID(uuidString: downloadID) != nil else { throw StorageError.invalidDownloadID }
        return directory.appending(path: downloadID, directoryHint: .isDirectory)
    }

    private func imageURL(for url: URL, in folder: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appending(path: hash)
    }

    private func validateImage(at url: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0, size.intValue <= 20_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 40_000_000,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
              ] as CFDictionary) != nil else {
            throw StorageError.invalidImage
        }
    }
}
