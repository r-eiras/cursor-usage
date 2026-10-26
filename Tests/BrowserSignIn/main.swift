import CryptoKit
import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
func json(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) }
func jwt(_ claims: [String: Any]) -> String {
    let part = { (object: [String: Any]) in BrowserAuth.base64URL(try! JSONSerialization.data(withJSONObject: object)) }
    return "\(part(["alg": "HS256", "typ": "JWT"])).\(part(claims)).synthetic-signature"
}
// Cursor's tokens last about two months; macOS caps cookie lifetimes at 400 days, so stay realistic.
let expiry = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 60 * 86400)
let token = jwt(["sub": "auth0|user_01SYNTHETIC", "exp": expiry.timeIntervalSince1970])
let renewedToken = jwt(["sub": "auth0|user_01SYNTHETIC", "exp": expiry.timeIntervalSince1970 + 86400])
let pollBody = json(["accessToken": token, "refreshToken": "synthetic-refresh"])

let pkce = BrowserAuth.makePKCE(), other = BrowserAuth.makePKCE()
check(pkce.verifier.count == 43 && pkce.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }, "Verifier is 32 random bytes in base64url without padding")
check(pkce.challenge == BrowserAuth.base64URL(Data(SHA256.hash(data: Data(pkce.verifier.utf8)))), "Challenge is the S256 hash of the verifier")
check(pkce.verifier != other.verifier, "Each sign-in uses a fresh verifier")

let login = URLComponents(url: BrowserAuth.loginURL(challenge: "c", uuid: "u"), resolvingAgainstBaseURL: false)!
let loginQuery = Dictionary(uniqueKeysWithValues: login.queryItems!.map { ($0.name, $0.value ?? "") })
check(login.host == "cursor.com" && login.path == "/loginDeepControl", "Open Cursor's own login page")
check(loginQuery == ["challenge": "c", "uuid": "u", "mode": "login", "redirectTarget": "cli"], "Ask for a login that ends on a confirmation page")
let poll = URLComponents(url: BrowserAuth.pollURL(uuid: "u", verifier: "v"), resolvingAgainstBaseURL: false)!
check(poll.host == "api2.cursor.sh" && poll.path == "/auth/poll" && poll.queryItems?.count == 2, "Poll with the uuid and the verifier only")

let session = BrowserSession(accessToken: token, refreshToken: "synthetic-refresh")
check(session.userID == "user_01SYNTHETIC", "Use the WorkOS user, not the provider prefix")
check(BrowserSession(accessToken: jwt(["sub": "user_01PLAIN", "exp": 1]), refreshToken: "").userID == "user_01PLAIN", "Accept a subject without a prefix")
check(session.expiresAt == expiry, "Read the expiry claim")
let cookie = session.cookie()!
check(cookie.name == "WorkosCursorSessionToken" && cookie.value == "user_01SYNTHETIC%3A%3A\(token)", "Build the dashboard session cookie")
check(cookie.domain == "cursor.com" && cookie.path == "/" && cookie.isSecure && cookie.expiresDate == expiry, "Scope the cookie to cursor.com over HTTPS until the token expires")
check(BrowserSession(accessToken: "not-a-jwt", refreshToken: "").cookie() == nil, "Never build a cookie from a malformed token")
check(BrowserSession(accessToken: jwt(["exp": 1]), refreshToken: "").cookie() == nil, "Never build a cookie without a user")
check(!session.needsRenewal(now: expiry.addingTimeInterval(-2 * 86400)) && session.needsRenewal(now: expiry.addingTimeInterval(-3600)), "Renew within a day of expiry")

check(BrowserSession.fromPoll(pollBody) == session, "Read the tokens from a finished poll")
check(BrowserSession.fromPoll(json(["accessToken": token])) == nil, "Require the refresh token")
check(BrowserSession.fromPoll(json(["accessToken": "x", "refreshToken": "y"])) == nil, "Reject tokens the dashboard could not use")
check(BrowserSession.fromPoll(Data("<html>".utf8)) == nil, "Reject a non-JSON answer")

