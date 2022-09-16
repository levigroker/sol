//
//  SDODataManager.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import UIKit
import RegexBuilder
import os

public actor SDODataManager {

	public enum SDODataManagerError: Error {
		case badURL
		case invalidImageData(key: String)
	}

	// Unless otherwise stated, ImageSets:
	//  - do not contain 3072 resolution
	//  - do contain pfss variants
	public enum ImageSet: String, CaseIterable {
		case i0094 = "0094" // no 256 resolution
		case i0131 = "0131"
		case i0171 = "0171"
		case i0193 = "0193"
		case i0211 = "0211"
		case i0304 = "0304"
		case i0335 = "0335"
		case i1600 = "1600"
		case i1700 = "1700"
		case i4500 = "4500" // no pfss variant
		case iHMI171 = "HMI171"
		case iHMIB = "HMIB"
		case iHMII = "HMII" // no pfss variant
		case iHMID = "HMID" // no pfss variant
		case iHMIBC = "HMIBC" // no pfss variant, contains 3072 resolution
		case iHMIIF = "HMIIF" // no pfss variant, contains 3072 resolution
		case iHMIIC = "HMIIC" // no pfss variant, contains 3072 resolution
		// Composite of 0094, 0335, and 0193
		case i094335193 = "094335193"
		// Composite of 0304, 0211, and 0171
		case i304211171 = "304211171"
		// Composite of 0211, 0193, and 0171
		case i211193171 = "211193171" // contains 3072 resolution
		// Composite of 0211, 0193, and 0171, with dimmed corona
		case i211193171n = "211193171n" // no pfss variant, contains 3072 resolution
		// Appears to be the same as 211193171
		case i211193171rg = "211193171rg" // no pfss variant, contains 3072 resolution

		public func name() -> String {
			switch self {
			case .i0094: return "AIA 94 Å"
			case .i0131: return "AIA 131 Å"
			case .i0171: return "AIA 171 Å"
			case .i0193: return "AIA 193 Å"
			case .i0211: return "AIA 221 Å"
			case .i0304: return "AIA 304 Å"
			case .i0335: return "AIA 335 Å"
			case .i1600: return "AIA 1600 Å"
			case .i1700: return "AIA 1700 Å"
			case .i4500: return "AIA 4500 Å"
			case .iHMI171: return "AIA 171 Å & HMIB"
			case .iHMIB: return "HMI Magnetogram"
			case .iHMII: return "HMI Intensitygram"
			case .iHMID: return "HMI Dopplergram"
			case .iHMIBC: return "HMI Colorized Magnetogram"
			case .iHMIIF: return "HMI Intensitygram - Flattened"
			case .iHMIIC: return "HMI Intensitygram - Colored"
			case .i094335193: return "AIA 94 Å, 335 Å, 193 Å"
			case .i304211171: return "AIA 304 Å, 211 Å, 171 Å"
			case .i211193171: return "AIA 211 Å, 193 Å, 171 Å"
			case .i211193171n: return "AIA 211 Å, 193 Å, 171 Å n"
			case .i211193171rg: return "AIA 211 Å, 193 Å, 171 Å rg"
			}
		}
	}

	public enum Resolution: String, CaseIterable {
		case x256 = "256"
		case x512 = "512"
		case x1024 = "1024"
		case x2048 = "2048"
		case x3072 = "3072"
		case x4096 = "4096"
	}
	/// Singleton
	/// We only want one data manager managing things, so only create one
	public static let shared = SDODataManager()

	private init() {
		remoteListings = Self.loadRemoteListings(dir: Self.dataStoreRootDir)
	}

	/// Populates local cache with images with the given criteria
	/// - parameter date: The day of the desired images
	/// - parameter imageSet: The ImageSet which the images belong to
	/// - parameter resolution: The desired Resolution of the images
	/// - parameter pfss: Should the images belong to the `pfss` subset (defaults to `false`)?
	/// - returns: A tuple containing the desired image keys and the appropriate DataStore
	func prefetchImages(date: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool = false) async throws {
		let sdoImages = try await sdoImages(date: date, imageSet: imageSet, resolution: resolution, pfss: pfss)
		let sdoImagesByKey = sdoImages.reduce(into: [:]) { partialResult, sdoImage in
			partialResult[sdoImage.key] = sdoImage
		}

		// Get all the locally cached image names
		let dataStore = dataStoreFor(date: date)
		let allLocalFilenames = try await dataStore.keys()

		// Determine which files we still need to fetch from the remote system
		let neededFilenames = Set(sdoImagesByKey.keys).subtracting(Set(allLocalFilenames))
		let neededSDOImages = neededFilenames.compactMap { sdoImagesByKey[$0] }

		// Fetch all needed images from the remote system and cache them in the DataStore
		try await Self.fetchRemote(sdoImages: neededSDOImages, to: dataStore)
	}

	/// Gathers metadata for images with the given criteria.
	/// - parameter date: The day of the desired images
	/// - parameter imageSet: The ImageSet which the images belong to
	/// - parameter resolution: The desired Resolution of the images
	/// - parameter pfss: Should the images belong to the `pfss` subset (defaults to `false`)?
	/// - returns: A tuple containing the desired image keys and the appropriate DataStore
	func sdoImages(date: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool = false) async throws -> [SDOImage] {
		// Create the regular expression to match our desired image names
		let regex = Self.imageNameRegex(date: date, imageSet: imageSet, resolution: resolution, pfss: pfss)
		Logger().info("Looking for images with date '\(Self.fullDateFormatter.string(from: date))' imageSet: '\(imageSet.rawValue)' resolution: '\(resolution.rawValue)' pfss: '\(pfss ? "true" : "false")'")

		// Get the listing of all images for the given day
		let remoteImages = try await remoteImagesFor(date: date)
		let allFilenames = remoteImages.keys
		// Filter to those matching the desired criteria
		let matchingFilenames = allFilenames.filter { key in
			key.wholeMatch(of: regex) != nil
		}

		let sdoImages = matchingFilenames.compactMap({ filename in
			if let remoteURL = remoteImages[filename] {
				return SDOImage(key: filename, day: date, remoteURL: remoteURL)
			}
			return nil
		})
		.sorted()

		return sdoImages
	}

	/// Get the UImage associated with the given SDOImage
	/// This will attempt to load from local caches but may fetch images from the remote system.
	/// - parameter The SDOImage whose UIImage to retreive
	public func image(_ sdoImage: SDOImage) async throws -> UIImage {
		// Check for the image (or an active task) in our cache and return the image
		if let item = sdoImageCache[sdoImage.key] {
			switch item.state {
			case .awaiting(let task):
				return try await task.value
			case .cached(let image):
				return image
			case .uninitiated:
				break // Continue below to initiate image retrieval
			}
		}

		// We don't have the image in our cache
		// Create a Task to retreive it as needed
		let task: Task<UIImage, Error> = Task {
			// First let's try to get it from the data store
			let dataStore = dataStoreFor(date: sdoImage.day)
			var data = try? await dataStore.read(key: sdoImage.key)

			// If we don't get the image data from the data store, fetch it from the remote
			if data == nil {
				data = try await Self.fetchRemoteData(sdoImage: sdoImage, to: dataStore)
			}

			// Create the UIImage from the data, if we have it
			guard let data = data, let image = UIImage(data: data) else {
				throw SDODataManagerError.invalidImageData(key: sdoImage.key)
			}
			return image
		}

		// We create new metadata state containing the task, and store it in the cache to provide re-entrant protection while the task is being awaited
		var updatedSDOImage = sdoImage
		updatedSDOImage.state = SDOImage.State.awaiting(task)
		sdoImageCache[updatedSDOImage.key] = updatedSDOImage
		// await the task
		let image = try await task.value
		// Update our cache with the actual image
		updatedSDOImage.state = SDOImage.State.cached(image)
		sdoImageCache[updatedSDOImage.key] = updatedSDOImage

		return image
	}

	// In-memory cache of SDOImages by 'key'
	// NOTE: We will need to consider cache size and item management (remove item, flush all) so we can control memory use by the cache, but presently we are caching everything in memory
	private var sdoImageCache: [SDOImageKey: SDOImage] = [:]

	/// Fetches the Data of the given images and attempts to write it to the given data store
	/// - parameter sdoImage: The image metadata of the desired image
	/// - parameter dataStore: The DataStore instance to write the image data to
	/// - returns: The image data for the desired image
	static func fetchRemote(sdoImages: [SDOImage], to dataStore: DataStore) async throws {
		var retries = [SDOImage]()
		for sdoImage in sdoImages {
			do {
				_ = try await fetchRemoteData(sdoImage: sdoImage, to: dataStore, storeFailureThrows: true)
			}
			catch {
				Logger().error("Failed to cache image '\(sdoImage.remoteURL)'. Will retry. Error: \(error)")
				retries.append(sdoImage)
			}
		}
		for sdoImage in retries {
			do {
				_ = try await fetchRemoteData(sdoImage: sdoImage, to: dataStore, storeFailureThrows: true)
			}
			catch {
				Logger().error("Again failed to cache image '\(sdoImage.remoteURL)'. Will NOT retry. Error: \(error)")
			}
		}
	}

	/// Fetches the Data of the given image and attempts to write it to the given data store
	/// - parameter sdoImage: The image metadata of the desired image
	/// - parameter dataStore: The DataStore instance to write the image data to
	/// - parameter storeFailureThrows: If `true` a failure to write to the data store is considered fatal and the error is thrown. If `false` the priority is to return the Data even if it can not be written to the DataStore
	/// - returns: The image data for the desired image
	static func fetchRemoteData(sdoImage: SDOImage, to dataStore: DataStore, storeFailureThrows: Bool = false) async throws -> Data {
		let dataFetch = DataFetch(url: sdoImage.remoteURL)
		let data = try await dataFetch.fetch()
		Logger().info("Downloaded '\(sdoImage.key)'")
		do {
			try await dataStore.write(key: sdoImage.key, item: data)
		}
		catch {
			if storeFailureThrows {
				throw error
			}
			// Catch the error and just log it, since we have the data
			Logger().error("Unable to persist '\(sdoImage.key)' to data store. Error: \(error)")
		}
		return data
	}

	/// Gets a dictionary mapping filenames to remote URLs for images in the given day
	/// - parameter date: A Date representing the day whose associated images to return
	/// - returns: A Dictionary of remote URLs keyed by image filenames
	func remoteImagesFor(date: Date) async throws -> [String: URL] {
		let key = Self.fullDateFormatter.string(from: date)
		let today = Self.fullDateFormatter.string(from: Date())

		// If the desired listing is for the current day, we need to refetch it, as the listing is updated throughout the day.
		if key == today {
			return try await Self.remoteListingFor(date: date)
		}

		// Use a cached listing file, if we have one.
		if let existingListingFile = remoteListings[key] {
			return try await Self.readListingsFile(existingListingFile)
		}

		// The desired listing is not for today and not already cached, so
		// fetch and cache the listing
		let listing = try await Self.remoteListingFor(date: date)
		let listingFile = try await Self.cacheRemote(listing: listing, to: Self.dataStoreRootDir, for: date)
		remoteListings[key] = listingFile

		return listing
	}

	/// Reads the listing file from the given URL
	/// - returns: A Dictionary keyed with the filenames and whose values are the remote URLs for the images
	static func readListingsFile(_ file: URL) async throws -> [String: URL] {
		let task = Task {
			// Load up the listing file into a dictionary
			let data = try Data(contentsOf: file, options: .mappedIfSafe)
			let listing = try JSONDecoder().decode([String: URL].self, from: data)
			return listing
		}
		return try await task.value
	}

	static var baseSDOImageURL: URL? {
		guard let url = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse") else {
			Logger().error("Unable to create baseSDOImageURL")
			return nil
		}
		return url
	}

	/// Gets the remote URL to the server
	/// - parameter date: The desired day
	/// - parameter filename: The specific filename of the file to retrieve (optional).
	/// - returns: If `filename` is supplied, the URL returned will represent the remote file. If `filename` is nil, the URL returned will represent the directory containing images for the given day
	static func remoteImageURLFor(date: Date, filename: String? = nil) throws -> URL {
		guard let baseSDOImageURL = Self.baseSDOImageURL else {
			throw SDODataManagerError.badURL
		}
		let year = Self.yearDateFormatter.string(from: date)
		let month = Self.monthDateFormatter.string(from: date)
		let day = Self.dayDateFormatter.string(from: date)
		var url = baseSDOImageURL.appending(path: year, directoryHint: .isDirectory).appending(path: month, directoryHint: .isDirectory).appending(path: day, directoryHint: .isDirectory)
		if let filename = filename {
			url.append(path: filename, directoryHint: .notDirectory)
		}

		return url
	}

	/// Gets the appropriate DataStor for the given day, creating if needed
	/// - parameter date: A Date representing the day associated with the desired DataStore
	/// - returns A DataStore instance associated with the given day
	func dataStoreFor(date: Date) -> DataStore {
		let key = Self.fullDateFormatter.string(from: date)
		let existingDataStore = dataStores[key]
		if let existingDataStore = existingDataStore {
			return existingDataStore
		}
		let rootDir = Self.dataStoreRootDir.appending(path: key, directoryHint: .isDirectory)
		let dataStore = FileSystemDataStore(rootDir: rootDir)
		dataStores[key] = dataStore
		return dataStore
	}

	static var yearDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy" // Like "2022"
		return formatter
	}
	static var monthDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "MM" // Like "10"
		return formatter
	}
	static var dayDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "dd" // Like "05"
		return formatter
	}
	static var fullDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd" // Like "20221005"
		return formatter
	}

	/// Creates a regular expression to match on an image name with the given criteria
	/// - parameter date: The day of the image
	/// - parameter imageSet: The ImageSet which the image belongs to
	/// - parameter resolution: The desired Resolution of the image
	/// - parameter pfss: Should the image belong to the `pfss` subset?
	/// - returns: A regular expression which will match the image name for the given parameters, ignoring the time component of the name (matches all images for a given day, with the appropriate ImageSet, Resolution and pfss status)
	static func imageNameRegex(date: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool) -> Regex<Substring> {
		let formattedDate = fullDateFormatter.string(from: date)
		// "<date>_<time>_<resolution>_<image_set><pfss>.jpg"
		// "\(formattedDate)_\\d+_\(resolution.rawValue)_\(imageSet.rawValue)\(pfss ? "pfss" : "")\\.jpg"
		// Like  "20220909_034253_1024_1700pfss.jpg"
		return Regex {
			formattedDate
			"_"
			OneOrMore(.digit)
			"_"
			resolution.rawValue
			"_"
			imageSet.rawValue
			pfss ? "pfss" : ""
			".jpg"
		}
	}

	/// The root directory to store SDO data
	private static var dataStoreRootDir: URL {
		var baseURL: URL
		do {
			baseURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		}
		catch {
			Logger().error("Unable to get caches directory. Defaulting to temp directory. Error: \(error)")
			baseURL = FileManager.default.temporaryDirectory
		}
		baseURL.append(path: "SDO")
		return baseURL
	}
	/// Mapping of date string (yyyyMMdd) to DataStore instance
	private var dataStores: [String: DataStore] = [:]

	/// Mapping of date string (yyyyMMdd) to local file URL containing the remote image listing for the given day
	private var remoteListings: [String: URL] = [:]

	/// The file suffix for remote listing files
	private static let remoteListingFileSuffix = "_listing.json"

	/// Inspects the filesystem for remote listing files in the given directory
	///	- parameter dir: A URL representing the directory to inspect for cached listing files
	/// - returns: A dictionary with keys representing the imageDateFormat and values of URLs to the local remote listing files
	static func loadRemoteListings(dir: URL) -> [String: URL] {
		do {
			// Make sure we have a directory to inspect
			try FileManager.default.createDirectory(at: dataStoreRootDir, withIntermediateDirectories: true)
			Logger().info("Created SDO root data directory: '\(self.dataStoreRootDir.path(percentEncoded: false))'")
			// Get all the remoteListing files in the given directory
			let remoteListingFiles: [String: URL] = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles).reduce(into: [:]) { partialResult, url in
				guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir == false else {
					return
				}
				let filename = url.lastPathComponent
				guard filename.hasSuffix(Self.remoteListingFileSuffix) else {
					return
				}
				let filePrefix = String(filename.prefix(filename.count - Self.remoteListingFileSuffix.count))
				partialResult[filePrefix] = url
			}
			return remoteListingFiles
		}
		catch {
			Logger().error("Unable to load remote listing files from local filesystem. Error: \(error)")
		}
		return [:]
	}

	/// Fetches the remote listing for the given date
	///	- parameter date: The Date to get the listing of
	/// - returns: A dictionary of links mapped by filename
	static func remoteListingFor(date: Date) async throws -> [String: URL] {
		let remoteDir = try remoteImageURLFor(date: date)
		// Fetch the links from the remote directory, and map them by filename
		let links = try await LinkFetcher.parseLinks(dir: remoteDir).reduce(into: [String: URL]()) { partialResult, url in
			let filename = url.lastPathComponent
			partialResult[filename] = url
		}
		return links
	}

	/// Caches the remote listing for the given date to a local file in the given directory
	///	- parameter listing: A dictionary of links mapped by filename
	///	- parameter to: A URL representing the directory to save the cached listing file
	///	- parameter date: A Date representing the day of the listing
	/// - returns: A URL of the resulting cache file
	static func cacheRemote(listing: [String: URL], to dir: URL, for date: Date) async throws -> URL {
		// Cache the listing into a local file
		let task = Task {
			// Write out the dictionary listing to file
			let data = try JSONEncoder().encode(listing)
			let key = fullDateFormatter.string(from: date)
			let filename = "\(key)\(Self.remoteListingFileSuffix)"
			let file = dir.appending(path: filename, directoryHint: .notDirectory)
			try data.write(to: file, options: .atomic)
			return file
		}
		return try await task.value
	}
}
