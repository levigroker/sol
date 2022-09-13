//
//  SDODataManager.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation
import RegexBuilder
import os

class SDODataManager {

	enum SDODataManagerError: Error {
		case badURL
	}

	// Unless otherwise stated, ImageSets:
	//  - do not contain 3072 resolution
	//  - do contain pfss variants
	enum ImageSet: String {
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
	}

	enum Resolution: String {
		case x256 = "256"
		case x512 = "512"
		case x1024 = "1024"
		case x2048 = "2048"
		case x3072 = "3072"
		case x4096 = "4096"
	}

	init() {
		remoteListings = loadRemoteListings(dir: dataStoreRootDir)
	}

	/// Gathers images with the given criteria. This will attempt to load from local caches but may fetch images from the remote system.
	/// - parameter date: The day of the desired images
	/// - parameter imageSet: The ImageSet which the images belong to
	/// - parameter resolution: The desired Resolution of the images
	/// - parameter pfss: Should the images belong to the `pfss` subset (defaults to `false`)?
	/// - returns: A tuple containing the desired image keys and the appropriate DataStore
	func images(date: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool = false) async throws -> (Array<String>, DataStore) {
		// Create the regular expression to match our desired image names
		let regex = Self.imageNameRegex(date: date, imageSet: imageSet, resolution: resolution, pfss: pfss)
		Logger().info("Looking for images with date '\(date)' imageSet: '\(imageSet.rawValue)' resolution: '\(resolution.rawValue)' pfss: '\(pfss ? "true" : "false")'")

		// Get the listing of all images for the given day
		let remoteImages = try await remoteImagesFor(date: date)
		let allFilenames = remoteImages.keys
		// Filter to those matching the desired criteria
		let matchingFilenames = allFilenames.filter { key in
			key.wholeMatch(of: regex) != nil
		}

		// Get all the locally cached image names
		let dataStore = dataStoreFor(date: date)
		let allLocalFilenames = try await dataStore.keys()

		// Determine which files we still need to fetch from the remote system
		let neededFilenames = Set(matchingFilenames).subtracting(Set(allLocalFilenames))
		let neededFileMap = neededFilenames.reduce(into: [:]) { partialResult, filename in
			partialResult[filename] = remoteImages[filename]
		}

		// Fetch all needed images from the remote system and cache them in the DataStore
		try await fetchRemoteDatas(neededFileMap, to: dataStore)

		return (matchingFilenames, dataStore)
	}

	func fetchRemoteDatas(_ dataMap: [String: URL], to dataStore: DataStore) async throws {
		var retries:[String: URL] = [:]
		for (key, url) in dataMap {
			do {
				try await fetchRemoteData(key: key, url: url, to: dataStore)
			}
			catch {
				Logger().error("Failed to download '\(url)'. Will retry. Error: \(error)")
				retries[key] = url
			}
		}
		for (key, url) in retries {
			do {
				try await fetchRemoteData(key: key, url: url, to: dataStore)
			}
			catch {
				Logger().error("Again failed to download '\(url)'. Will NOT retry. Error: \(error)")
			}
		}
	}

	func fetchRemoteData(key: String, url: URL, to dataStore: DataStore) async throws {
		let dataFetch = DataFetch(url: url)
		let data = try await dataFetch.fetch()
		try await dataStore.write(key: key, item: data)
		Logger().info("Downloaded '\(key)'")
	}

	/**
	 Gets a dictionary mapping filenames to remote URLs for images in the given day
	 */
	func remoteImagesFor(date: Date) async throws -> [String: URL] {
		let key = Self.fullDateFormatter.string(from: date)
		let today = Self.fullDateFormatter.string(from: Date())

		// If the desired listing is for the current day, we need to refetch it, as the listing is updated throughout the day.
		if key == today {
			return try await remoteListingFor(date: date)
		}

		// Use a cached listing file, if we have one.
		if let existingListingFile = remoteListings[key] {
			return try await readListingsFile(existingListingFile)
		}

		// The desired listing is not for today and not already cached, so
		// fetch and cache the listing
		let listing = try await remoteListingFor(date: date)
		let listingFile = try await cacheRemote(listing: listing, to: dataStoreRootDir, for: date)
		remoteListings[key] = listingFile

		return listing
	}

