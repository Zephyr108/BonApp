//
//  PantryItem+CoreDataProperties.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//
//

import Foundation
import CoreData


extension PantryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PantryItem> {
        return NSFetchRequest<PantryItem>(entityName: "PantryItem")
    }

    @NSManaged public var name: String?
    @NSManaged public var quantity: String?
    @NSManaged public var category: String?
    @NSManaged public var owner: User?

}

extension PantryItem : Identifiable {

}
