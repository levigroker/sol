//
//  AboutViewController.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-12.
//

import UIKit

class AboutViewController: UIViewController {

	@IBOutlet weak var copyrightLabel: UILabel!

	override func viewDidLoad() {
		super.viewDidLoad()

		// Dynamically update the copyright year
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .none
		let year = dateFormatter.string(from: Date())
		copyrightLabel.text = "© \(year) @levigroker"
	}
}
