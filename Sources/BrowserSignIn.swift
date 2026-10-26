import CryptoKit
import Foundation
import Security

// Fallback for sign-ins the embedded page cannot complete. macOS lets an app's WKWebView use passkeys only for
// domains associated with that app, so a passkey that belongs to one of Cursor's identity providers (Google,
// GitHub, Apple, company SSO) never appears there. This runs Cursor's own PKCE login in the default browser, where
// passkeys work, and hands the resulting session to the embedded dashboard as the cookie it already uses.
// The endpoints are the ones Cursor's app and CLI call. Cursor does not document them, so every failure leaves
// the embedded sign-in available instead of disconnecting the account.
enum BrowserAuth {
    static let loginBase = URL(string: "https://cursor.com/loginDeepControl")!
    static let pollBase = URL(string: "https://api2.cursor.sh/auth/poll")!
    static let tokenURL = URL(string: "https://api2.cursor.sh/oauth/token")!
    // The client Cursor's app renews its tokens with.
    static let clientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"
    static let cookieName = "WorkosCursorSessionToken"

    // A random verifier and its S256 challenge, both base64url without padding.
    static func makePKCE() -> (verifier: String, challenge: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = base64URL(Data(bytes))
        return (verifier, base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))))
    }
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func loginURL(challenge: String, uuid: String) -> URL {
        var parts = URLComponents(url: loginBase, resolvingAgainstBaseURL: false)!
        // `cli` ends on a confirmation page instead of trying to open the Cursor editor.
        parts.queryItems = [URLQueryItem(name: "challenge", value: challenge), URLQueryItem(name: "uuid", value: uuid),
                            URLQueryItem(name: "mode", value: "login"), URLQueryItem(name: "redirectTarget", value: "cli")]
        return parts.url!
    }
    static func pollURL(uuid: String, verifier: String) -> URL {
        var parts = URLComponents(url: pollBase, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "uuid", value: uuid), URLQueryItem(name: "verifier", value: verifier)]
        return parts.url!
    }
}

struct BrowserSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String

    // Claims read without verifying the signature: Cursor's servers verify the token, the app only needs its
    // subject and expiry.
    static func claims(_ jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }
        var text = segments[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        text += String(repeating: "=", count: (4 - text.count % 4) % 4)
        guard let data = Data(base64Encoded: text) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    var expiresAt: Date? { (Self.claims(accessToken)?["exp"] as? Double).map(Date.init(timeIntervalSince1970:)) }
    // The dashboard cookie names the WorkOS user: the subject after its provider prefix (`auth0|user_…`).
    var userID: String? {
        guard let subject = Self.claims(accessToken)?["sub"] as? String,
              let id = subject.split(separator: "|").last, !id.isEmpty else { return nil }
        return String(id)
    }
    // The same `<user>::<token>` value cursor.com sets after a sign-in on its own page.
    func cookie() -> HTTPCookie? {
        guard let userID, let expiresAt else { return nil }
        return HTTPCookie(properties: [.name: BrowserAuth.cookieName, .value: "\(userID)%3A%3A\(accessToken)", .domain: "cursor.com",
                                       .path: "/", .secure: "TRUE", .expires: expiresAt])
    }
    func needsRenewal(now: Date = Date()) -> Bool { expiresAt.map { $0.timeIntervalSince(now) < 86400 } ?? true }

    static func fromPoll(_ data: Data) -> BrowserSession? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = object["accessToken"] as? String, let refresh = object["refreshToken"] as? String else { return nil }
        let session = BrowserSession(accessToken: access, refreshToken: refresh)
        return session.cookie() == nil ? nil : session
    }
    static func renewal(status: Int, data: Data) -> RenewalOutcome {
        guard status == 200, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return status == 401 ? .signedOut : .failed }
        if object["shouldLogout"] as? Bool == true { return .signedOut }
        guard let access = object["access_token"] as? String else { return .failed }
        // Cursor's app keeps the new access token as the refresh token when the response names none.
        let session = BrowserSession(accessToken: access, refreshToken: object["refresh_token"] as? String ?? access)
        return session.cookie() == nil ? .failed : .renewed(session)
    }
}

enum RenewalOutcome: Equatable { case renewed(BrowserSession), signedOut, failed }

enum BrowserSignInError: Error, Equatable { case timedOut, unreachable, rejected }

// Kept with the app's other account data and readable by the user only. The same bearer value already sits in
// WebKit's cookie store after an embedded sign-in, and a Keychain item would ask again after every ad hoc build.
struct BrowserSessionStore {
    let file: URL
    init(folder: URL) { file = folder.appendingPathComponent("browser-session.json") }
    func load() -> BrowserSession? { (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(BrowserSession.self, from: $0) } }
    func save(_ session: BrowserSession) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(session).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    func delete() { try? FileManager.default.removeItem(at: file) }
}

struct BrowserSignIn {
    var open: (URL) -> Void
    var fetch: (URLRequest) async throws -> (Int, Data) = BrowserSignIn.network
    var pause: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    // Two seconds apart: five minutes to finish in the browser.
    var attempts = 150

    // Opens Cursor's login page and polls until the browser sign-in finishes: 404 while pending, 200 with tokens.
    func run() async throws -> BrowserSession {
        let pkce = BrowserAuth.makePKCE(), uuid = UUID().uuidString.lowercased()
        open(BrowserAuth.loginURL(challenge: pkce.challenge, uuid: uuid))
        var failures = 0
        for _ in 0..<attempts {
            try await pause(.seconds(2))
            let request = URLRequest(url: BrowserAuth.pollURL(uuid: uuid, verifier: pkce.verifier), timeoutInterval: 15)
            guard let (status, data) = try? await fetch(request) else {
                try Task.checkCancellation(); failures += 1
                if failures >= 5 { throw BrowserSignInError.unreachable }
                continue
            }
            if status == 200 {
                guard let session = BrowserSession.fromPoll(data) else { throw BrowserSignInError.rejected }
                return session
            }
            failures = status == 404 ? 0 : failures + 1
            if failures >= 5 { throw BrowserSignInError.unreachable }
        }
        throw BrowserSignInError.timedOut
    }
    func renew(_ session: BrowserSession) async -> RenewalOutcome {
        var request = URLRequest(url: BrowserAuth.tokenURL, timeoutInterval: 20); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["grant_type": "refresh_token", "client_id": BrowserAuth.clientID, "refresh_token": session.refreshToken])
        guard let (status, data) = try? await fetch(request) else { return .failed }
        return BrowserSession.renewal(status: status, data: data)
    }
    static func network(_ request: URLRequest) async throws -> (Int, Data) {
        let (data, response) = try await client.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }
    // No cookies or cached credentials: tokens travel only in these requests.
    private static let client = URLSession(configuration: .ephemeral)
}
