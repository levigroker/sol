//
//  LinkFetcher.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-10.
//

import Foundation

struct LinkFetcher {

	enum LinkFetcherError: Error {
		case invalidHTMLContent
	}

	/**
	 Parse links from the given "directory" URL and return them in an array, relative to the given URL.
	 */
	static func parseLinks(dir: URL) async throws -> Array<URL> {
		// Perform asynchronously
		let task = Task {
			// Fetch the HTML data and convert to a utf8 string
			let dataFetch = DataFetch(url: dir)
			let htmlData = try await dataFetch.fetch()
			guard let htmlContent = String(data: htmlData, encoding: .utf8) else {
				throw LinkFetcherError.invalidHTMLContent
			}
			// Parse the HTML using regex for all hrefs
			// NOTE: This is not ideal in that we could be more robust by using an acutal HTML parsing engine, but considering the static nature of the expected content, the lack of a Foundataion provided HTML parser, and the desire to limit external dependencies, I've opted to use this regular expression approach.
			// See: https://blog.codinghorror.com/parsing-html-the-cthulhu-way/
			let linkMatcher = #/<a href="(?<url>.*?)">.*?</a>/#
			// Our regex captures the link as a string, so we convert it to a URL object, if possible.
			let links = htmlContent.matches(of: linkMatcher).compactMap { match -> URL? in
				let url = URL(string: String(match.url), relativeTo: dir)
				return url
			}
			return links
		}
		return try await task.value
	}
}
