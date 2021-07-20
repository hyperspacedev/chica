//
//  ExampleProjectApp.swift
//  Shared
//
//  Created by Alex Modroño Vara on 20/7/21.
//

import SwiftUI
import chica

@main
struct ExampleProjectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Chica.OAuth.handleURL()
                }
        }
    }
}
