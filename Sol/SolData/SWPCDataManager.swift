//
//  SWPCDataManager.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import RegexBuilder
import os

// Protocol encapsulating SWPCAPForecast and SWPCGeoAlert common functionality
//protocol SWPCData {
//	typealias Etag = String
//
//	func etag() -> Etag
//	func issuedDate() -> Date
//	func writeAs(file: URL) async throws
//
//	static func from(data: Data, etag: Etag) throws -> SWPCData
//	static func readFrom(file: URL) async throws -> SWPCData
//	static func swpcDataURL() throws -> URL
//}

public enum SWPCDataManager {

	public enum SWPCDataManagerError: Error {
		case unlikely(message: String)
	}

	//TODO: Convert to generic function capable of handling both SWPCAPForecast and SWPCGeoAlert

	public static func apForecast() async throws -> SWPCAPForecast {
		var cachedAlert: SWPCAPForecast?

		// Check for a cached version
		try FileManager.default.createDirectory(at: dataStoreRootDir, withIntermediateDirectories: true)
		let cachedURL = dataStoreRootDir.appending(path: Self.persistedSWPCAPForecastFilename, directoryHint: .notDirectory)
		do {
			let alert = try await SWPCAPForecast.readFrom(file: cachedURL)
			cachedAlert = alert
		}
		catch {
			Logger().warning("Unable to read persisted SWPCAPForecast from '\(cachedURL.path(percentEncoded: false))'. Error: \(error)")
		}

		let url = try SWPCAPForecast.swpcDataURL()
		let dataFetch = DataFetch(url: url)

		do {
			let (data, etag) = try await dataFetch.fetchIfNonMatching(etag: cachedAlert?.etag)
			let alert = try SWPCAPForecast.from(data: data, etag: etag ?? "<unknown>")
			Logger().info("SWPCAPForecast (downloaded) issued: \(alert.issuedDate)")
			do {
				try await alert.writeAs(file: cachedURL)
			}
			catch {
				Logger().error("Unable to write SWPCAPForecast to '\(cachedURL.path(percentEncoded: false))'. Error: \(error)")
			}
			return alert
		}
		catch {
			switch error {
			case DataFetch.DataFetchError.matchingEtag:
				guard let cachedAlert else {
					throw SWPCDataManagerError.unlikely(message: "cachedAlert unexpectedly nil")
				}
				Logger().info("SWPCAPForecast (cached) issued: \(cachedAlert.issuedDate)")
				return cachedAlert
			default:
				throw error
			}
		}
	}

	public static func geoAlert() async throws -> SWPCGeoAlert {
		var cachedAlert: SWPCGeoAlert?

		// Check for a cached version
		try FileManager.default.createDirectory(at: dataStoreRootDir, withIntermediateDirectories: true)
		let cachedURL = dataStoreRootDir.appending(path: Self.persistedSWPCGeoAlertFilename, directoryHint: .notDirectory)
		do {
			let alert = try await SWPCGeoAlert.readFrom(file: cachedURL)
			cachedAlert = alert
		}
		catch {
			Logger().warning("Unable to read persisted SWPCGeoAlert from '\(cachedURL.path(percentEncoded: false))'. Error: \(error)")
		}

		let url = try SWPCGeoAlert.swpcDataURL()
		let dataFetch = DataFetch(url: url)

		do {
			let (data, etag) = try await dataFetch.fetchIfNonMatching(etag: cachedAlert?.etag)
			let alert = try SWPCGeoAlert.from(data: data, etag: etag ?? "<unknown>")
			Logger().info("SWPCGeoAlert (downloaded) issued: \(alert.issuedDate)")
			do {
				try await alert.writeAs(file: cachedURL)
			}
			catch {
				Logger().error("Unable to write SWPCGeoAlert to '\(cachedURL.path(percentEncoded: false))'. Error: \(error)")
			}
			return alert
		}
		catch {
			switch error {
			case DataFetch.DataFetchError.matchingEtag:
				guard let cachedAlert else {
					throw SWPCDataManagerError.unlikely(message: "cachedAlert unexpectedly nil")
				}
				Logger().info("SWPCGeoAlert (cached) issued: \(cachedAlert.issuedDate)")
				return cachedAlert
			default:
				throw error
			}
		}
	}

	/// The root directory to store SWPC data
	private static var dataStoreRootDir: URL {
		var baseURL: URL
		do {
			baseURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		}
		catch {
			Logger().error("Unable to get caches directory. Defaulting to temp directory. Error: \(error)")
			baseURL = FileManager.default.temporaryDirectory
		}
		baseURL.append(path: "SWPC")
		return baseURL
	}

	private static let persistedSWPCAPForecastFilename = "SWPCAPForecast.json"
	private static let persistedSWPCGeoAlertFilename = "SWPCGeoAlert.json"
}
