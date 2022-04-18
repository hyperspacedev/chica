/*
*   THE WORK (AS DEFINED BELOW) IS PROVIDED UNDER THE TERMS OF THIS
*   NON-VIOLENT PUBLIC LICENSE v4 ("LICENSE"). THE WORK IS PROTECTED BY
*   COPYRIGHT AND ALL OTHER APPLICABLE LAWS. ANY USE OF THE WORK OTHER THAN
*   AS AUTHORIZED UNDER THIS LICENSE OR COPYRIGHT LAW IS PROHIBITED. BY
*   EXERCISING ANY RIGHTS TO THE WORK PROVIDED IN THIS LICENSE, YOU AGREE
*   TO BE BOUND BY THE TERMS OF THIS LICENSE. TO THE EXTENT THIS LICENSE
*   MAY BE CONSIDERED TO BE A CONTRACT, THE LICENSOR GRANTS YOU THE RIGHTS
*   CONTAINED HERE IN AS CONSIDERATION FOR ACCEPTING THE TERMS AND
*   CONDITIONS OF THIS LICENSE AND FOR AGREEING TO BE BOUND BY THE TERMS
*   AND CONDITIONS OF THIS LICENSE.
*
*   This source file is part of the Codename Starlight open source project
*   Written by Alejandro Modroño <alex@sureservice.es>, July 2021
*
*   See `LICENSE.txt` for license information
*   See `CONTRIBUTORS.txt` for project authors
*
*/
import Foundation
import KeychainAccess
import SwiftUI
import Combine
import os

