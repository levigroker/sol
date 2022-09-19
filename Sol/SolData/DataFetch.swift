//
//  DataFetch.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation

/**
Fetches data from an HTTP URL
*/
struct DataFetch {
	typealias Etag = String

	enum DataFetchError: Error, CustomStringConvertible {
		case invalidServerResponse
		case invalidServerStatus(code: Int)
		case matchingEtag(etag: String)

		var description: String {
			switch self {
			case .invalidServerResponse:
				return "invalidServerResponse"
			case .invalidServerStatus(let code):
				return "invalidServerStatus: \(code)"
			case .matchingEtag(let etag):
				return "matchingEtag: '\(etag)'"
			}
		}
	}

	let url: URL

	init(url: URL) {
		self.url = url
	}

	func fetch() async throws -> (Data, Etag?) {
		let (data, response) = try await URLSession.shared.data(from: url)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw DataFetchError.invalidServerResponse
		}
		guard httpResponse.statusCode == 200 else {
			throw DataFetchError.invalidServerStatus(code: httpResponse.statusCode)
		}
		let etag = httpResponse.value(forHTTPHeaderField: "Etag")
		return (data, etag)
	}

	func fetchIfNonMatching(etag: String?) async throws -> (Data, Etag?) {
		// If we don't have an etag, fetch directly
		guard etag != nil else {
			return try await fetch()
		}
		guard let remoteEtag = try await fetchEtag() else {
			// No "Etag" header, so fetch directly
			return try await fetch()
		}
		guard remoteEtag != etag else {
			throw DataFetchError.matchingEtag(etag: remoteEtag)
		}

		return try await fetch()
	}

	func fetchEtag() async throws -> Etag? {
		// Perform a HEAD request to get the response headers
		var request = URLRequest(url: url)
		request.httpMethod = "HEAD"
		let (_, response) = try await URLSession.shared.data(for: request)
		// Get the Etag header from the response
		let httpResponse = response as? HTTPURLResponse
		let etag = httpResponse?.value(forHTTPHeaderField: "Etag")
		return etag
	}
}
