//
//  AboutViewController.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-12.
//

import UIKit

class AboutViewController: UIViewController {

	@IBOutlet private var copyrightLabel: UILabel!

	override func viewDidLoad() {
		super.viewDidLoad()

		// Dynamically update the copyright year
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy"
		let year = dateFormatter.string(from: Date())
		copyrightLabel.text = "© \(year) @levigroker"
	}
}
