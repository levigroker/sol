//
//  DataStore.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation

protocol DataStore {
	func keys() async throws -> Array<String>
	func exists(key: String) async throws -> Bool
	func read(key: String) async throws -> Data
	func write(key: String, item: Data) async throws
	func delete(key: String) async throws
}
