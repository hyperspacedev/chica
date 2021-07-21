# ``Chica``

Connect to Twitter and a Mastodon instance simultaneously and asynchronously.

## Overview

Chica is a Swift library that lets you make authenticated requests to Twitter and Mastodon simultaneously. This library is designed with concurrency in mind and will work with your asynchronous code. With a few lines of code, it's pretty easy to make a request:

```swift
let account: Account? = try await Chica()
    .request(.get, for: .account(id: "1"))
```

## Topics

### Making Network Requests

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
