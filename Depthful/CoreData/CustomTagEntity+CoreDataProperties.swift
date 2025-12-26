//
//  CustomTagEntity+CoreDataProperties.swift
//  Depthful
//
//  Created by User on 2/15/25.
//
//

import Foundation
import CoreData


extension CustomTagEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CustomTagEntity> {
        return NSFetchRequest<CustomTagEntity>(entityName: "CustomTagEntity")
    }

    @NSManaged public var blue: Double
    @NSManaged public var green: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var opacity: Double
    @NSManaged public var red: Double

}

extension CustomTagEntity : Identifiable {

}
