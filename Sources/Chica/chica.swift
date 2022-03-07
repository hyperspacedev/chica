import Foundation
import KeychainAccess
import SwiftUI
import Combine

/**
The primary client object that handles all fediverse requests. It basically works as the logic controller of all the networking done by the app.

All of the getter and setter methods work asynchronously thanks to the new concurrency model introduced in Swift 5.5. They have been written to provide helpful error messages and have a state that can be traced by the app. This model works best in scenarios where data needs to be loaded into a view.

- Version 2.0

*/
public class Chica: ObservableObject, CustomStringConvertible {

    //  MARK: - OAuth
    /**
    An ObservableObject that handles everything related with user authentication. It can be acessed through the singleton `Chica.OAuth.shared()`.

    - Version 1.0

    */
    public class OAuth: ObservableObject {

        /// An enum that allows us to know the state of the user authentication.
        public enum State: Equatable {
            case signedOut
            case refreshing, signinInProgress
            case authenthicated(authToken: String)
        }

        static public let shared = OAuth()

        /// An EnvironmentValue that allows us to open a URL using the appropriate system service.
        ///
        /// Can be used as follows:
        /// ```
        /// openURL(URL(string: "url")!)
        /// ```
        /// or
        ///```
        /// openURL(url) // Where URL.type == URL
        /// ```
        @Environment(\.openURL) private var openURL
        
        /// The current state of the authorization (i.e. whether the user is signedOut, signing in, or already logged in).
        @Published public var authState = State.refreshing

        //  MARK: – STORED PROPERTIES

        // Intializing Keychain
        static public let keychainService = "net.marquiskurt.starlight–secrets"

        private let scopes = ["read", "write", "follow", "push"]

        private let URL_SUFFIX = "oauth"

        init() {

            _ = isOnMainThread(named: "OAUTH CLIENT STARTED")

//            //  First, we are trying to see if there is a Tokens.plist file that we will use for our application.
//            if let path = Bundle.path(forResource: "Tokens", ofType: "plist", inDirectory: "Tokens"),
//               let secrets = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
//                self.secrets = secrets
//            } else {
//                self.secrets = nil
//                print("Error: We no secrets were found which means that you won't be able to use Starlight.")
//            }

            //  Now, we check whether the user is signed in or not.
            let keychain = Keychain(service: Chica.OAuth.keychainService)
            if let accessToken = keychain["starlight_acess_token"] {
                authState = .authenthicated(authToken: accessToken)
            } else {
                authState = .signedOut
            }

        }

        /// Returns the URL that needs to be opened in the browser to allow the user to complete registration.
        public func startOauthFlow(for instanceDomain: String) async {

            //  First, we initialize the keychain object
            let keychain = Keychain(service: Chica.OAuth.keychainService)

            //  Then, we assign the domain of the instance we are working with.
            keychain["starlight_instance_domain"] = instanceDomain
            Chica.INSTANCE_DOMAIN = instanceDomain

            //  Now, we change the state of the oauth to .signInProgress
            authState = .signinInProgress

            //  We then do a POST request to create an application on the specified mastodon instance.
            let client: Application? = try! await Chica.shared.request(.post, for: .apps, params:
                [
                    "client_name": "Starlight",
                    "redirect_uris": "\(Chica.shared.urlPrefix)\(URL_SUFFIX)",
                    "scopes": scopes.joined(separator: " "),
                    "website": "https://hyperspace.marquiskurt.net"
                ]
            )

            //  Once we register our application, we store the information we need for later (id and secret).
            keychain["starlight_client_id"] = client?.clientId
            keychain["starlight_client_secret"] = client?.clientSecret

            //  Then, we generate the url we need to visit for authorizing the user
            let url = Chica.API_URL.appendingPathComponent(Endpoint.authorizeUser.path)
                .queryItem("client_id", value: client?.clientId)
                .queryItem("redirect_uri", value: "\(Chica.shared.urlPrefix)\(URL_SUFFIX)")
                .queryItem("scope", value: scopes.joined(separator: " "))
                .queryItem("response_type", value: "code")

            //  And finally, we open the url in the browser.
            openURL(url)
        }

        /// Continues with the OAuth flow after obtaining the user authorization code from the redirect URI
        public func continueOauthFlow(_ url: URL) async {

            if let code = url.queryParameters?.first(where: { $0.key == "code" }) {

                await continueOauthFlow(code.value)

            }

        }