	/// Reads the listing file from the given URL
	/// - returns: A Dictionary keyed with the filenames and whose values are the remote URLs for the images
	func readListingsFile(_ file: URL) async throws -> [String: URL] {
		let task = Task {
			// Load up the listing file into a dictionary
			let data = try Data(contentsOf: file, options: .mappedIfSafe)
			let listing = try JSONDecoder().decode([String: URL].self, from: data)
			return listing
		}
		return try await task.value
	}

	class var baseSDOImageURL: URL? {
		guard let url:URL = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse") else {
			Logger().error("Unable to create baseSDOImageURL")
			return nil
		}
		return url
	}

	/// Gets the remote URL to the server
	/// - parameter date: The desired day
	/// - parameter filename: The specific filename of the file to retrieve (optional).
	/// - returns: If `filename` is supplied, the URL returned will represent the remote file. If `filename` is nil, the URL returned will represent the directory containing images for the given day
	func remoteImageURLFor(date: Date, filename: String? = nil) throws -> URL {
		guard let baseSDOImageURL = Self.baseSDOImageURL else {
			throw SDODataManagerError.badURL
		}
		let year = Self.yearDateFormatter.string(from: date)
		let month = Self.monthDateFormatter.string(from: date)
		let day = Self.dayDateFormatter.string(from: date)
		var url = baseSDOImageURL.appending(path: year, directoryHint:.isDirectory).appending(path: month, directoryHint:.isDirectory).appending(path: day, directoryHint:.isDirectory)
		if let filename = filename {
			url.append(path: filename, directoryHint:.notDirectory)
		}

		return url
	}

	func dataStoreFor(date: Date) -> DataStore {
		let key = Self.fullDateFormatter.string(from: date)
		let existingDataStore = dataStores[key]
		if let existingDataStore = existingDataStore {
			return existingDataStore
		}
		let rootDir = dataStoreRootDir.appending(path: key, directoryHint:.isDirectory)
		let dataStore = FileSystemDataStore(rootDir: rootDir)
		dataStores[key] = dataStore
		return dataStore
	}

	class var yearDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy" // Like "2022"
		return formatter
	}
	class var monthDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "MM" // Like "10"
		return formatter
	}
	class var dayDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "dd" // Like "05"
		return formatter
	}
	class var fullDateFormatter: DateFormatter {
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
	class func imageNameRegex(date: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool) -> Regex<Substring> {
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
	private var dataStoreRootDir: URL {
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
	private var dataStores:[String: DataStore] = [:]

	/// Mapping of date string (yyyyMMdd) to local file URL containing the remote image listing for the given day
	private var remoteListings:[String: URL] = [:]

	/// The file suffix for remote listing files
	private static let remoteListingFileSuffix = "_listing.json"

	/// Inspects the filesystem for remote listing files in the given directory
	///	- parameter dir: A URL representing the directory to inspect for cached listing files
	/// - returns: A dictionary with keys representing the imageDateFormat and values of URLs to the local remote listing files
	func loadRemoteListings(dir: URL) -> [String: URL] {
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
	func remoteListingFor(date: Date) async throws -> [String: URL] {
		let remoteDir = try remoteImageURLFor(date: date)
		// Fetch the links from the remote directory, and map them by filename
		let links = try await LinkFetcher.parseLinks(dir: remoteDir).reduce(into: Dictionary<String,URL>()) { partialResult, url in
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
	func cacheRemote(listing: [String: URL], to dir: URL, for date: Date) async throws -> URL {
		// Cache the listing into a local file
		let task = Task {
			// Write out the dictionary listing to file
			let data = try JSONEncoder().encode(listing)
			let key = Self.fullDateFormatter.string(from: date)
			let filename = "\(key)\(Self.remoteListingFileSuffix)"
			let file = dir.appending(path: filename, directoryHint:.notDirectory)
			try data.write(to: file, options: .atomic)
			return file
		}
		return try await task.value
	}
}

