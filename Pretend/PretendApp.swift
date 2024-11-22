//
//  PretendApp.swift
//  Pretend
//
//  Created by Tennen on 2024/11/21.
//

import SwiftUI

@main
struct PretendApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Customize TabBar appearance
        let appearance = UITabBarAppearance()
        appearance.backgroundColor = UIColor(Color("Primary").opacity(0.1))
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color("Primary").opacity(0.5))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color("Primary").opacity(0.5))]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color("Primary"))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color("Primary"))]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
