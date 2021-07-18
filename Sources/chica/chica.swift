import Foundation
import KeychainAccess
import SwiftUI

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
        
        /// The current state of the authorization (i.e. whether the user is signedOut, signing in, or already logged in).
        @Published public var authState = State.refreshing

        // Oauth URL
        private let baseURL = "\(Chica.API_URL)/authorize"
        private let secrets: [String: AnyObject]?

        // Intializing Keychain
        private let keychainService = "net.marquiskurt.starlight–secrets"

        init() {

            _ = isOnMainThread(named: "OAUTH CLIENT STARTED")

            //  First, we are trying to see if there is a Tokens.plist file that we will use for our application.
            if let path = Bundle.path(forResource: "Tokens", ofType: "plist", inDirectory: "Tokens"),
               let secrets = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
                self.secrets = secrets
            } else {
                self.secrets = nil
                print("Error: We couldn't locate your \"Tokens.plist\" file which means that you won't be able to use Starlight.")
            }

            //  Now, we check whether the user is signed in or not.
            let keychain = Keychain(service: keychainService)
            if let accessToken = keychain["starlight_acess_token"] {
                authState = .authenthicated(authToken: accessToken)
            } else {
                authState = .signedOut
            }

        }

        /// Returns the URL that needs to be opened in the browser to allow the user to complete registration.
        public func startOauthFlow() -> URL? {
            guard let clientId = secrets?["client_id"] as? String else {
                return nil
            }
            
            authState = .signinInProgress

            return URL(string: baseURL)!
                .queryItem("client_id", value: clientId)
                .queryItem("redirect_uris", value: "starlight://auth")
                .queryItem("scopes", value: "starlight://auth")
                .queryItem("website", value: "https://hyperspace.marquiskurt.net")
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
    static private let URL_PREFIX = "https://"

    /// The domain (without the prefixes) of the instance.
    static public private(set) var INSTANCE_DOMAIN = "mastodon.social"

    static private let API_URL = URL(string: "\(URL_PREFIX)\(INSTANCE_DOMAIN)")!

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

    /// Allows us to decode top-level values of the given type from the given JSON representation.
    private let decoder: JSONDecoder

    private var session: URLSession

    public private(set) var text = "Hello, World!"

    //  MARK: - INITIALIZERS

    public init() {

        _ = isOnMainThread(named: "CLIENT STARTED")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        self.decoder = decoder

        let token: String? = nil

//        switch state {
//        case .authenthicated(let token):
//            self.authenticatedSession = URLSession(configuration: Self.makeSessionConfiguration(token: token))
//        case .refreshing, .signinInProgress, .signedOut:
//            self.authenticatedSession = nil
//        }

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
        let (data, response) = try await self.session.data(for: Self.makeRequest(method, url: url, params: params))
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
