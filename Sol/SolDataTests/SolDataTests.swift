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
		let data = try await dataFetch.fetch()
		XCTAssertGreaterThan(data.count, 0, "Expected some data.")
    }

	// LinkFetcher

	func testLinkFetcherFetchLinks100() async throws {
		guard let url = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse/2022/09/09/") else {
			XCTFail("Unexpectedly unable to create URL from string.")
			return
		}
		let links = try await LinkFetcher.parseLinks(dir: url)
		XCTAssertGreaterThan(links.count, 0, "Expected at least one link.")
		XCTAssertEqual(links.count, 11701)
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
}
