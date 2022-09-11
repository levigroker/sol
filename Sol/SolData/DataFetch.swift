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
	}

	let url: URL

	init(url: URL) {
		self.url = url
	}

	func fetch() async throws -> Data {
		let (data, response) = try await URLSession.shared.data(from: url)
		guard let httpResponse = response as? HTTPURLResponse,
			  httpResponse.statusCode == 200 /* OK */ else {
			throw DataFetchError.invalidServerResponse
		}
		return data
	}
}
