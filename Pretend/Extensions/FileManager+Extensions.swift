import Foundation

extension FileManager {
    static func messageImagesDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let imagesDirectory = documentsDirectory.appendingPathComponent("MessageImages")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        return imagesDirectory
    }
    
    static func saveMessageImage(_ imageData: Data) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = messageImagesDirectory().appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    static func getMessageImage(fileName: String) -> Data? {
        let fileURL = messageImagesDirectory().appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
    
    static func deleteMessageImage(fileName: String) {
        let fileURL = messageImagesDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    static func messageAudiosDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let audiosDirectory = documentsDirectory.appendingPathComponent("MessageAudios")
        
        if !FileManager.default.fileExists(atPath: audiosDirectory.path) {
            try? FileManager.default.createDirectory(at: audiosDirectory, withIntermediateDirectories: true)
        }
        
        return audiosDirectory
    }
    
    static func deleteMessageAudio(fileName: String) {
        let fileURL = messageAudiosDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
} 