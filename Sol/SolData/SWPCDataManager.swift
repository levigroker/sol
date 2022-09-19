//
//  SWPCDataManager.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import RegexBuilder
import os

public actor SWPCDataManager {

	public enum SWPCDataManagerError: Error {
		case unlikely(message: String)
	}

	/// Singleton
	/// We only want one data manager managing things, so only create one
	public static let shared = SWPCDataManager()

	init() {
	}

	static func geoAlert() async throws -> SWPCGeoAlert {
		var cachedAlert: SWPCGeoAlert?

		// Check for a cached version
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
			try await alert.writeAs(file: cachedURL)
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


	private static let persistedSWPCGeoAlertFilename = "SWPCGeoAlert.json"
}
