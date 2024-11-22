import SwiftUI
import CoreData

struct ChatPartnerListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ChatPartner.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatPartner.nickname, ascending: true)],
        animation: .default
    ) private var chatPartners: FetchedResults<ChatPartner>
    
    var body: some View {
        NavigationView {
            List(chatPartners) { partner in
                NavigationLink(
                    destination: ChatView(chatPartner: partner)
                ) {
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
                        Text(partner.nickname ?? "")
                            .padding(.leading, 8)
                    }
                }
            }
            .navigationTitle("Chats")
        }
    }
} 
