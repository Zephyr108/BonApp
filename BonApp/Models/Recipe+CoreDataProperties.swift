//
//  Recipe+CoreDataProperties.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//
//

import Foundation
import CoreData


extension Recipe {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Recipe> {
        return NSFetchRequest<Recipe>(entityName: "Recipe")
    }

    @NSManaged public var title: String?
    @NSManaged public var detail: String?
    @NSManaged public var images: Data?
    @NSManaged public var ingredients: NSArray?
    @NSManaged public var cookTime: Int16
    @NSManaged public var isPublic: Bool
    @NSManaged public var author: User?
    @NSManaged public var favoritedBy: NSSet?
    @NSManaged public var steps: NSSet?

}

// MARK: Generated accessors for favoritedBy
extension Recipe {

    @objc(addFavoritedByObject:)
    @NSManaged public func addToFavoritedBy(_ value: User)

    @objc(removeFavoritedByObject:)
    @NSManaged public func removeFromFavoritedBy(_ value: User)

    @objc(addFavoritedBy:)
    @NSManaged public func addToFavoritedBy(_ values: NSSet)

    @objc(removeFavoritedBy:)
    @NSManaged public func removeFromFavoritedBy(_ values: NSSet)

}

// MARK: Generated accessors for steps
extension Recipe {
    @objc(addStepsObject:)
    @NSManaged public func addToSteps(_ value: RecipeStep)

    @objc(removeStepsObject:)
    @NSManaged public func removeFromSteps(_ value: RecipeStep)

    @objc(addSteps:)
    @NSManaged public func addToSteps(_ values: NSSet)

    @objc(removeSteps:)
    @NSManaged public func removeFromSteps(_ values: NSSet)
}

extension Recipe : Identifiable {

}
