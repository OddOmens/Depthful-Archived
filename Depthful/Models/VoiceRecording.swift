import Foundation
import CoreData

class VoiceRecording: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var audioData: Data
    @NSManaged public var duration: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var thought: Thought?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}

extension VoiceRecording {
    static var entityName: String { "VoiceRecording" }
    
    static func fetchRequest() -> NSFetchRequest<VoiceRecording> {
        return NSFetchRequest<VoiceRecording>(entityName: entityName)
    }
} 