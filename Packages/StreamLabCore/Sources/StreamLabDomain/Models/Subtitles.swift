import Foundation

/// Plain-text SubRip cues. End boundaries are exclusive, including after a seek.
public struct SubtitleCue: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let text: String
}

public enum SubRip {
    public static func parse(_ source: String) -> [SubtitleCue] {
        let normalized = source.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var blocks: [[String]] = []
        var lines: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !lines.isEmpty { blocks.append(lines); lines = [] }
            } else { lines.append(line) }
        }
        if !lines.isEmpty { blocks.append(lines) }
        return blocks.compactMap { block -> SubtitleCue? in
            guard let index = block.firstIndex(where: { $0.contains("-->") }), index <= 1,
                  index + 1 < block.count else { return nil }
            let times = block[index].components(separatedBy: "-->")
            guard times.count == 2, let start = timestamp(times[0]), let end = timestamp(times[1]), end > start else { return nil }
            let text = block[(index + 1)...].joined(separator: "\n")
            return SubtitleCue(start: start, end: end, text: text)
        }.sorted { $0.start < $1.start }
    }

    public static func text(at time: Double, in cues: [SubtitleCue]) -> String {
        guard time.isFinite else { return "" }
        return cues.filter { $0.start <= time && time < $0.end }.map(\.text).joined(separator: "\n")
    }

    private static func timestamp(_ value: String) -> Double? {
        let parts = value.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
        guard parts.count == 3, parts[0].count >= 2, parts[1].count == 2,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let hours = Double(parts[0]), let minutes = Double(parts[1]), minutes < 60 else { return nil }
        let seconds = parts[2].components(separatedBy: ",")
        guard seconds.count == 2, seconds[0].count == 2, seconds[1].count == 3,
              seconds.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let whole = Double(seconds[0]), whole < 60, let fraction = Double(seconds[1]) else { return nil }
        let result = hours * 3600 + minutes * 60 + whole + fraction / 1000
        return result.isFinite ? result : nil
    }
}
