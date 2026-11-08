import Foundation
import CryptoKit
import Security
import Combine
import AppKit

// MARK: - Config

enum Config {
    /// Where the site, license API, and downloads live. Change it here (or with tools/set_base_url.sh) after deploying.
    static let baseURL = URL(string: "https://revivethetouchbar.com")!
    /// Ed25519 public key (raw, base64) that license tokens are signed with. The private half lives only on the server.
    static let publicKey = "d+FnYBYhvfJA5k7OEl5ZzzfwF/cxAhCTqGCyAwDxBrE="
    static let trialDays = 7
    static let urlScheme = "revive"
    /// Charging is off for now: every effect and setting is unlocked for everyone, and the app shows no
    /// trial countdown or upgrade prompts. Paid plans and their payment code were removed from this codebase.
    static let chargingEnabled = false
}

// MARK: - Funnel

/// Two anonymous counts help us see whether people who download the app actually use it: one when the app
/// first launches and one when the trial ends. Nothing identifies you or this Mac (see the privacy policy).
enum Telemetry {
    static func ping(_ event: String) {
        #if DEBUG
        return
        #else
        var c = URLComponents(url: Config.baseURL.appendingPathComponent("api/event"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "e", value: event)]
        guard let url = c.url else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 10)).resume()
        #endif
    }
}

// MARK: - Plans and status

enum Plan: String, Codable {
    case lifetime   // one payment, everything, forever
    case yearly     // Pro Yearly: everything, renews every year
    case monthly    // legacy: sold before Pro Yearly; still honored

    var isSubscription: Bool { self != .lifetime }
}

enum LicenseStatus: Equatable {
    case trial(daysLeft: Int)
    /// The trial ended and there is no license: two effects, fixed settings, sponsor card.
    case free
    case licensed(plan: Plan, ads: Bool)

    var isTrial: Bool { if case .trial = self { return true } else { return false } }
    /// Every effect, every control. False on the free plan (always true while `Config.chargingEnabled` is off).
    var hasFullAccess: Bool {
        guard Config.chargingEnabled else { return true }
        if case .free = self { return false } else { return true }
    }
    /// The free plan and Lifetime show the sponsor card; Monthly and the trial do not.
    /// No ads while `Config.chargingEnabled` is off — there's no paid plan to upsell out of them.
    var showsAds: Bool {
        guard Config.chargingEnabled else { return false }
        switch self {
        case .licensed(_, let ads): return ads
        case .free: return true
        case .trial: return false
        }
    }
}

/// What the server signs. `plan` is "none" when a license has lapsed (canceled or unpaid subscription).
/// `plan` only ever says lifetime, monthly, or none, so app versions from before Pro Yearly keep working;
/// `tier` names the actual plan (lifetime, yearly, monthly).
private struct Claims: Codable {
    var key: String
    var plan: String
    var tier: String?
    var ads: Bool
    var iat: Double
    var exp: Double
    /// Set by the server on the owner's license only. Unlocks tools customers don't get (the Direction knob).
    var admin: Bool?
    /// "launch" on the free Lifetime licenses the launch offer gives out.
    var promo: String?
}

// MARK: - Storage

/// The license token and this Mac's ID, kept in the app's settings. Versions up to 1.2.0 kept them in the
/// Keychain, but a Keychain entry belongs to the exact build that wrote it: any other build (a rebuild, a copy
/// built from source) made macOS ask for the login password. Everything is free now, so nothing here is secret.
private enum SecureStore {
    static let service = "com.isaac.rgbtouchbar"
    private static let prefix = "store."

    static func read(_ account: String) -> String? {
        let d = UserDefaults.standard
        if let v = d.string(forKey: prefix + account) { return v }
        // One-time move from the Keychain. Only a Developer ID build can read the old entry without a password
        // prompt, so other builds skip it and start fresh.
        guard isDeveloperIDSigned, let v = keychainRead(account) else { return nil }
        d.set(v, forKey: prefix + account)
        return v
    }

    static func write(_ account: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: prefix + account)
    }

    private static func keychainRead(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// True when this copy carries a team ID (Developer ID signed), false for ad-hoc and unsigned builds.
    private static let isDeveloperIDSigned: Bool = {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return false }
        return dict[kSecCodeInfoTeamIdentifier as String] != nil
    }()
}

/// A random ID for this Mac, kept with the license. The server counts distinct IDs per license (3 Macs max).
private var deviceID: String {
    if let existing = SecureStore.read("deviceId"), !existing.isEmpty { return existing }
    let fresh = UUID().uuidString
    SecureStore.write("deviceId", fresh)
    return fresh
}