let renewed = json(["access_token": renewedToken])
check(BrowserSession.renewal(status: 200, data: renewed) == .renewed(BrowserSession(accessToken: renewedToken, refreshToken: renewedToken)), "Keep the new access token as the refresh token")
let named = json(["access_token": renewedToken, "refresh_token": "next"])
check(BrowserSession.renewal(status: 200, data: named) == .renewed(BrowserSession(accessToken: renewedToken, refreshToken: "next")), "Use a refresh token the response names")
check(BrowserSession.renewal(status: 200, data: json(["shouldLogout": true])) == .signedOut, "Drop a session Cursor ends")
check(BrowserSession.renewal(status: 401, data: Data()) == .signedOut, "Drop a session Cursor rejects")
check(BrowserSession.renewal(status: 503, data: Data()) == .failed && BrowserSession.renewal(status: 200, data: Data("{}".utf8)) == .failed, "Keep the session through temporary or unexpected failures")

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: folder) }
let store = BrowserSessionStore(folder: folder)
check(store.load() == nil, "No session before a browser sign-in")
try store.save(session)
let mode = (try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions] as? NSNumber)?.intValue
check(store.load() == session && mode == 0o600, "Persist the session readable by the user only")
store.delete(); check(store.load() == nil, "Delete the session on disconnect")

final class Script { var responses: [Result<(Int, Data), Error>]; var opened: [URL] = []; var polled: [URL] = []; init(_ r: [Result<(Int, Data), Error>]) { responses = r } }
func flow(_ script: Script, attempts: Int = 150) -> BrowserSignIn {
    BrowserSignIn(open: { script.opened.append($0) }, fetch: { request in
        script.polled.append(request.url!)
        guard !script.responses.isEmpty else { return (404, Data()) }
        return try script.responses.removeFirst().get()
    }, pause: { _ in }, attempts: attempts)
}
func failure(_ run: () async throws -> BrowserSession) async -> Error? { do { _ = try await run(); return nil } catch { return error } }

let happy = Script([.success((404, Data())), .success((404, Data())), .success((200, pollBody))])
let signedIn = try await flow(happy).run()
check(signedIn == session && happy.opened.count == 1 && happy.polled.count == 3, "Open the browser once and wait while the poll is pending")
let openedUUID = URLComponents(url: happy.opened[0], resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "uuid" }?.value
check(happy.polled.allSatisfy { URLComponents(url: $0, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "uuid" }?.value == openedUUID }, "Poll the same login the browser opened")
let timedOut = await failure { try await flow(Script([]), attempts: 3).run() }
check(timedOut as? BrowserSignInError == .timedOut, "Give up after the waiting period")
let offline = await failure { try await flow(Script(Array(repeating: .failure(URLError(.notConnectedToInternet)), count: 5))).run() }
check(offline as? BrowserSignInError == .unreachable, "Stop when Cursor is unreachable")
let serverErrors = await failure { try await flow(Script(Array(repeating: .success((500, Data())), count: 5))).run() }
check(serverErrors as? BrowserSignInError == .unreachable, "Stop on repeated server errors")
let recovered = await failure { try await flow(Script([.success((500, Data())), .success((404, Data())), .success((200, pollBody))])).run() }
check(recovered == nil, "A pending answer resets the error count")
let unusable = await failure { try await flow(Script([.success((200, Data("{}".utf8)))])).run() }
check(unusable as? BrowserSignInError == .rejected, "Reject an unusable finished poll")
let cancelled = await failure { try await BrowserSignIn(open: { _ in }, fetch: { _ in (404, Data()) }, pause: { _ in throw CancellationError() }).run() }
check(cancelled is CancellationError, "Cancelling stops the wait")
let renewal = Script([.success((200, renewed))])
let renewalOutcome = await flow(renewal).renew(session)
check(renewalOutcome == .renewed(BrowserSession(accessToken: renewedToken, refreshToken: renewedToken)) && renewal.polled.first == BrowserAuth.tokenURL, "Renew through Cursor's token endpoint")
let renewalOffline = await flow(Script([.failure(URLError(.timedOut))])).renew(session)
check(renewalOffline == .failed, "A network failure keeps the current session")
print("PASS: browser sign-in PKCE, polling, session cookie, renewal and private storage")
