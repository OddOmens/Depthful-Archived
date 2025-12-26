//
//  Thought+CoreDataProperties.swift
//  Depthful
//
//  Created by User on 2/20/25.
//
//

import Foundation
import CoreData


extension Thought {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Thought> {
        return NSFetchRequest<Thought>(entityName: "Thought")
    }

    @NSManaged public var content: String?
    @NSManaged public var tag: String?
    @NSManaged public var tags: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var creationDate: Date?
    @NSManaged public var images: Data?
    @NSManaged public var favorite: Bool
    @NSManaged public var recordings: NSSet?

}

// MARK: Generated accessors for recordings
extension Thought {

    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: VoiceRecording)

    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: VoiceRecording)

    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)

    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)

}

extension Thought : Identifiable {

}