// MARK: - License manager

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var status: LicenseStatus = .free
    /// True only for a license the server has marked admin.
    @Published private(set) var isAdmin = false
    /// True when the license is a free Lifetime from the launch offer.
    @Published private(set) var isLaunchGift = false
    @Published var busy = false
    /// The last thing worth telling the person about activation (already localized).
    @Published var message: String?

    private(set) var key: String?
    private var token: String?
    private let d = UserDefaults.standard
    private var timer: Timer?
    private var claiming = false

    private init() {
        // Trial start: remember the earliest date we can find, in both places.
        let now = Date().timeIntervalSince1970
        let stored = [SecureStore.read("trialStart"), d.string(forKey: "trialStart")].compactMap { $0.flatMap(Double.init) }
        let start = stored.min() ?? now
        SecureStore.write("trialStart", String(start))
        d.set(String(start), forKey: "trialStart")
        trialStart = start

        key = (SecureStore.read("licenseKey") ?? d.string(forKey: "licenseKey")).flatMap { $0.isEmpty ? nil : $0 }
        token = SecureStore.read("licenseToken") ?? d.string(forKey: "licenseToken")
        recompute()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.recompute()
            self?.refreshFromServer()
            self?.claimLaunchLicense()
        }
        refreshFromServer()
        claimLaunchLicense()
    }

    private let trialStart: Double

    // MARK: Status

    private func claims(from token: String) -> Claims? {
        let parts = token.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let raw = Data(base64Encoded: Config.publicKey),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: raw),
              let sig = Data(base64URL: parts[1]),
              pub.isValidSignature(sig, for: Data(parts[0].utf8)),
              let payload = Data(base64URL: parts[0]),
              let c = try? JSONDecoder().decode(Claims.self, from: payload) else { return nil }
        return c
    }

    func recompute() {
        #if DEBUG
        // Debug builds only (build with DEBUG_BUILD=1): REVIVE_DEBUG_STATUS=trial5 | expired | lifetime | yearly | monthly
        if let forced = ProcessInfo.processInfo.environment["REVIVE_DEBUG_STATUS"] {
            isAdmin = ProcessInfo.processInfo.environment["REVIVE_DEBUG_ADMIN"] == "1"
            switch forced {
            case "expired", "free": status = .free
            case "lifetime": status = .licensed(plan: .lifetime, ads: false)
            case "yearly": status = .licensed(plan: .yearly, ads: false)
            case "monthly": status = .licensed(plan: .monthly, ads: false)
            default: status = .trial(daysLeft: Int(forced.dropFirst(5)) ?? 5)
            }
            return
        }
        #endif
        let now = Date().timeIntervalSince1970
        if let token, let c = claims(from: token), c.exp > now, Plan(rawValue: c.plan) != nil,
           let plan = Plan(rawValue: c.tier ?? c.plan) ?? Plan(rawValue: c.plan) {
            status = .licensed(plan: plan, ads: c.ads)
            isAdmin = c.admin ?? false
            isLaunchGift = c.promo == "launch"
            return
        }
        isAdmin = false
        isLaunchGift = false
        let elapsedDays = (now - trialStart) / 86_400
        let left = Config.trialDays - Int(elapsedDays.rounded(.down))
        status = left > 0 ? .trial(daysLeft: left) : .free
    }

    // MARK: Server

    /// Silently renews the signed token (weekly for subscriptions). Offline is fine: the cached token keeps working until it expires.
    func refreshFromServer() {
        guard let key else { return }
        fetchToken(for: key) { [weak self] result in
            guard case .success(let t) = result else { return }
            self?.store(token: t)
        }
    }

    /// Launch offer: every download gets a free Lifetime license. With no license on this Mac, ask the server for
    /// one (POST /api/claim with this Mac's random ID). The server hands the same key back every time this Mac
    /// asks, and answers 404 once the offer ends, which leaves the normal trial in place. Runs at launch and
    /// hourly until it lands; never after the person deactivated this Mac themselves.
    func claimLaunchLicense() {
        guard key == nil, !claiming, !d.bool(forKey: "launchClaimDeclined") else { return }
        claiming = true
        var req = URLRequest(url: Config.baseURL.appendingPathComponent("api/claim"), timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["device": deviceID])
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            struct Answer: Decodable { var key: String; var token: String }
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            let answer = ok ? data.flatMap { try? JSONDecoder().decode(Answer.self, from: $0) } : nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.claiming = false
                // Only a token signed by our server counts; anything else leaves the trial as it was.
                guard let answer, self.key == nil, let c = self.claims(from: answer.token), Plan(rawValue: c.plan) != nil else { return }
                self.key = answer.key
                SecureStore.write("licenseKey", answer.key); self.d.set(answer.key, forKey: "licenseKey")
                self.store(token: answer.token)
            }
        }.resume()
    }

    private var userAgent: String {
        "ReviveTheTouchbar/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1")"
    }

    /// Activates a license key the person pasted or opened from the website.
    func activate(key raw: String) {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else { return }
        busy = true; message = nil
        fetchToken(for: key) { [weak self] result in
            guard let self else { return }
            self.busy = false
            switch result {
            case .success(let t):
                guard let c = self.claims(from: t), Plan(rawValue: c.plan) != nil else {
                    self.message = NSLocalizedString("That license has ended. Choose a plan to continue.", comment: "")
                    return
                }
                self.key = key
                SecureStore.write("licenseKey", key); self.d.set(key, forKey: "licenseKey")
                self.d.removeObject(forKey: "launchClaimDeclined")
                self.store(token: t)
                self.message = NSLocalizedString("License activated. Thank you!", comment: "")
            case .failure(let e):
                self.message = e.localizedDescription
            }
        }
    }

    func signOut() {
        // Free this Mac's slot on the server (best effort), then forget the license locally.
        if let key {
            var req = URLRequest(url: Config.baseURL.appendingPathComponent("api/deactivate"), timeoutInterval: 10)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["key": key, "device": deviceID])
            URLSession.shared.dataTask(with: req).resume()
        }
        key = nil; token = nil
        d.set(true, forKey: "launchClaimDeclined")   // they asked for this Mac to be off; don't re-claim behind their back
        SecureStore.write("licenseKey", ""); SecureStore.write("licenseToken", "")
        d.removeObject(forKey: "licenseKey"); d.removeObject(forKey: "licenseToken")
        recompute()
    }

    private func store(token t: String) {
        token = t
        SecureStore.write("licenseToken", t); d.set(t, forKey: "licenseToken")
        recompute()
    }

    private struct APIError: LocalizedError {
        var errorDescription: String?
    }

    private func fetchToken(for key: String, completion: @escaping (Result<String, Error>) -> Void) {
        var comps = URLComponents(url: Config.baseURL.appendingPathComponent("api/license"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "device", value: deviceID)]
        var req = URLRequest(url: comps.url!, timeoutInterval: 15)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                if err != nil {
                    completion(.failure(APIError(errorDescription: NSLocalizedString("Can't reach the license server. Check your connection and try again.", comment: ""))))
                    return
                }
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 409 {
                    completion(.failure(APIError(errorDescription: NSLocalizedString("This license is already in use on 3 Macs. Deactivate one, then try again.", comment: ""))))
                } else if code == 404 {
                    completion(.failure(APIError(errorDescription: NSLocalizedString("That key wasn't found. Check it and try again.", comment: ""))))
                } else if code == 200, let data, let t = String(data: data, encoding: .utf8) {
                    completion(.success(t.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(APIError(errorDescription: NSLocalizedString("Something went wrong on our end. Try again in a moment.", comment: ""))))
                }
            }
        }.resume()
    }

    // MARK: Links

    /// `revive://activate?key=RVT-...`, for keys from the website (the launch offer and earlier).
    func handle(url: URL) {
        guard url.scheme == Config.urlScheme, url.host == "activate",
              let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "key" })?.value
        else { return }
        activate(key: key)
    }
}

