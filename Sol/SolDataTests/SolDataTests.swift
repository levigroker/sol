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
    }

	// LinkFetcher

	func testLinkFetcherFetchLinks100() async throws {
		guard let url = URL(string: "https://sdo.gsfc.nasa.gov/assets/img/browse/2022/09/09/") else {
			XCTFail("Unexpectedly unable to create URL from string.")
			return
		}
		let linkFetcher = LinkFetcher()
		let links = try await linkFetcher.parseLinks(dir: url)
		XCTAssertGreaterThan(links.count, 0, "Expected at least one link.")
		XCTAssertEqual(links.count, 11701)
	}

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