        /// Continues with the OAuth flow after obtaining the user authorization code from the redirect URI
        public func continueOauthFlow(_ code: String) async {

            let keychain = Keychain(service: Chica.OAuth.keychainService)

            //  We now have the user code, so now all we need to do is retrieve our token
            let token: Token? = try! await Chica.shared.request(.post, for: .token, params:
                [
                    "client_id": keychain["starlight_client_id"]!,
                    "client_secret": keychain["starlight_client_secret"]!,
                    "redirect_uri": "\(Chica.shared.urlPrefix)\(URL_SUFFIX)",
                    "grant_type": "authorization_code",
                    "code": code,
                    "scope": scopes.joined(separator: " ")
                ]
            )

            //  We store the token in the keychain
            keychain["starlight_acess_token"] = token?.accessToken

            //  And, finally, we change the state to use the token we just retrieved.
            self.authState = .authenthicated(authToken: token!.accessToken)

        }

    }

    //  MARK: - HTTPS METHODS
    public enum Method: String {
        case post = "POST"
        case get = "GET"
    }

    //  MARK: - PROPERTIES

    /// A singleton everybody can access to.
    static public let shared = Chica()

    //  MARK: – URLs

    /// The url prefix
    static private let DEFAULT_URL_PREFIX = "starlight://"

    /// The domain (without the prefixes) of the instance.
    static var INSTANCE_DOMAIN: String = Keychain(service: OAuth.keychainService)["starlight_instance_domain"] ?? "mastodon.online"

    static public let API_URL = URL(string: "https://\(INSTANCE_DOMAIN)")!

    /// Allows us to decode top-level values of the given type from the given JSON representation.
    private let decoder: JSONDecoder

    private var session: URLSession

    fileprivate var urlPrefix: String

    private var oauthStateCancellable: AnyCancellable?

    //  MARK: - INITIALIZERS

    public init() {

        _ = isOnMainThread(named: "CLIENT STARTED")
        urlPrefix = Chica.DEFAULT_URL_PREFIX

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        self.decoder = decoder
        var token: String? = nil

        //  For the moment, we still need to use Combine and Publishers a bit, but this might change over time.
        oauthStateCancellable = OAuth.shared.$authState.sink { state in

            switch state {
            case .authenthicated(let oToken):
                token = oToken
            default:
                break
            }

        }

        let configuration = URLSessionConfiguration.default
        var headers = ["User-Agent": "Starlight:v1.0 (by Starlight Development Team)."]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        configuration.httpAdditionalHeaders = headers
        configuration.urlCache = .shared
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120

        self.session = URLSession(configuration: configuration)

    }

    /// Sets the URL prefix of the Chica client when making requests.
    /// - Parameter urlPrefix: The URL prefix to use with this client.
    ///
    /// When the Chica class is first instantiated, the default URL prefix used is `starlight://`. When this method is
    /// called, any future requests made with ``request(_:for:params:)`` will use the new URL prefix.
    ///
    /// - Important: The URL prefix that is assigned to Chica should be a valid URL prefix type registered with your
    ///     app in Xcode or in the app's Info.plist.
    public func setRequestPrefix(to urlPrefix: String) {
        self.urlPrefix = urlPrefix
    }

    /// Resets the URL prefix of the Chica client to the default URL prefix.
    ///
    /// When calling this method, future requests will use the default URL prefix of `starlight://`.
    public func resetRequestPrefix() {
        self.urlPrefix = Chica.DEFAULT_URL_PREFIX
    }

    public static func handleURL(url: URL, actions: [String: ([String: String]?) -> Void]) {
        if !url.absoluteString.hasPrefix(Chica.shared.urlPrefix) {
            print("Cannot handle URL: URL is not valid (\(url.absoluteString)).")
            return
        }
        if url.absoluteString.contains("oauth") {
            Task.init {
                await OAuth.shared.continueOauthFlow(url)
            }
        } else {
            for action in actions {
                if url.absoluteString.contains(action.key) {
                    action.value(url.queryParameters)
                }
            }
        }
    }

    /// Returns a URLRequest with the specified URL, http method, and query parameters.
    static private func makeRequest(_ method: Method, url: URL, params: [String: String]? = nil) -> URLRequest {

        var request: URLRequest
        var url = url

        if let params = params {
            for (_, value) in params.enumerated() {
                url = url.queryItem(value.key, value: value.value)
            }
        }

        request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        return request

    }

    public func request<T: Decodable>(_ method: Method, for endpoint: Endpoint, params: [String: String]? = nil) async throws -> T? {

        var content: T? = nil

        let url = Self.API_URL.appendingPathComponent(endpoint.path)
        let (data, response) = try! await self.session.data(for: Self.makeRequest(method, url: url, params: params))

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FetchError.message(
                reason: "Request returned with error code: \(String(describing: (response as? HTTPURLResponse)?.statusCode))",
                data: data
            )
        }

        do {

            content = try JSONDecoder().decode(T.self, from: data)

        } catch {

            throw FetchError.parseError(reason: error)

        }

        return content

    }

}
