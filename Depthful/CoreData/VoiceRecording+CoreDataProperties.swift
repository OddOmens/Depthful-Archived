//
//  VoiceRecording+CoreDataProperties.swift
//  Depthful
//
//  Created by User on 5/19/25.
//
//

import Foundation
import CoreData


extension VoiceRecording {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VoiceRecording> {
        return NSFetchRequest<VoiceRecording>(entityName: "VoiceRecording")
    }

    @NSManaged public var audioData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var transcription: String?
    @NSManaged public var thought: Thought?

}

extension VoiceRecording : Identifiable {

}
