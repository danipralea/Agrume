//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit
import Agrume

/// Sample class showing how to handle image downloads by yourself
final class CustomDownloadHandlerViewController: UIViewController {
  
  private lazy var agrume: Agrume = {
    let url = URL(string: "https://www.dropbox.com/s/mlquw9k6ogvspox/MapleBacon.png?raw=1")!
    let agrume = Agrume(url: url, background: .colored(.white))
    // Set the downloadHandler property on Agrume and it will call this function with a URL
    agrume.downloadHandler = { [weak self] url, completion in
      self?.downloadImage(url: url) { image in
        completion(image)
      }
    }
    agrume.isStatusBarHidden = true
    return agrume
  }()
  
  @IBAction private func openImage(_ sender: Any) {
    present(agrume, animated: true)
  }
  
  private func downloadImage(url: URL, completion: @escaping (UIImage?) -> Void) {
    var configuration = URLSessionConfiguration.default
    if #available(iOS 11.0, *) {
      configuration.waitsForConnectivity = true
    }
    let session = URLSession(configuration: configuration)
    let task = session.dataTask(with: url) { data, _, error in
      var image: UIImage?
      defer {
        DispatchQueue.main.async {
          completion(image)
        }
      }
      guard let data = data, error == nil else { return }
      image = UIImage(data: data)
    }
    task.resume()
  }
  
}