// MARK: - Pricing display

enum Pricing {
    /// Prices for this person's currency, falling back to USD.
    static var local: Price {
        let code = Locale.current.currency?.identifier ?? PricingTable.fallback
        return PricingTable.table[code] ?? PricingTable.table[PricingTable.fallback]!
    }

    static func format(_ amount: Double, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.locale = Locale.current
        return f.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }

    static func yearly() -> String { format(local.yearly, currency: local.currency) }
    static func lifetime() -> String { format(local.lifetime, currency: local.currency) }
}

// MARK: - Sponsor card (free plan)

struct Sponsor: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var text: String
    var url: String
    var cta: String?
}

/// Loads the sponsor cards you control from `<site>/sponsors.json` and rotates them by day.
final class SponsorFeed: ObservableObject {
    static let shared = SponsorFeed()
    @Published private(set) var current: Sponsor?
    private let d = UserDefaults.standard

    private init() {
        if let data = d.data(forKey: "sponsors"), let list = try? JSONDecoder().decode([Sponsor].self, from: data) { pick(list) }
    }

    private func pick(_ list: [Sponsor]) {
        guard !list.isEmpty else { current = nil; return }
        let day = Int(Date().timeIntervalSince1970 / 86_400)
        current = list[day % list.count]
    }

    func refresh() {
        var req = URLRequest(url: Config.baseURL.appendingPathComponent("sponsors.json"), timeoutInterval: 10)
        req.cachePolicy = .reloadRevalidatingCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data, let list = try? JSONDecoder().decode([Sponsor].self, from: data) else { return }
            DispatchQueue.main.async {
                self.d.set(data, forKey: "sponsors")
                self.pick(list)
            }
        }.resume()
    }
}

// MARK: - Helpers

private extension Data {
    init?(base64URL s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        self.init(base64Encoded: b)
    }
}
