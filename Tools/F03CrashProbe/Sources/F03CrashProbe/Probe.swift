import Foundation
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

private enum ProbeError: Error { case usage, mismatch(String) }

@main struct Probe {
    static func require(_ value: Bool, _ message: String) throws {
        guard value else { throw ProbeError.mismatch(message) }
    }

    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw ProbeError.usage }
        let phase = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let scope = MutationScope(accountID: "f03-process", profileID: "adult")
        let local = root.appendingPathComponent("local")
        let expectedURL = root.appendingPathComponent("envelopes.json")
        let store = try DurableMutationStore(directory: local, scope: scope)
        let expectedValues = Dictionary(uniqueKeysWithValues: (0..<100).map {
            ("item-\($0)", Data("value-\($0)".utf8))
        })
        if phase == "seed" {
            try require(store.pending.isEmpty && store.values.isEmpty, "fixture must start empty")
            for index in 0..<100 { try store.set(Data("value-\(index)".utf8), forKey: "item-\(index)") }
            try require(store.values == expectedValues && store.pending.count == 100, "seed")
            try JSONEncoder().encode(store.pending).write(to: expectedURL, options: .atomic)
        } else {
            let original = try JSONDecoder().decode([DurableMutation].self, from: Data(contentsOf: expectedURL))
            try require(store.values == expectedValues, "local values after process restart")
            let server = try MockMutationServer(storageURL: root.appendingPathComponent("server.json"))
            if phase == "send" {
                try require(store.pending == original, "envelope identity after first SIGKILL")
                for envelope in store.pending { _ = try await server.send(envelope) }
                try require(await server.revision(for: scope) == 100, "server effects")
                try require(store.pending == original, "ACK must remain unrecorded")
            } else if phase == "recover" {
                try require(store.pending == original, "envelope identity after second SIGKILL")
                try require(await server.revision(for: scope) == 100, "persisted server receipts")
                try await store.flush(using: server)
                try require(store.pending.isEmpty && store.values == expectedValues, "recovery")
                try require(await server.values(for: scope) == expectedValues, "server values")
                try require(await server.revision(for: scope) == 100, "duplicate server effects")
                print("F03 PROCESS RECOVERED mutations=100 serverEffects=100 pending=0 lost=0")
                return
            } else if phase == "verify" {
                try require(store.pending.isEmpty, "ACK durability after another restart")
                try require(await server.values(for: scope) == expectedValues, "final server values")
                try require(await server.revision(for: scope) == 100, "final server revision")
                print("F03 PROCESS VERIFIED durableACKs=100 pending=0")
                return
            } else { throw ProbeError.usage }
        }
        // Tell the parent exactly which durable boundary has completed, then stay
        // alive. Parent sends SIGKILL: no stop/invalidate/deinit cleanup is involved.
        try Data(phase.utf8).write(to: root.appendingPathComponent("\(phase).ready"), options: .atomic)
        while true { try await Task.sleep(for: .seconds(60)) }
    }
}
