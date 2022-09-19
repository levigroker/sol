//
//  SWPCAPForecast.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import RegexBuilder
import os

// From https://services.swpc.noaa.gov/text/45-day-ap-forecast.txt
// Sample:
/*
:Product: 45 Day AP Forecast  45DF.txt
:Issued: 2022 Sep 17 2119 UTC
# Prepared by the U.S. Air Force.
# Retransmitted by the Dept. of Commerce, NOAA, Space Weather Prediction Center
# Please send comments and suggestions to SWPC.Webmaster@noaa.gov
#
#
#          45-Day AP and F10.7cm Flux Forecast
#-------------------------------------------------------------
45-DAY AP FORECAST
18Sep22 012 19Sep22 008 20Sep22 005 21Sep22 005 22Sep22 005
23Sep22 015 24Sep22 012 25Sep22 014 26Sep22 014 27Sep22 014
28Sep22 008 29Sep22 008 30Sep22 022 01Oct22 050 02Oct22 030
03Oct22 020 04Oct22 012 05Oct22 015 06Oct22 012 07Oct22 010
08Oct22 008 09Oct22 005 10Oct22 010 11Oct22 008 12Oct22 005
13Oct22 015 14Oct22 020 15Oct22 012 16Oct22 005 17Oct22 005
18Oct22 005 19Oct22 005 20Oct22 012 21Oct22 010 22Oct22 014
23Oct22 014 24Oct22 014 25Oct22 008 26Oct22 008 27Oct22 022
28Oct22 050 29Oct22 030 30Oct22 020 31Oct22 012 01Nov22 015
45-DAY F10.7 CM FLUX FORECAST
18Sep22 130 19Sep22 125 20Sep22 125 21Sep22 122 22Sep22 120
23Sep22 120 24Sep22 120 25Sep22 120 26Sep22 120 27Sep22 120
28Sep22 120 29Sep22 120 30Sep22 125 01Oct22 125 02Oct22 125
03Oct22 125 04Oct22 125 05Oct22 125 06Oct22 125 07Oct22 130
08Oct22 130 09Oct22 150 10Oct22 148 11Oct22 143 12Oct22 140
13Oct22 136 14Oct22 130 15Oct22 125 16Oct22 120 17Oct22 125
18Oct22 125 19Oct22 120 20Oct22 120 21Oct22 120 22Oct22 120
23Oct22 120 24Oct22 120 25Oct22 120 26Oct22 120 27Oct22 125
28Oct22 125 29Oct22 125 30Oct22 125 31Oct22 125 01Nov22 125
FORECASTER:  TROST / HOUSSEAL
99999
NNNN
*/
public struct SWPCAPForecast: Codable {

	public typealias Etag = String

	enum SWPCAPForecastError: Error {
		case badURL(message: String)
		case badData(message: String)
	}

	let etag: Etag
	let issuedDate: Date
	let prepared: String
	let forecastAP: [Date: Int]
	let forecastFlux: [Date: Int]

	public init(etag: Etag, issuedDate: Date, prepared: String, forecastAP: [Date: Int], forecastFlux: [Date: Int]) {
		self.etag = etag
		self.issuedDate = issuedDate
		self.prepared = prepared
		self.forecastAP = forecastAP
		self.forecastFlux = forecastFlux
	}

