//
//  SolActor.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-16.
//

import Foundation
import SwiftUI
import os
import SolData

enum SolActorError: Error {
	case noData(message: String)
	case inProgress(message: String)
}

actor SolActor {

	func updateSDOImages() async throws -> UIImage {
		let now = Date()
		// Kick off a pre-fetch of what is configured in User Defaults
		// NOTE: we don't care if this fails or need to await it here... we just want to ensure we have a head start on the expected data needs
		Task {
			try? await SDODataManager.shared.prefetchImages(date: now, imageSet: Settings.sdoImageSet(), resolution: Settings.sdoResolution(), pfss: Settings.sdoPFSS())
		}

		sdoImages = try await SDODataManager.shared.sdoImages(date: now, imageSet: Settings.sdoImageSet(), resolution: Settings.sdoResolution(), pfss: Settings.sdoPFSS())
		currentSDOImageIndx = 0
		let mostRecent = sdoImages.first
		guard let mostRecent = mostRecent else {
			throw SolActorError.noData(message: "No images available for today (\(SDODataManager.fullDateFormatter.string(from: now)))yet.")
		}
		let image = try await SDODataManager.shared.image(mostRecent)
		return image
	}

	func nextOlderImage() async throws -> UIImage {
		// NOTE: the sdoImage array is sorted in decending order, so to get an older image increase the index
		let index = currentSDOImageIndx + 1
		// Asking for older images than we have
		if index >= sdoImages.count {
			if previousDayTask == nil {
				Logger().debug("Asking for older images than we have... (creating new previousDayTask)")
				var updatedSDOImages = Array(sdoImages)
				let task = Task<[SDOImage], Error> {
					let oldestSDOImage = sdoImages.last
					let previousDay = oldestSDOImage?.day.previousDay ?? Date()
					let previousDayImages = try await SDODataManager.shared.sdoImages(date: previousDay, imageSet: oldestSDOImage?.imageSet ?? Settings.sdoImageSet(), resolution: oldestSDOImage?.resolution ?? Settings.sdoResolution(), pfss: oldestSDOImage?.pfss ?? Settings.sdoPFSS())
					Logger().debug("found \(previousDayImages.count) older image\(previousDayImages.count == 1 ? "" : "s") in \(SDODataManager.fullDateFormatter.string(from: previousDay))...")
					guard !previousDayImages.isEmpty else {
						throw SolActorError.noData(message: "No older images available.")
					}
					Logger().debug("prefetching images for \(SDODataManager.fullDateFormatter.string(from: previousDay))")
					try await SDODataManager.shared.prefetch(sdoImages: previousDayImages)
					updatedSDOImages.append(contentsOf: previousDayImages)
					return updatedSDOImages
				}
				previousDayTask = task
				Logger().debug("Awaiting new previousDayTask")
				sdoImages = try await task.value
				Logger().debug("previousDayTask complete. sdoImages.count: \(self.sdoImages.count)")
				previousDayTask = nil
			}
			else {
				throw SolActorError.inProgress(message: "Please wait")
			}
		}

		currentSDOImageIndx = index
		let sdoImage = sdoImages[currentSDOImageIndx]
		Logger().debug("next older: '\(sdoImage.key)'")
		let image = try await SDODataManager.shared.image(sdoImage)
		return image
	}

	func nextNewerImage() async throws -> UIImage {
		guard !sdoImages.isEmpty else {
			throw SolActorError.noData(message: "No images available.")
		}
		// NOTE: the sdoImage array is sorted in decending order, so to get a newer image decrease the index
		let index = currentSDOImageIndx - 1
		// Asking for more recent images than what we presently have
		if index < 0 {
			throw SolActorError.noData(message: "Fetching newer images not implemented yet")
			// TODO : Need a way to get the deltas from what we have already for today and reload
			//			sdoImages = try await SDODataManager.shared.sdoImages(date: Date(), imageSet: settingImageSet, resolution: settingResolution, pfss: settingPFSS, cacheOK: false)
			//			let mostRecent = sdoImages.first
			//			guard let mostRecent = mostRecent else {
			//				throw Sol.error(message: "No images available for today.")
			//			}
			//			let image = try await SDODataManager.shared.image(mostRecent)
		}

		currentSDOImageIndx = index
		let sdoImage = sdoImages[currentSDOImageIndx]
		Logger().debug("next newer: '\(sdoImage.key)'")
		let image = try await SDODataManager.shared.image(sdoImage)
		return image
	}

	// State
	private var sdoImages = [SDOImage]()
	private var currentSDOImageIndx = 0
	private var previousDayTask: Task<[SDOImage], Error>?
}

extension Date {
	var nextDay: Date {
		return Calendar.current.date(byAdding: .day, value: 1, to: self) ?? self
	}

	var previousDay: Date {
		return Calendar.current.date(byAdding: .day, value: -1, to: self) ?? self
	}
}
