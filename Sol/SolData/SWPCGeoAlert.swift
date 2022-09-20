//
//  SWPCGeoAlert.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import RegexBuilder
import os

// From http://services.swpc.noaa.gov/text/wwv.txt
// Sample:
/*
:Product: Geophysical Alert Message wwv.txt
:Issued: 2022 Sep 18 1805 UTC
# Prepared by the US Dept. of Commerce, NOAA, Space Weather Prediction Center
#
#          Geophysical Alert Message
#
Solar-terrestrial indices for 17 September follow.
Solar flux 132 and estimated planetary A-index 5.
The estimated planetary K-index at 1800 UTC on 18 September was 2.

Space weather for the past 24 hours has been minor.
Radio blackouts reaching the R1 level occurred.

No space weather storms are predicted for the next 24 hours.
*/

public struct SWPCGeoAlert: Codable {

	public typealias Etag = String

	enum SWPCGeoAlertError: Error {
		case badURL(message: String)
		case badData(message: String)
	}

	let etag: Etag
	public let issuedDate: Date
	public let prepared: String
	public let body: String

	public init(etag: Etag, issuedDate: Date, prepared: String, body: String) {
		self.etag = etag
		self.issuedDate = issuedDate
		self.prepared = prepared
		self.body = body
	}

	static func from(data: Data, etag: Etag) throws -> SWPCGeoAlert {
		let text = String(data: data, encoding: .utf8)
		guard let text else {
			throw SWPCGeoAlertError.badData(message: "Unable to interpret given data as utf8 string.")
		}
		// Like `:Issued:\s* (?<issued>.+)`
		let issuedRegex = Regex {
			":Issued:"
			ZeroOrMore(.whitespace)
			Capture() {
				OneOrMore {
					/./
				}
			}
		}
		.anchorsMatchLineEndings()

		guard let issuedMatch = text.firstMatch(of: issuedRegex) else {
			throw SWPCGeoAlertError.badData(message: "[issuedDate] Unable to find match")
		}
		let issuedText = String(issuedMatch.1)
		guard let issuedDate = issuedDateFormatter.date(from: issuedText) else {
			throw SWPCGeoAlertError.badData(message: "[issuedDate] Unable to interpret '\(issuedText)' as date")
		}

		// Like `^#\s*(Prepared.*)`
		let preparedRegex = Regex {
			/^/
				"#"
			ZeroOrMore(.whitespace)
			Capture {
				Regex {
					"Prepared"
					ZeroOrMore {
						/./
					}
				}
			}
		}
		.anchorsMatchLineEndings()

		guard let preparedMatch = text.firstMatch(of: preparedRegex) else {
			throw SWPCGeoAlertError.badData(message: "[prepared] Unable to find match")
		}
		let preparedText = String(preparedMatch.1)

		var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
		if let i = lines.lastIndex(where: { $0.hasPrefix(":") || $0.hasPrefix("#") }) {
			lines.removeFirst(i + 1)
		}
		let body = lines.joined(separator: "\n")

		return SWPCGeoAlert(etag: etag, issuedDate: issuedDate, prepared: preparedText, body: body)
	}

	static func readFrom(file: URL) async throws -> SWPCGeoAlert {
		let task = Task {
			// Read and decode from file
			let data = try Data(contentsOf: file, options: .mappedIfSafe)
			let alert = try JSONDecoder().decode(self, from: data)
			return alert
		}
		return try await task.value
	}

	func writeAs(file: URL) async throws {
		let task = Task {
			// Encode and write out to file
			let data = try JSONEncoder().encode(self)
			try data.write(to: file, options: .atomic)
		}
		return try await task.value
	}

	public static var issuedDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy MMM dd HHmm z" // Like "2022 Sep 18 1805 UTC"
		return formatter
	}

	static func swpcDataURL() throws -> URL {
		guard let _swpcDataURL else {
			guard let url = URL(string: swpcDataURLTxt) else {
				throw SWPCGeoAlertError.badURL(message: "Unexpectedly unable create URL from '\(swpcDataURLTxt)'")
			}
			Self._swpcDataURL = url
			return url
		}
		return _swpcDataURL
	}
	private static let swpcDataURLTxt = "https://services.swpc.noaa.gov/text/wwv.txt"
	private static var _swpcDataURL: URL?
}
