//
//  RecipeStep+CoreDataProperties.swift
//  BonApp
//
//  Created by Marcin on 30/04/2025.
//
//

import Foundation
import CoreData


extension RecipeStep {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecipeStep> {
        return NSFetchRequest<RecipeStep>(entityName: "RecipeStep")
    }

    @NSManaged public var instruction: String?
    @NSManaged public var order: Int16
    @NSManaged public var recipe: Recipe?

}
