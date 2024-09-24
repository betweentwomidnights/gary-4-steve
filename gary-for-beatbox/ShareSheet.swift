//
//  ShareSheet.swift
//  gary-for-beatbox
//
//  Created by Kevin Griffing on 9/26/24.
//

import Foundation
import SwiftUI
import UIKit

// Wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