	static func from(data: Data, etag: Etag) throws -> SWPCAPForecast {
		let text = String(data: data, encoding: .utf8)
		guard let text else {
			throw SWPCAPForecastError.badData(message: "Unable to interpret given data as utf8 string.")
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
			throw SWPCAPForecastError.badData(message: "[issuedDate] Unable to find match")
		}
		let issuedText = String(issuedMatch.1)
		guard let issuedDate = issuedDateFormatter.date(from: issuedText) else {
			throw SWPCAPForecastError.badData(message: "[issuedDate] Unable to interpret '\(issuedText)' as date")
		}

		let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

		let preparedQuery = "# Prepared "
		let preparedIndex = lines.firstIndex(where: { $0.hasPrefix(preparedQuery) })
		guard let preparedIndex else {
			throw SWPCAPForecastError.badData(message: "[prepared] Unable to find expected '\(preparedQuery)' line")
		}
		let preparedSequence = lines[preparedIndex...]
		let preparedEndIndex = preparedSequence.firstIndex(where: { $0 == "#" })
		guard let preparedEndIndex else {
			throw SWPCAPForecastError.badData(message: "[prepared] Unable to find end of Prepared section")
		}
		let preparedTextData = preparedSequence[..<preparedEndIndex].map({ String($0.dropFirst(2)) })
		let preparedText = preparedTextData.joined(separator: "\n")

		// Forecast data

		// Get the blocks of data following the "45-DAY AP FORECAST" and "45-DAY F10.7 CM FLUX FORECAST" headers (and before the "FORECASTER:" header)
		let apHeader = "45-DAY AP FORECAST"
		let apHeaderIndex = lines.firstIndex(where: { $0.hasPrefix(apHeader) })
		guard let apHeaderIndex else {
			throw SWPCAPForecastError.badData(message: "[forecastAP] Unable to find expected '\(apHeader)' header")
		}
		let fluxHeader = "45-DAY F10.7 CM FLUX FORECAST"
		let fluxHeaderIndex = lines.firstIndex(where: { $0.hasPrefix(fluxHeader) })
		guard let fluxHeaderIndex else {
			throw SWPCAPForecastError.badData(message: "[forecastAP] Unable to find expected '\(fluxHeader)' header")
		}
		let forecasterHeader = "FORECASTER:"
		let forecasterHeaderIndex = lines.firstIndex(where: { $0.hasPrefix(forecasterHeader) })
		guard let forecasterHeaderIndex else {
			throw SWPCAPForecastError.badData(message: "[forecastAP] Unable to find expected '\(forecasterHeader)' header")
		}

		let apTextData = lines[(apHeaderIndex + 1)..<fluxHeaderIndex].joined(separator: "\n")
		let fluxTextData = lines[(fluxHeaderIndex + 1)..<forecasterHeaderIndex].joined(separator: "\n")

		let apData = try forecastDataFrom(text: apTextData)
		let fluxData = try forecastDataFrom(text: fluxTextData)

		return SWPCAPForecast(etag: etag, issuedDate: issuedDate, prepared: preparedText, forecastAP: apData, forecastFlux: fluxData)
	}

	static func forecastDataFrom(text: String) throws -> [Date: Int] {
		// Match date/value pairs (like "18Sep22 012") with regex (like "(?<date>[0-9]{2}[A-Za-z]{3}[0-9]{2}) (?<val>[0-9]{3})"
		let date = Reference(Substring.self)
		let val = Reference(Substring.self)
		let forecast = Regex {
			Capture(as: date) {
				Regex {
					Repeat(count: 2) {
						One(.digit)
					}
					Repeat(count: 3) {
						CharacterClass(
							("A"..."Z"),
							("a"..."z")
						)
					}
					Repeat(count: 2) {
						One(.digit)
					}
				}
			}
			" "
			Capture(as: val) {
				Repeat(count: 3) {
					One(.digit)
				}
			}
		}
		.anchorsMatchLineEndings()

		let matches = text.matches(of: forecast)

		var forecastData = [Date: Int]()
		for match in matches {
			let dateTxt = String(match[date])
			let valTxt = String(match[val])

			let date = forecastDateFormatter.date(from: dateTxt)
			guard let date else {
				throw SWPCAPForecastError.badData(message: "[forecastAP] unable to interpret '\(dateTxt)' as Date")
			}
			let val = Int(valTxt)
			guard let val else {
				throw SWPCAPForecastError.badData(message: "[forecastAP] unable to interpret '\(valTxt)' as Int")
			}
			forecastData[date] = val
		}
		return forecastData
	}

	static func readFrom(file: URL) async throws -> SWPCAPForecast {
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
		formatter.dateFormat = "yyyy MMM dd HHmm z" // Like "2022 Sep 17 2119 UTC"
		return formatter
	}

	public static var forecastDateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMMyy" // Like "18Sep22"
		return formatter
	}

	static func swpcDataURL() throws -> URL {
		guard let _swpcDataURL else {
			guard let url = URL(string: swpcDataURLTxt) else {
				throw SWPCAPForecastError.badURL(message: "Unexpectedly unable create URL from '\(swpcDataURLTxt)'")
			}
			Self._swpcDataURL = url
			return url
		}
		return _swpcDataURL
	}
	private static let swpcDataURLTxt = "https://services.swpc.noaa.gov/text/45-day-ap-forecast.txt"
	private static var _swpcDataURL: URL?
}
