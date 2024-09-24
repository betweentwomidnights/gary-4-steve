//
//  gary_for_beatboxApp.swift
//  gary-for-beatbox
//
//  Created by Kevin Griffing on 9/23/24.
//

import SwiftUI

@main
struct gary_for_beatboxApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
