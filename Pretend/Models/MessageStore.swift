import Foundation
import CoreData

struct InMemoryMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let type: MessageType
    var messageType: String { type.rawValue }
}

class MessageStore: ObservableObject {
    static let shared = MessageStore()
    
    @Published private var messages: [ChatPartner: [InMemoryMessage]] = [:]
    
    func getMessages(for partner: ChatPartner) -> [Message] {
        return messages[partner]?.map { msg in
            let message = Message(context: PersistenceController.shared.container.viewContext)
            message.content = msg.content
            message.isUser = msg.isUser
            message.timestamp = msg.timestamp
            message.type = msg.type
            message.messageType = msg.messageType
            return message
        } ?? []
    }
    
    func addMessage(_ content: String, isUser: Bool, type: MessageType, for partner: ChatPartner) {
        let newMessage = InMemoryMessage(
            id: UUID(),
            content: content,
            isUser: isUser,
            timestamp: Date(),
            type: type
        )
        
        var partnerMessages = messages[partner] ?? []
        partnerMessages.append(newMessage)
        messages[partner] = partnerMessages
        objectWillChange.send()
    }
    
    func deleteMessage(_ message: Message, for partner: ChatPartner) {
        var partnerMessages = messages[partner] ?? []
        partnerMessages.removeAll { msg in
            msg.timestamp == message.timestamp && 
            msg.content == message.content &&
            msg.type.rawValue == message.type.rawValue
        }
        messages[partner] = partnerMessages
        objectWillChange.send()
    }
    
    func clearMessages(for partner: ChatPartner) {
        messages[partner] = []
        objectWillChange.send()
    }
    
    func removeAllMessages() {
        messages.removeAll()
        objectWillChange.send()
    }
} 