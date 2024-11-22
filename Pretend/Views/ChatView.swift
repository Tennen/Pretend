import SwiftUI
import CoreData
import PhotosUI
import AVFoundation

extension Message {
    var type: MessageType {
        get {
            MessageType(rawValue: messageType ?? "text") ?? .text
        }
        set {
            messageType = newValue.rawValue
        }
    }
}

struct ChatView: View {
    let chatPartner: ChatPartner?
    @FetchRequest private var persistedMessages: FetchedResults<Message>
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var messageStore = MessageStore.shared
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isTextFieldFocused: Bool
    @State private var scrollToBottom = false
    @StateObject private var audioManager = AudioManager()
    @State private var isRecording = false
    @State private var recordingURL: URL?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditView = false
    
    var messages: [Message] {
        guard let partner = chatPartner else { return [] }
        return partner.persistHistory ? Array(persistedMessages) : messageStore.getMessages(for: partner)
    }
    
    init(chatPartner: ChatPartner?) {
        self.chatPartner = chatPartner
        
        // Create a fetch request for messages specific to this chat partner
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        if let partner = chatPartner {
            request.predicate = NSPredicate(format: "chatPartner == %@", partner)
        }
        
        _persistedMessages = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat partner info - more compact design
            HStack(spacing: 16) {
                if let partner = chatPartner,
                   let avatarData = partner.avatar,
                   let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .shadow(color: Color("Primary").opacity(0.4), radius: 5, x: 0, y: 3)
                        .overlay(
                            Circle()
                                .stroke(Color("Primary").opacity(0.2), lineWidth: 2)
                        )
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color("Primary"))
                        .shadow(color: Color("Primary").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                if let partner = chatPartner {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.nickname ?? "No One")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color("Primary"))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingEditView = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(Color("Primary"))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color("Primary").opacity(0.1))
                        )
                }
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: Color("Primary").opacity(0.15), radius: 4, x: 0, y: 2)
            
            // Chat messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.timestamp)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        scrollToBottom = true
                    }
                }
                .onChange(of: scrollToBottom) { scroll in
                    if scroll, let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.timestamp, anchor: .bottom)
                        }
                        scrollToBottom = false
                    }
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.timestamp, anchor: .bottom)
                    }
                }
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        isTextFieldFocused = false
                    }
            )
            
            // Updated input bar
            HStack(spacing: 8) {
                // Voice recording button
                Button(action: handleVoiceButton) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("Primary"))
                        .overlay(
                            Group {
                                if isRecording {
                                    Circle()
                                        .stroke(Color("Primary"), lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.5)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)
                                }
                            }
                        )
                }
                .padding(.leading, 8)
                
                TextField("Message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 8)
                    .focused($isTextFieldFocused)
                
                // Image picker button
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(Color("Primary"))
                }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                            ? Color("Primary").opacity(0.15)
                            : Color("Primary")
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing, 8)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .top
            )
        }
        .onChange(of: selectedImage) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await sendImageMessage(imageData: data)
                    scrollToBottom = true
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive {
                if let partner = chatPartner, !partner.persistHistory {
                    deleteAllMessages()
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            if let partner = chatPartner {
                ChatPartnerEditView(chatPartner: partner)
            }
        }
        .environmentObject(messageStore)
    }
    
    private func sendImageMessage(imageData: Data) async {
        guard let partner = chatPartner,
              let uiImage = UIImage(data: imageData),
              let compressedData = await compressImage(uiImage) else { return }
        
        if partner.persistHistory {
            if let fileName = FileManager.saveMessageImage(compressedData) {
                let newMessage = Message(context: viewContext)
                newMessage.content = fileName
                newMessage.isUser = true
                newMessage.timestamp = Date()
                newMessage.chatPartner = partner
                newMessage.type = .image
                newMessage.messageType = MessageType.image.rawValue
                
                do {
                    try viewContext.save()
                } catch {
                    print("Error saving image message: \(error)")
                    FileManager.deleteMessageImage(fileName: fileName)
                }
            }
        } else {
            if let fileName = FileManager.saveMessageImage(compressedData) {
                messageStore.addMessage(
                    fileName,
                    isUser: true,
                    type: .image,
                    for: partner
                )
            }
        }
    }
    
    private func compressImage(_ image: UIImage) async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 1024, height: 1024)
                let size = image.size
                
                let widthRatio  = targetSize.width  / size.width
                let heightRatio = targetSize.height / size.height
                
                var newSize: CGSize
                if widthRatio > heightRatio {
                    newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
                } else {
                    newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
                }
                
                let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: rect)
                let newImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                let compressedData = newImage?.jpegData(compressionQuality: 0.7)
                continuation.resume(returning: compressedData)
            }
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, let partner = chatPartner else { return }
        
        if partner.persistHistory {
            let newMessage = Message(context: viewContext)
            newMessage.content = trimmedText
            newMessage.isUser = true
            newMessage.timestamp = Date()
            newMessage.chatPartner = partner
            newMessage.type = .text
            newMessage.messageType = MessageType.text.rawValue
            
            do {
                try viewContext.save()
                messageText = ""
                scrollToBottom = true
            } catch {
                print("Error saving message: \(error)")
            }
        } else {
            messageStore.addMessage(
                trimmedText,
                isUser: true,
                type: .text,
                for: partner
            )
            messageText = ""
            scrollToBottom = true
        }
    }
    
    private func handleVoiceButton() {
        if isRecording {
            if audioManager.stopRecording() {
                // Send the recorded audio message
                if let url = recordingURL {
                    sendVoiceMessage(url: url)
                }
            }
            isRecording = false
        } else {
            if let url = audioManager.startRecording() {
                recordingURL = url
                isRecording = true
            }
        }
    }
    
    private func sendVoiceMessage(url: URL) {
        let fileName = url.lastPathComponent
        guard let partner = chatPartner else { return }
        
        if partner.persistHistory {
            let newMessage = Message(context: viewContext)
            newMessage.content = fileName
            newMessage.isUser = true
            newMessage.timestamp = Date()
            newMessage.chatPartner = partner
            newMessage.type = .voice
            newMessage.messageType = MessageType.voice.rawValue
            
            do {
                try viewContext.save()
                scrollToBottom = true
            } catch {
                print("Error saving voice message: \(error)")
                FileManager.deleteMessageAudio(fileName: fileName)
            }
        } else {
            messageStore.addMessage(
                fileName,
                isUser: true,
                type: .voice,
                for: partner
            )
            scrollToBottom = true
        }
    }
    
    private func deleteAllMessages() {
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
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting messages: \(error)")
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showingContextMenu = false
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var messageStore: MessageStore
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            switch message.type {
            case .image:
                if let fileName = message.content,
                   let imageData = FileManager.getMessageImage(fileName: fileName),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(16)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.image = uiImage
                            }) {
                                Label("Copy Image", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                            }) {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(role: .destructive, action: deleteMessage) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                
            case .voice:
                if let fileName = message.content {
                    AudioMessagePlayer(fileName: fileName)
                        .contextMenu {
                            Button(role: .destructive, action: deleteMessage) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                
            case .text:
                Text(message.content ?? "")
                    .padding(12)
                    .background(message.isUser ? Color("Primary") : Color(.systemGray6))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                        }) {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive, action: deleteMessage) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            
            if !message.isUser { Spacer() }
        }
    }
    
    private func deleteMessage() {
        guard let partner = message.chatPartner else { return }
        
        if partner.persistHistory {
            // Delete from Core Data
            switch message.type {
            case .image:
                FileManager.deleteMessageImage(fileName: message.content ?? "")
            case .voice:
                FileManager.deleteMessageAudio(fileName: message.content ?? "")
            default:
                break
            }
            viewContext.delete(message)
            try? viewContext.save()
        } else {
            // Delete from MessageStore and cleanup any temporary files
            switch message.type {
            case .image:
                FileManager.deleteMessageImage(fileName: message.content ?? "")
            case .voice:
                FileManager.deleteMessageAudio(fileName: message.content ?? "")
            default:
                break
            }
            messageStore.deleteMessage(message, for: partner)
        }
    }
}

struct AudioMessagePlayer: View {
    let fileName: String
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(.white)
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Text(formatTime(totalDuration))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 120)
        }
        .padding(12)
        .background(Color("Primary"))
        .cornerRadius(16)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func setupAudioPlayer() {
        let fileURL = FileManager.messageAudiosDirectory().appendingPathComponent(fileName)
        audioPlayer = try? AVAudioPlayer(contentsOf: fileURL)
        audioPlayer?.delegate = AVPlayerDelegate(onComplete: {
            stopPlayback()
        })
        totalDuration = audioPlayer?.duration ?? 0
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        progress = 0
        currentTime = 0
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
            
            // Update progress and time
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if let player = audioPlayer {
                    progress = player.currentTime / player.duration
                    currentTime = player.currentTime
                    if !player.isPlaying {
                        timer.invalidate()
                        isPlaying = false
                    }
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class AVPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete()
    }
}
