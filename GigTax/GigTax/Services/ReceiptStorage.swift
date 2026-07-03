import Foundation

/// Saves receipt images/PDFs into the app's sandboxed Documents/Receipts
/// folder and hands back a relative path suitable for Expense.receiptImagePath.
enum ReceiptStorage {
    static func save(data: Data, fileExtension: String) -> String? {
        let dir = receiptsDirectory()
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return "Receipts/\(filename)"
        } catch {
            return nil
        }
    }

    static func save(fileAt sourceURL: URL) -> String? {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: sourceURL) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
        return save(data: data, fileExtension: ext)
    }

    static func fullURL(for relativePath: String) -> URL {
        documentsDirectory().appendingPathComponent(relativePath)
    }

    static func delete(relativePath: String) {
        try? FileManager.default.removeItem(at: fullURL(for: relativePath))
    }

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func receiptsDirectory() -> URL {
        let dir = documentsDirectory().appendingPathComponent("Receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