/**
The primary client object that handles all fediverse requests. It basically works as the logic controller of all the networking done by the app.

All of the getter and setter methods work asynchronously thanks to the new concurrency model introduced in Swift 5.5. They have been written to provide helpful error messages and have a state that can be traced by the app. This model works best in scenarios where data needs to be loaded into a view.
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

        private let keychain: Keychain

        init() {

            Chica.logger.trace("Initialising OAuth client.")
            defer {

                if case .authenthicated = authState {
                    Chica.logger.info("An access token was found, user is logged in.")
                } else {
                    Chica.logger.info("No access token was found, user is signed out.")
                }

                Chica.logger.info("OAuth client initialised.")
            }

            Chica.logger.trace("Accessing keychainService \"\(Chica.OAuth.keychainService)\".")
            keychain = Keychain(service: Chica.OAuth.keychainService)

            /*
             *  As of chica v1.0 users can also specify a specific authorization token
             *  that will be used, by creating a Tokens.plist file.
             */

            //  First, we are trying to see if there is a Tokens.plist file that we
            //  will use for our application.
            if let path = Bundle.path(forResource: "Tokens", ofType: "plist", inDirectory: "Tokens"),
               let secrets = NSDictionary(contentsOfFile: path) as? [String: String] {
                if let token = secrets["token"] {
                    authState = .authenthicated(authToken: token)
                }
            } else {

                //  If there is no token, we will check whether the user is signed in
                //  or not by checking if there is a token stored in the keychain.
                if let accessToken = keychain["starlight_access_token"] {
                    authState = .authenthicated(authToken: accessToken)
                } else {
                    authState = .signedOut
                }

            }

        }

        /// Returns the URL that needs to be opened in the browser to allow the user to complete registration.
        /// - Parameter instanceDomain: The domain in which the instance lies to start authorization for.
        /// - Parameter authHandler: An optional closure that runs once the URL is created to open. Defaults to
        ///     nil, using `openURL` instead.
        public func startOauthFlow(for instanceDomain: String, authHandler: ((URL) -> Void)? = nil) async throws {

            Chica.logger.trace("Sign Up process started...")
            //  First, we initialize the keychain object

            //  Then, we assign the domain of the instance we are working with.
            keychain["starlight_instance_domain"] = instanceDomain
            Chica.INSTANCE_DOMAIN = instanceDomain
            Chica.logger.trace("Instance domain: \(instanceDomain)")

            //  Now, we change the state of the oauth to .signInProgress
            authState = .signinInProgress

            var client: Application? = nil

            do {
                //  We then do a POST request to create an application on the specified mastodon instance.
                client = try await Chica.shared.request(.post, for: .apps, queryParams:
                    [
                        "client_name": "Starlight",
                        "redirect_uris": "\(Chica.shared.urlPrefix)://\(URL_SUFFIX)",
                        "scopes": scopes.joined(separator: " "),
                        "website": "https://hyperspace.marquiskurt.net"
                    ]
                )
            } catch {
                Chica.logger.error("An unexpected error ocurred: \(error.localizedDescription)")
                throw error
            }

            //  Once we register our application, we store the information we need for later (id and secret).
            keychain["starlight_client_id"] = client?.clientId
            keychain["starlight_client_secret"] = client?.clientSecret
            Chica.logger.info("Application registered.")

            //  Then, we generate the url we need to visit for authorizing the user
            let url = Chica.API_URL.appendingPathComponent(Endpoint.authorizeUser.path)
                .queryItem("client_id", value: client?.clientId)
                .queryItem("redirect_uri", value: "\(Chica.shared.urlPrefix)://\(URL_SUFFIX)")
                .queryItem("scope", value: scopes.joined(separator: " "))
                .queryItem("response_type", value: "code")

            //  And finally, we open the url in the browser.
            if let handler = authHandler {
                Chica.logger.info("Opening url with custom handler.")
                handler(url)
            } else {
                Chica.logger.info("Opening url in the in-app safari.")
                openURL(url)
            }
        }

        /// Continues with the OAuth flow after obtaining the user authorization code from the redirect URI
        public func continueOauthFlow(_ url: URL) async throws {

            if let code = url.queryParameters?.first(where: { $0.key == "code" }) {

                try await continueOauthFlow(code.value)

            }

        }

        /// Continues with the OAuth flow after obtaining the user authorization code from the redirect URI
        public func continueOauthFlow(_ code: String) async throws {

            Chica.logger.trace("Continuing OAuth flow.")

            var token: Token? = nil

            do {
                //  We now have the user code, so now all we need to do is retrieve our token
                token = try await Chica.shared.request(.post, for: .token, queryParams:
                    [
                        "client_id": keychain["starlight_client_id"]!,
                        "client_secret": keychain["starlight_client_secret"]!,
                        "redirect_uri": "\(Chica.shared.urlPrefix)://\(URL_SUFFIX)",
                        "grant_type": "authorization_code",
                        "code": code,
                        "scope": scopes.joined(separator: " ")
                    ]
                )
            } catch {
                Chica.logger.error("An unexpected error ocurred: \(error.localizedDescription)")
                throw error
            }

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

    /// The class' main logger.
    public static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Chica.self)
    )

    //  MARK: – URLs

    /// The url prefix
    static private let DEFAULT_URL_PREFIX = "starlight"

    /// The domain (without the prefixes) of the instance.
    static var INSTANCE_DOMAIN: String = Keychain(service: OAuth.keychainService)["starlight_instance_domain"] ?? "mastodon.online"

    static public let API_URL = URL(string: "https://\(INSTANCE_DOMAIN)")!

    /// Allows us to decode top-level values of the given type from the given JSON representation.
    private let decoder: JSONDecoder

    private var session: URLSession

    public var urlPrefix: String

    //  MARK: - INITIALIZERS

    public init() {

        Chica.logger.trace("Initialising Chica...")
        urlPrefix = Chica.DEFAULT_URL_PREFIX

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder

        Chica.logger.trace("Initialising URL session configuration...")
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Starlight:v1.0 (by Starlight Development Team)."
        ]
        configuration.urlCache = .shared
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120

        self.session = URLSession(configuration: configuration)
        Chica.logger.info("Initialised session, wapper successfully initialised.")
    }

    /**
     *  Sets the URL prefix of the Chica client when making requests.
     *  - Parameter urlPrefix: The URL prefix to use with this client.
     *
     *  When the Chica class is first instantiated, the default URL prefix used is `starlight://`. When this method is called, any future requests made with
     *  ``request(_:for:params:)`` will use the new URL prefix.
     *
     *  - Important: The URL prefix that is assigned to Chica should be a valid URL prefix type registered with your app in Xcode or in the app's Info.plist.
     */
    public func setRequestPrefix(to urlPrefix: String) {
        Chica.logger.info("URL prefix changed from \(self.urlPrefix) to \(urlPrefix).")
        self.urlPrefix = urlPrefix
    }

    /// Resets the URL prefix of the Chica client to the default URL prefix.
    ///
    /// When calling this method, future requests will use the default URL prefix of `starlight://`.
    public func resetRequestPrefix() {
        Chica.logger.info("Restored default url prefix: URL prefix changed from \(self.urlPrefix) to \(Chica.DEFAULT_URL_PREFIX).")
        self.urlPrefix = Chica.DEFAULT_URL_PREFIX
    }

    /// Returns a URLRequest with the specified URL, http method, and query parameters.
    static private func makeRequest(
        _ method: Method,
        url: URL,
        params: [String: String]? = nil,
        body: [String: String]? = nil,
        headers: [String: String]? = nil
    ) -> URLRequest {

        var request: URLRequest
        var url = url

        if let params = params {
            for (_, value) in params.enumerated() {
                url = url.queryItem(value.key, value: value.value)
            }
        }

        request = URLRequest(url: url)

        request.addValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        if let body = body {

            assert(method == .post, "A GET request can't have body arguments.")

            var bodyItems: String = ""

            for (index, value) in body.enumerated() {
                bodyItems.append(contentsOf: "\(value.key)=\(value.value)\(index == body.count - 1 ? "" : "&")")
            }

            request.httpBody = bodyItems.data(using: String.Encoding.utf8);
            request.httpMethod = method.rawValue
        }

        if let headers = headers {
            for (_, value) in headers.enumerated() {
                request.addValue(value.value, forHTTPHeaderField: value.key)
            }
        }

        if case .authenthicated(let token) = Chica.OAuth.shared.authState {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            Chica.logger.info("Added authorization token \"\(token)\" to URL session configuration headers.")
        }

        return request

    }

    public func request<T: Decodable>(
        _ method: Method,
        for endpoint: Endpoint,
        queryParams: [String: String]? = nil,
        body: [String: String]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T? {

        var content: T?
        let url = Self.API_URL.appendingPathComponent(endpoint.path)

        defer {
            Chica.logger.info("\(method.rawValue) request to endpoint \"\(url)\" finished.")
        }

        let (data, response) = try await self.session.data(
            for: Self.makeRequest(
                method,
                url: url,
                params: queryParams,
                body: body,
                headers: headers
            )
        )

        Chica.logger.trace("Received data: \(String(bytes: data, encoding: .utf8)! as NSObject)")

        content = try JSONDecoder().decode(
            T.self,
            from: FetchError.processResponse(
                data: data,
                response: response
            )
        )

        return content

    }

}
