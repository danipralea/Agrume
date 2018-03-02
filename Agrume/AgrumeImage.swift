//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

public struct AgrumeImage: Equatable {

  public let image: UIImage?
  public let url: URL?

  private init(image: UIImage?, url: URL?) {
    self.image = image
    self.url = url
  }

  public init(image: UIImage) {
    self.init(image: image, url: nil)
  }

  public init(url: URL) {
    self.init(image: nil, url: url)
  }

  public static func == (lhs: AgrumeImage, rhs: AgrumeImage) -> Bool {
    return lhs.image == rhs.image && lhs.url == rhs.url
  }

}
