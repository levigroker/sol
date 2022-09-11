//
//  DataStore.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation

protocol DataStore<Item> {
	associatedtype Item: Codable & Hashable

	func read(key: String) async throws -> Item
	func write(key: String, item: Item) async throws
	func delete(key: String) async throws
}
