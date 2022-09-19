//
//  SolDataTests.swift
//  SolDataTests
//
//  Created by Levi Brown on 2022-09-10.
//

import XCTest
@testable import SolData

final class SolDataTests: XCTestCase {

	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	// DataFetch

	func testFetch100() async throws {
		// This is an example of a functional test case.
		// Use XCTAssert and related functions to verify your tests produce the correct results.
		// Any test you write for XCTest can be annotated as throws and async.
		// Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
		// Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
		guard let url = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse/2022/09/09/") else {
			XCTFail("Unexpectedly unable to create URL from string.")
			return
		}
		let dataFetch = DataFetch(url: url)
		let (data, _) = try await dataFetch.fetch()
		XCTAssertGreaterThan(data.count, 0, "Expected some data.")
	}

	func testFetchEtag100() async throws {
		let url = try SWPCGeoAlert.swpcDataURL()
		let dataFetch = DataFetch(url: url)
		guard let etag = try await dataFetch.fetchEtag() else {
			XCTFail("Unexpectedly no ETag.")
			return
		}

		XCTAssertFalse(etag.isEmpty, "Etag should not be empty.")
	}

	func testFetchIfNonMatching100() async throws {
		let url = try SWPCGeoAlert.swpcDataURL()
		let dataFetch = DataFetch(url: url)
		let (data, _) = try await dataFetch.fetchIfNonMatching(etag: nil)
		XCTAssertGreaterThan(data.count, 0, "Expected some data.")
	}

	func testFetchIfNonMatching200() async throws {
		let url = try SWPCGeoAlert.swpcDataURL()
		let dataFetch = DataFetch(url: url)
		let (data, _) = try await dataFetch.fetchIfNonMatching(etag: "1e6-5e8f9f32f0900")
		XCTAssertGreaterThan(data.count, 0, "Expected some data.")
	}

	func testFetchIfNonMatching300() async throws {
		let url = try SWPCGeoAlert.swpcDataURL()
		let dataFetch = DataFetch(url: url)
		guard let etag = try await dataFetch.fetchEtag() else {
			XCTFail("Unexpectedly no ETag.")
			return
		}
		do {
			_ = try await dataFetch.fetchIfNonMatching(etag: etag)
			XCTFail("Expected matchingEtag error")
			return
		}
		catch {
			switch error {
			case DataFetch.DataFetchError.matchingEtag(let matchingEtag):
				XCTAssertEqual(etag, matchingEtag)
			default:
				XCTFail("Unexpected error: \(error)")
				return
			}
		}
	}

	// LinkFetcher

	func testLinkFetcherFetchLinks100() async throws {
		guard let url = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse/2022/09/09/") else {
			XCTFail("Unexpectedly unable to create URL from string.")
			return
		}
		let links = try await LinkFetcher.parseLinks(dir: url)
		XCTAssertGreaterThan(links.count, 0, "Expected at least one link.")
		XCTAssertEqual(links.count, 13_409)
	}

	// FileSystemDataStore

	func testFileSystemDataStore100() async throws {
		let tempDir = FileManager.default.temporaryDirectory
		let dataStore = FileSystemDataStore(rootDir: tempDir)
		guard let outData = "This is some test data".data(using: .utf8) else {
			XCTFail("Unexpectedly unable to create test data.")
			return
		}
		let key = "test100"
		try await dataStore.write(key: key, item: outData)
		let inData = try await dataStore.read(key: key)
		XCTAssertEqual(outData, inData)
		try await dataStore.delete(key: key)
	}

	// SDODataManager

	func testSDODataManagerImageNameRegex100()  throws {
		guard let date = SDODataManager.fullDateFormatter.date(from: "20220909") else {
			XCTFail("Unexpectedly unable to create test date.")
			return
		}
		let nameRegex = SDODataManager.imageNameRegex(date: date, imageSet: .i0171, resolution: .x4096, pfss: true)
		let badMatches = ["", " ", "\t", "raspberries", "124_456_789_012pfss.jpg", "20210909_034658_4096_0171pfss.jpg", "20220909_034658_4096_0171.jpg", "20220909_034658_4096_0131pfss.jpg", "20220909_034658_4096_0171pfss.JPG"]
		for badMatch in badMatches {
			let match = try nameRegex.wholeMatch(in: badMatch)
			XCTAssertNil(match)
		}
		let goodMatches = [
			"20220909_034258_4096_0171pfss.jpg",
			"20220909_094634_4096_0171pfss.jpg",
			"20220909_214158_4096_0171pfss.jpg",
		]
		for goodMatch in goodMatches {
			let match = goodMatch.wholeMatch(of: nameRegex)
			XCTAssertNotNil(match)
			guard let output = match?.output else {
				XCTFail("Unexpectedly unable to get string from match output.")
				return
			}
			let matchOut = String(output)
			XCTAssertEqual(goodMatch, matchOut)
		}
	}

	func testSDODataManagerSDOImages100() async throws {
		guard let date = SDODataManager.fullDateFormatter.date(from: "20220909") else {
			XCTFail("Unexpectedly unable to create test date.")
			return
		}
		let manager = SDODataManager.shared
		let sdoImages = try await manager.sdoImages(date: date, imageSet: .i0094, resolution: .x512)
		XCTAssertEqual(sdoImages.count, 193)
	}

	func testSDODataManagerPrefetchImages100() async throws {
		guard let date = SDODataManager.fullDateFormatter.date(from: "20220909") else {
			XCTFail("Unexpectedly unable to create test date.")
			return
		}
		let manager = SDODataManager.shared
		try await manager.prefetchImages(date: date, imageSet: .i0094, resolution: .x512)
		let dataStore = await manager.dataStoreFor(date: date)
		let keys: [String] = try await dataStore.keys()
		let sdoImages = try await manager.sdoImages(date: date, imageSet: .i0094, resolution: .x512)
		for sdoImage in sdoImages {
			XCTAssertTrue(keys.contains(sdoImage.key), "Expected datastore to contain all sdo images after pre-fetch. Missing '\(sdoImage.key)'")
		}
	}

	// SWPCGeoAlert

	func testIssuedDateFormatter100() {
		guard let date = SWPCGeoAlert.issuedDateFormatter.date(from: "2022 Sep 18 1705 UTC") else {
			XCTFail("Unexpectedly unable to parse date from string.")
			return
		}
		guard let utcTZ = TimeZone(identifier: "UTC") else {
			XCTFail("Unexpectedly unable to make TimeZone from string.")
			return
		}
		let components = Calendar.current.dateComponents(in: utcTZ, from: date)
		let year = components.year
		XCTAssertEqual(year, 2022)
		let month = components.month
		XCTAssertEqual(month, 9)
		let day = components.day
		XCTAssertEqual(day, 18)
		let hour = components.hour
		XCTAssertEqual(hour, 17)
		let minute = components.minute
		XCTAssertEqual(minute, 5)
	}

	func testSWPCGeoAlertFromData100() async throws {
		guard let date = SWPCGeoAlert.issuedDateFormatter.date(from: "2022 Sep 18 1805 UTC") else {
			XCTFail("Unexpectedly unable to parse date from string.")
			return
		}
		let data = """
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
""".data(using: .utf8)
		guard let data else {
			XCTFail("Unexpectedly unable to create data from string.")
			return
		}
		let alert = try SWPCGeoAlert.from(data: data, etag: "foo")
		XCTAssertEqual(alert.issuedDate, date)
		XCTAssertEqual(alert.etag, "foo")
		XCTAssertEqual(alert.prepared, "Prepared by the US Dept. of Commerce, NOAA, Space Weather Prediction Center")
		let expectedBody = """
Solar-terrestrial indices for 17 September follow.
Solar flux 132 and estimated planetary A-index 5.
The estimated planetary K-index at 1800 UTC on 18 September was 2.

Space weather for the past 24 hours has been minor.
Radio blackouts reaching the R1 level occurred.

No space weather storms are predicted for the next 24 hours.
"""
		XCTAssertEqual(alert.body, expectedBody)
	}
}
