//
//  FileSystemDataStore.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation
import os

struct FileSystemDataStore {

	enum FileSystemDataStoreError: Error {
		case badURL
		case noData
	}

	let rootDir: URL
	let manager = FileManager.default

	init(rootDir: URL) {
		self.rootDir = rootDir
		do {
			try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
			Logger().info("Created DataStore directory: '\(rootDir.path(percentEncoded: false))'")
		}
		catch {
			Logger().error("Unable to create DataStore directory '\(rootDir.path(percentEncoded: false))'. Error: \(error)")
		}
	}

	func urlFor(key: String) throws -> URL {
		guard !key.isEmpty else {
			throw FileSystemDataStoreError.badURL
		}
		guard let url = URL(string: key, relativeTo: rootDir) else {
			throw FileSystemDataStoreError.badURL
		}
		return url
	}
}

extension FileSystemDataStore: DataStore {

	func read(key: String) async throws -> Data {
		let url = try urlFor(key: key)
		let task = Task { () -> Data in
			let data = try Data(contentsOf:url)
			guard data.count > 0 else {
				throw FileSystemDataStoreError.noData
			}
			return data
		}
		return try await task.value
	}

	func write(key: String, item: Data) async throws {
		let url = try urlFor(key: key)
		let task = Task {
			let dir = url.deletingLastPathComponent()
			try manager.createDirectory(at: dir, withIntermediateDirectories: true)
			try item.write(to: url, options: .atomic)
		}
		return try await task.value
	}

	func delete(key: String) async throws {
		let url = try urlFor(key: key)
		let task = Task {
			try manager.removeItem(at:url)
		}
		return try await task.value
	}

}
