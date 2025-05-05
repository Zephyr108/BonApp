//
//  ShoppingListItem+CoreDataProperties.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//
//

import Foundation
import CoreData


extension ShoppingListItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingListItem> {
        return NSFetchRequest<ShoppingListItem>(entityName: "ShoppingListItem")
    }

    @NSManaged public var name: String?
    @NSManaged public var quantity: String?
    @NSManaged public var isBought: Bool
    @NSManaged public var owner: User?

}

extension ShoppingListItem : Identifiable {

}
