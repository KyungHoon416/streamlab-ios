import Foundation

public enum ArtworkLoader {
    public static func load(_ url: URL) async throws -> Data {
        let limit = 8 * 1024 * 1024
        if url.isFileURL {
            return try await Task.detached {
                try Task.checkCancellation()
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= limit else { throw ArtworkLoadError.tooLarge }
                return try Data(contentsOf: url)
            }.value
        }
        guard url.scheme?.lowercased() == "https" else { throw ArtworkLoadError.unsupportedURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              http.mimeType?.hasPrefix("image/") == true else { throw ArtworkLoadError.invalidResponse }
        guard response.expectedContentLength <= Int64(limit) else { throw ArtworkLoadError.tooLarge }
        var data = Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < limit else { throw ArtworkLoadError.tooLarge }
            data.append(byte)
        }
        return data
    }
}
