//
//  User+CoreDataProperties.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var email: String?
    @NSManaged public var password: String?
    @NSManaged public var name: String?
    @NSManaged public var preferences: String?
    @NSManaged public var recipes: NSSet?
    @NSManaged public var pantryItems: NSSet?
    @NSManaged public var shoppingListItems: NSSet?
    @NSManaged public var favoriteRecipes: NSSet?
    @NSManaged public var avatarColorHex: String?
    @NSManaged public var isCurrent: Bool

}

// MARK: Generated accessors for recipes
extension User {

    @objc(addRecipesObject:)
    @NSManaged public func addToRecipes(_ value: Recipe)

    @objc(removeRecipesObject:)
    @NSManaged public func removeFromRecipes(_ value: Recipe)

    @objc(addRecipes:)
    @NSManaged public func addToRecipes(_ values: NSSet)

    @objc(removeRecipes:)
    @NSManaged public func removeFromRecipes(_ values: NSSet)

}

// MARK: Generated accessors for pantryItems
extension User {

    @objc(addPantryItemsObject:)
    @NSManaged public func addToPantryItems(_ value: PantryItem)

    @objc(removePantryItemsObject:)
    @NSManaged public func removeFromPantryItems(_ value: PantryItem)

    @objc(addPantryItems:)
    @NSManaged public func addToPantryItems(_ values: NSSet)

    @objc(removePantryItems:)
    @NSManaged public func removeFromPantryItems(_ values: NSSet)

}

// MARK: Generated accessors for shoppingListItems
extension User {

    @objc(addShoppingListItemsObject:)
    @NSManaged public func addToShoppingListItems(_ value: ShoppingListItem)

    @objc(removeShoppingListItemsObject:)
    @NSManaged public func removeFromShoppingListItems(_ value: ShoppingListItem)

    @objc(addShoppingListItems:)
    @NSManaged public func addToShoppingListItems(_ values: NSSet)

    @objc(removeShoppingListItems:)
    @NSManaged public func removeFromShoppingListItems(_ values: NSSet)

}

// MARK: Generated accessors for favoriteRecipes
extension User {

    @objc(addFavoriteRecipesObject:)
    @NSManaged public func addToFavoriteRecipes(_ value: Recipe)

    @objc(removeFavoriteRecipesObject:)
    @NSManaged public func removeFromFavoriteRecipes(_ value: Recipe)

    @objc(addFavoriteRecipes:)
    @NSManaged public func addToFavoriteRecipes(_ values: NSSet)

    @objc(removeFavoriteRecipes:)
    @NSManaged public func removeFromFavoriteRecipes(_ values: NSSet)

}

extension User : Identifiable {

}
