<div align="center">

![Banner](./Resources/banner.png)

![swift 5.5](https://img.shields.io/badge/swift-5.5-blue.svg)
![SwiftUI](https://img.shields.io/badge/-SwiftUI-blue.svg)
![iOS](https://img.shields.io/badge/os-iOS-green.svg)
![iPadOS](https://img.shields.io/badge/os-iPadOS-green.svg)
![macOS](https://img.shields.io/badge/os-macOS-green.svg)
![tvOS](https://img.shields.io/badge/os-tvOS-green.svg)
![watchOS](https://img.shields.io/badge/os-watchOS-green.svg)

<a href="https://github.com/hyperspacedev/starlight"><img src="./Resources/go-to-starlight.png" width="143" height="35"/></a> <a href="https://discord.gg/c69AXwk"><img src="./Resources/discord.png" width="177" height="35"/> </a>
    
</div>

# Index

<!-- Pages -->
[qsp]: #quick-start-%EF%B8%8F
[bfs]: #building-from-source
[spm]: #through-swift-package-manager
[usg]: #usage
[bhttpr]: #basic-http-requests
[bgr]: #basic-get-request-to-obtain-a-mastodon-account
[ppr]: #passing-parameters
[bpr]: #basic-post-request-to-register-an-application-in-an-instance
[oauth]: #oauth
[wcidwi]: #what-can-i-do-with-it
[licensing]: #licensing
[cntrbtn]: #contributions

<!-- Links -->
- [Quick Start 🏃‍♂️][qsp]
    - [Building from source][bfs]
    - [Through Swift Package Manager][spm]
- [Usage][usg]
    - [Basic HTTP requests][bhttpr]
        - [Basic GET request to obtain a Mastodon account][bgr]
            - [Passing parameters][ppr]
        - [Basic POST request to register an application in an instance][bpr]
    - [OAuth][oauth]
- [What can I do with it?][wcidwi]
- [Licensing][licensing]
- [Contributions][cntrbtn]

## Quick Start 🏃‍♂️

> :warning: The following source code is highly experimental and  has been designed in a version of Swift that is still in beta, which will result in this code changing over time. The following code may or may not result in a final product shipped to consumers.

While `chica` is just [starlight][starlight]'s backend put into a separated swift package, you can still import it to your project if you want to work with Mastodon and Twitter endpoints. Think of it as a Twitter + Mastodon API for Swift 5.5, that takes advantage of the new concurrency model.

`chica` can be installed via the Swift Package Manager, or built from source.

### Building from source

To build `chica`, you'll need the following:

- A Mac running macOS 12 (Monterey) or later
- Xcode 13 or higher
- [SwiftLint][sl]

Download the repository code using `gh repo clone` or opening directly in Xcode via GitHub and press the "Run" button to build and run the app. Targets can be changed to reflect the appropriate device to target.

### Through Swift Package Manager

In Xcode 13, go to `File > Swift Packages > Add Package Dependency...`, then paste in `https://github.com/hyperspacedev/chica`

Now just `import Chica`, and you're ready to go!

## Usage

Using chica is a very straight-forward process.

### Basic HTTP requests

#### Basic GET request to obtain a Mastodon account

```swift
let account: Account? = try await Chica().request(.get, for: .account(id: "account id here"))
```

Note that in this case, we will decode all the data we receive as `Account?`. The compiler inferres the data model from the type assigned to the variable. If you are working with functions, the compiler will infer the data type from the returning value:

```swift
func getAccount(id: String) async throws -> Account? {
    return try await Chica().request(.get, for: .account(id: id))
}
```

##### Passing parameters

You can use the `params` argument to pass query arguments to a request.

For example, if you were to obtain the local timeline of an instance, you'll need to pass the `local` query parameter as `true` when doing the request.

For this, just use the following syntax:
```swift
let statuses: [Status?] = try await Chica().request(.get, for: .timeline, params: 
    [
        "local": "true"
    ]
)
```

#### Basic POST request to register an application in an instance.

Doing POST requests is basically the same as doing a get request.

Let's say you are going to register an application on a specific mastodon instance for obtaining a token. Then, all you would need to do is a POST request to the specific endpoint:

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

### OAuth

Everything we've seen so far is pretty good, but it is only useful for accessing public data. Fortunately, Chica supports authorizing users, and it is very straight-forward. Everytime you do a request, Chica tries to add a Bearer token as a header parameter. So, all we need to do is obtain an access token.

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

> ⚠️ **NOTE**: As of version 1.0 of Chica, only `starlight://` is supported as redirect uri. In future versions the option to add other redirect uris will be added.

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

> ⚠️ **NOTE**: You also need to add the URL Scheme to your Xcode target or on Info.plist.

**Congrats, you've obtained user-level access!**

## What can I do with it?

- **Build apps that interact with Mastodon or Twitter —** `chica` was initially built for [starlight][starlight], but we decided to make it a separate package so that it can be reused for several projects. Are you working on an app that may require to show embed tweets or toots? We've got you covered.

- **Learn how the new concurrency model works —** The main benefit of being open-source is that the code is, well, open – and everybody can check it and even contribute to it. Thanks to this, `chica` can serve as a guide for people who want to see some real-examples of the new async/await features introduced by Apple in Swift 5.5.

- **Build tools that leverage the Fediverse or Twitter —** There is no reason why `chica` should only be limited for building apps: it can be used for everything! You can use it for building command line interfaces that interact with these social networks, or you can build a bot that automatically toots whatever you post on twitter (or viceversa); who knows what beatiful things you can achieve with this!

Found a novel use? We'd love to hear about it!

## Licensing

Codename Starlight and it's respective subprojects are licensed under the Non-Violent Public License, the same license used in Hyperspace Desktop. This is a semi-permissive license that allows modifications and redistributions as long as the software is not used to harm another person or cause conflict. You can read your rights in the attached [LICENSE][license] file.

## Contributions

Contribution guidelines are available in the [contributing file][cf] and when you make an issue/pull request. Additionally, you can access our [Code of Conduct][coc].

If you want to aid the project in other ways, consider supporting the project on [Patreon](https://patreon.com/hyperspacedev).

<!-- Links -->
[starlight]: https://github.com/hyperspacedev/starlight
[sl]: https://github.com/realm/swiftlint
[ptrn]: https://patreon.com/hyperspacedev

<!-- Files -->
[license]: LICENSE.txt
[cf]: .github/contributing.md
[coc]: .github/CODE_OF_CONDUCT.md
