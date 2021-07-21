# ``Chica``

Connect to Twitter and a Mastodon instance simultaneously and asynchronously.

## Overview

Chica is a Swift library that lets you make authenticated requests to Twitter and Mastodon simultaneously. This library is designed with concurrency in mind and will work with your asynchronous code. With a few lines of code, it's pretty easy to make a request.

### Basic HTTP requests

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

To learn more about making authenticated requests, see <doc:Registration>.

## Topics

### Making Network Requests

- <doc:Registration>
- ``Chica/Chica``
- ``Chica/Token``
- ``Chica/Endpoint``
- ``Chica/FetchError``

### Mastodon Instances

- ``Chica/Instance``
- ``Chica/Emoji``
- ``Chica/Announcement``
- ``Chica/AnnouncementReaction``

### Accounts

- ``Chica/Account``
- ``Chica/Relationship``
- ``Chica/Field``

### Posts and Statuses

- ``Chica/Status``
- ``Chica/Context``
- ``Chica/Visibility``
- ``Chica/Attachment``
- ``Chica/AttachmentType``
- ``Chica/Tag``
- ``Chica/Mention``
- ``Chica/Card``
- ``Chica/CardType``

### Polls

- ``Chica/Poll``
- ``Chica/PollOption``

### Notifications

- ``Chica/Notification``
- ``Chica/NotificationType``
