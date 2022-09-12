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

	enum DataFetchError: Error {
		case invalidServerResponse
		case invalidServerStatus(code: Int)
	}

	let url: URL

	init(url: URL) {
		self.url = url
	}

	func fetch() async throws -> Data {
		let (data, response) = try await URLSession.shared.data(from: url)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw DataFetchError.invalidServerResponse
		}
		guard httpResponse.statusCode == 200 else {
			throw DataFetchError.invalidServerStatus(code: httpResponse.statusCode)
		}
		return data
	}
}
