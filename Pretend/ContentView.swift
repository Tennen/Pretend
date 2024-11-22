//
//  ContentView.swift
//  Pretend
//
//  Created by Tennen on 2024/11/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ChatPartner.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatPartner.nickname, ascending: true)],
        animation: .default
    ) private var chatPartners: FetchedResults<ChatPartner>
    
    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                if chatPartners.isEmpty {
                    Text("Add a chat partner in Settings")
                        .tabItem {
                            Label("Chat", systemImage: "message")
                        }
                        .tag(0)
                } else {
                    ChatPartnerListView()
                        .tabItem {
                            Label("Chat", systemImage: "message")
                        }
                        .tag(0)
                }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(1)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
