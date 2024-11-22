import SwiftUI
import CoreData

struct ChatPartnerEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let chatPartner: ChatPartner?
    @State private var nickname: String = ""
    @State private var persistHistory: Bool = false
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var showingDeleteAlert = false
    
    var isNewPartner: Bool {
        chatPartner == nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Avatar")
                        Spacer()
                        if let partner = chatPartner,
                           let avatarData = partner.avatar,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else if let image = inputImage {
                            Image(uiImage: image)
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
                    }
                    .onTapGesture {
                        showingImagePicker = true
                    }
                    
                    TextField("Nickname", text: $nickname)
                    
                    Toggle("Save Chat History", isOn: $persistHistory)
                    
                    if !persistHistory {
                        Text("Chat history will be deleted when the app is closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !isNewPartner {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Chat Partner")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNewPartner ? "New Chat Partner" : "Edit Chat Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        savePartner()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .alert("Delete Chat Partner", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePartner()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this chat partner? This action cannot be undone.")
        }
        .onAppear {
            if let partner = chatPartner {
                nickname = partner.nickname ?? ""
                persistHistory = partner.persistHistory
            }
        }
    }
    
    private func savePartner() {
        let partner = chatPartner ?? ChatPartner(context: viewContext)
        
        if !persistHistory && partner.persistHistory {
            deleteAllMessages(for: partner)
        }
        
        partner.nickname = nickname
        partner.persistHistory = persistHistory
        
        if let image = inputImage,
           let data = image.jpegData(compressionQuality: 0.8) {
            partner.avatar = data
        }
        
        try? viewContext.save()
    }
    
    private func deleteAllMessages(for partner: ChatPartner) {
        let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chatPartner == %@", partner)
        
        do {
            let messages = try viewContext.fetch(fetchRequest)
            for message in messages {
                switch message.type {
                case .image:
                    FileManager.deleteMessageImage(fileName: message.content ?? "")
                case .voice:
                    FileManager.deleteMessageAudio(fileName: message.content ?? "")
                default:
                    break
                }
                viewContext.delete(message)
            }
            try viewContext.save()
        } catch {
            print("Error deleting messages: \(error)")
        }
    }
    
    private func deletePartner() {
        if let partner = chatPartner {
            viewContext.delete(partner)
            try? viewContext.save()
        }
    }
} 
