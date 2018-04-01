//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit
import Agrume

final class SingleImageBackgroundColorViewController: UIViewController {

  private lazy var complicatedTitle: NSAttributedString = {
    let title = "Agrume"
    let subtitle = "A lemony fresh image viewer written in Swift"
    let fullTitle = "\(title)\n\(subtitle)"
    let attributedTitle = NSMutableAttributedString(string: fullTitle, attributes: [.foregroundColor: UIColor.white,
                                                                                    .font: UIFont.systemFont(ofSize: 12)])
    let range = NSRange(fullTitle.range(of: title)!, in: fullTitle)
    attributedTitle.addAttributes([.font: UIFont.boldSystemFont(ofSize: 12)], range: range)
    return attributedTitle
  }()

  private lazy var agrume: Agrume = {
    let image = AgrumeImage(image: #imageLiteral(resourceName: "MapleBacon"), title: complicatedTitle)
    let agrume = Agrume(image: image, background: .colored(.black))
    agrume.isStatusBarHidden = true
    return agrume
  }()

  @IBAction private func openImage(_ sender: Any) {
    present(agrume, animated: true)
  }
  
}
