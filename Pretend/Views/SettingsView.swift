import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ChatPartner.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatPartner.nickname, ascending: true)],
        animation: .default
    ) private var chatPartners: FetchedResults<ChatPartner>
    
    @State private var showingAddPartner = false
    @State private var selectedPartner: ChatPartner?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chatPartners) { partner in
                    Section(header: Text(partner.nickname ?? "")) {
                        Button {
                            selectedPartner = partner
                        } label: {
                            HStack {
                                if let avatarData = partner.avatar,
                                   let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(partner.nickname ?? "")
                                        .foregroundColor(.primary)
                                    Text(partner.persistHistory ? "Saving chat history" : "Not saving chat history")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let partner = chatPartners[index]
                        viewContext.delete(partner)
                    }
                    try? viewContext.save()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPartner = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPartner) {
            ChatPartnerEditView(chatPartner: nil)
        }
        .sheet(item: $selectedPartner) { partner in
            ChatPartnerEditView(chatPartner: partner)
        }
    }
}
