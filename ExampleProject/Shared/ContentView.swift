//
//  ContentView.swift
//  Shared
//
//  Created by Alex Modroño Vara on 20/7/21.
//

import SwiftUI
import Chica

struct ContentView: View {

    @State var instance: String = ""

    var body: some View {

        VStack {

            TextField("Instance domain", text: self.$instance)

            Button(action: {
                Task.init {
                    await Chica.OAuth.shared.startOauthFlow(for: self.instance.lowercased())
                }
            }, label: {
                Text("Log in")
            })

        }
        .padding()

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
