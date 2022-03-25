//
//  ExampleProjectApp.swift
//  Shared
//
//  Created by Alex Modroño Vara on 20/7/21.
//

import SwiftUI
import Chica

@main
struct ExampleProjectApp: App {

    @State var deeplink: Deeplinker.Deeplink? {
        didSet {

            //  A bit of a workaround until Apple releases a fully working
            //  alternative to DispatchQueue.main.asyncAfter()
            Task {

                //  For some reason Apple decided it was a good idea to have to
                //  pass the time as nanoseconds.
                //
                //  Delay of 0.2 seconds (1 second = 1_000_000_000 nanoseconds)
                try? await Task.sleep(nanoseconds: 200_000_000)

                //  Now we refresh the deeplink
                Deeplinker.shared.refresh(&deeplink)

            }

        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.deeplink, self.deeplink)
                .task {
                    Chica.shared.setRequestPrefix(for: "exampleproject")
                }
                .onOpenURL { url in

                    // TODO: Add different URL endpoints here for deep linking.
                    // Maybe like Apollo?
                    do {
                        self.deeplink = try Deeplinker.shared.manage(url: url)
                    } catch {
                        print(error)
                    }

                }
        }
    }
}
