//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit
import Agrume

final class SingleImageViewController: UIViewController {
  
  var agrume: Agrume!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if #available(iOS 10.0, *) {
      agrume = Agrume(image: #imageLiteral(resourceName: "MapleBacon"), backgroundConfig: .blurred(.regular))
    }
  }

  @IBAction func openImage(_ sender: Any) {
    present(agrume, animated: true)
  }

}
