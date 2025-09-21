import Foundation

final class BudgetStorage {
    static let shared = BudgetStorage()
    private let fileName = "budget_local_v1.json"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("HomeBudgeting", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    func load() -> BudgetState {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                return BudgetState()
            }
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode(BudgetState.self, from: data)
            return decoded
        } catch {
            return BudgetState()
        }
    }

    func save(_ state: BudgetState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save budget: \(error)")
        }
    }

    func exportAll() -> String {
        let state = load()
        guard let data = try? encoder.encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
