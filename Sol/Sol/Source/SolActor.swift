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
		sdoImages = try await SDODataManager.shared.sdoImages(date: now, imageSet: settingImageSet, resolution: settingResolution, pfss: settingPFSS)
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
			Logger().debug("Asking for older images than we have...")
			if previousDayTask == nil {
				Logger().debug("Creating new previousDayTask")
				var updatedSDOImages = Array(sdoImages)
				let task = Task<[SDOImage], Error> {
					let oldestSDOImage = sdoImages.last
					let previousDay = oldestSDOImage?.day.previousDay ?? Date()
					let previousDayImages = try await SDODataManager.shared.sdoImages(date: previousDay, imageSet: oldestSDOImage?.imageSet ?? settingImageSet, resolution: oldestSDOImage?.resolution ?? settingResolution, pfss: oldestSDOImage?.pfss ?? settingPFSS)
					Logger().debug("found \(previousDayImages.count) older image\(previousDayImages.count == 1 ? "" : "s") in \(SDODataManager.fullDateFormatter.string(from: previousDay))...")
					guard !previousDayImages.isEmpty else {
						throw SolActorError.noData(message: "No older images available.")
					}
					updatedSDOImages.append(contentsOf: previousDayImages)
					return updatedSDOImages
				}
				Logger().debug("Assigning new previousDayTask")
				previousDayTask = task
				Logger().debug("Awaiting new previousDayTask")
				sdoImages = try await task.value
				Logger().debug("sdoImages.count: \(self.sdoImages.count)")
				Logger().debug("Nilling new previousDayTask")
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
		var index = currentSDOImageIndx - 1
		// Asking for more recent images than what we presently have
		if index < 0 {
			Logger().error("Fetching newer images not implemented yet")
			// TODO : Need a way to get the deltas from what we have already for today and reload
			//			sdoImages = try await SDODataManager.shared.sdoImages(date: Date(), imageSet: settingImageSet, resolution: settingResolution, pfss: settingPFSS, cacheOK: false)
			//			let mostRecent = sdoImages.first
			//			guard let mostRecent = mostRecent else {
			//				throw Sol.error(message: "No images available for today.")
			//			}
			//			let image = try await SDODataManager.shared.image(mostRecent)
			index = 0
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

	// Settings
	@AppStorage(Settings.sdoImageSet.rawValue)
	private var settingImageSet: SDOImage.ImageSet = Settings.default.sdoImageSet // swift compiler gets confused without specifying the type here

	@AppStorage(Settings.sdoResolution.rawValue)
	private var settingResolution = Settings.default.sdoResolution

	@AppStorage(Settings.sdoPFSS.rawValue)
	private var settingPFSS = Settings.default.sdoPFSS
}

extension Date {
	var nextDay: Date {
		return Calendar.current.date(byAdding: .day, value: 1, to: self) ?? self
	}

	var previousDay: Date {
		return Calendar.current.date(byAdding: .day, value: -1, to: self) ?? self
	}
}
