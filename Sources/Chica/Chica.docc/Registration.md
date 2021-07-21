#  Registration

Register your project with a Mastodon instance.

To make API requests that require authentication, your project must be registered and granted access to a user's account with an access token.

Registering an application on a specific Mastodon instance for obtaining a token is accomplished with a POST request to the specific endpoint:

```swift
let client: Application? = try! await Chica.shared.request(.post, for: .apps, params:
    [
        "client_name": "name",
        "redirect_uris": "app://ouath",
        "scopes": "read",
        "website": "https://hyperspace.marquiskurt.net"
    ]
)
```

## OAuth

Every time you do a request, Chica tries to add a Bearer token as a header parameter. So, all we need to do is obtain an access token.

For this, first, you need to start the authorization flow:

```swift
Task.init {
    await Chica.OAuth.shared.startOauthFlow(for: "instance domain here")
}
```

This will:

1. Register an application in the specified instance.
2. Once it's registered the application, save the client_id and client_secret in the device's login keychain.
3. Open safari, asking for authorization to the user.

Until this, you'll already have had registered an application and asked the user for authorization, but we are still missing the code that is returned by the instance through the redirect uri.

For this reason, you'll need to add a deeplink handler that will tell chica what's the user authorization code, or you can use the one built-in!

```swift
Chica.handleURL(url: url, actions: [:]) // Where url is the redirect_uri, with the data we need as the query parameters.
```

> Important: As of version 1.0 of Chica, only `starlight://` is supported as redirect uri. In future versions the option to add other redirect uris will be added.

This function will scan if the url contains "oauth", and if it does, it will handle with obtaining the user authorization code by itself.

One good thing about this deep link handler is that you can also use it for your own purposes, thanks to the `actions` parameter:

```swift
Chica.handleURL(url: URL(string: "starlight://whatever?test=true")!, actions:
    [
        "whatever" : { [self] parameters in doWhatever(parameters) }
    ]
)
```

where `doWhatever()` expects `[String : String]?` as a parameter:
```swift
func doWhatever(_ parameters: [String : String]?) {
    print("RECEIVED DEEP LINK...")
    if let parameters = parameters {
        for parameter in parameters {
            print("\(parameter.key) : \(parameter.value)")
        }
    }
}
```

Once you get the user authorization code, Chica will obtain the Token, and store it on the device's `login` keychain. Now, everytime you do a request, the access token will be attached as a header parameter.

>Important: You also need to register the URL Scheme to your Xcode target or on Info.plist.
