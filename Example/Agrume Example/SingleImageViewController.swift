//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit
import Agrume

final class SingleImageViewController: UIViewController {
  
  @available(iOS 10.0, *)
  private lazy var agrume: Agrume = {
    return Agrume(image: #imageLiteral(resourceName: "MapleBacon"), background: .blurred(.regular))
  }()

  @IBAction func openImage(_ sender: Any) {
    if #available(iOS 10.0, *) {
      present(agrume, animated: true)
    }
  }

}
