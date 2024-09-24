//
//  SettingsView.swift
//  gary-for-beatbox
//
//  Created by Kevin Griffing on 9/25/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var modelName: String
    @Binding var promptDuration: Int
    @Binding var isPresented: Bool // Binding to control the presentation

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Settings")) {
                    TextField("Model Name", text: $modelName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Stepper(value: $promptDuration, in: 1...15) {
                        Text("Prompt Duration: \(promptDuration) seconds")
                    }
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(leading:
                Button("Cancel") {
                    isPresented = false
                },
                trailing:
                Button("Save") {
                    isPresented = false
                }
            )
        }
    }
}
