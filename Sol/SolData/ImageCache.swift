//
//  ImageCache.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-12.
//

import Foundation
import UIKit

actor ImageCache {

	enum ImageCacheError: Error {
		case invalidImageData(key: String)
	}

	init(dataStore: DataStore) {
		self.dataStore = dataStore
	}

	public func image(key: String) async throws -> UIImage {
		// Check for the image (or an active task) in our cache and return the image
		if let item = cache[key] {
			switch item {
			case .awaiting(let task):
				return try await task.value
			case .cached(let image):
				return image
			}
		}

		// We don't have the image in our cache, so we need to read it from a DataStore
		// Create a Task to read it in as an image
		let task: Task<UIImage, Error> = Task {
			let data = try await dataStore.read(key: key)
			guard let image = UIImage(data: data) else {
				throw ImageCacheError.invalidImageData(key: key)
			}
			return image
		}

		// We store the task in the cache to provide re-entrant protection while the task is being awaited
		cache[key] = .awaiting(task)
		// await the task
		let image = try await task.value
		// Update our cache with the actual image
		cache[key] = .cached(image)

		return image
	}

	private let dataStore: DataStore
	// In-memory cache by 'key'
	// NOTE: We will need to consider cache size and item management (remove item, flush all) so we can control memory use by the cache, but presently we are caching everything in memory
	private var cache: [String: CacheItem] = [:]

	private enum CacheItem {
		// Still loading
		case awaiting(Task<UIImage, Error>)
		// Available currently
		case cached(UIImage)
	}
}
