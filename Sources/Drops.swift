import Foundation

/// Animation drops from `<site>/drops.json`, newest first. Cached, so they keep working offline. Adding a
/// drop is a website change (edit docs/drops.json, deploy); no app update is needed.
final class DropFeed: ObservableObject {
    static let shared = DropFeed()
    @Published private(set) var drops: [SceneSpec] = []
    private let d = UserDefaults.standard
    private var lastFetch = Date.distantPast

    private init() {
        if let data = d.data(forKey: "drops"), let list = try? JSONDecoder().decode([SceneSpec].self, from: data) {
            drops = Self.newestFirst(list)
        }
    }

    private static func newestFirst(_ list: [SceneSpec]) -> [SceneSpec] {
        list.sorted { ($0.added ?? "") > ($1.added ?? "") }
    }

    /// Fetches the feed, at most once every 10 minutes.
    func refresh() {
        guard Date().timeIntervalSince(lastFetch) > 600 else { return }
        lastFetch = Date()
        var req = URLRequest(url: Config.baseURL.appendingPathComponent("drops.json"), timeoutInterval: 15)
        req.cachePolicy = .reloadRevalidatingCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            guard let self, let data, (resp as? HTTPURLResponse)?.statusCode == 200,
                  let list = try? JSONDecoder().decode([SceneSpec].self, from: data) else { return }
            DispatchQueue.main.async {
                self.d.set(data, forKey: "drops")
                self.drops = Self.newestFirst(list)
            }
        }.resume()
    }

    /// Published in the last three weeks.
    func isNew(_ s: SceneSpec) -> Bool {
        guard let added = s.added else { return false }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: added) else { return false }
        return Date().timeIntervalSince(date) < 21 * 86_400
    }
}
