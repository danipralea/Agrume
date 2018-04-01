//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit

extension UIView {

  var portableTopAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {
    if #available(iOS 11.0, *) {
      return safeAreaLayoutGuide.topAnchor
    } else {
      return topAnchor
    }
  }

  func snapshotView() -> UIView? {
    guard let contents = layer.contents else { return snapshotView(afterScreenUpdates: true) }

    let snapshot: UIView
    if let view = self as? UIImageView {
      snapshot = UIImageView(image: view.image)
      snapshot.bounds = view.bounds
    } else {
      snapshot = UIView(frame: frame)
      snapshot.layer.contents = contents
      snapshot.layer.bounds = layer.bounds
    }

    snapshot.layer.masksToBounds = layer.masksToBounds
    snapshot.contentMode = contentMode
    snapshot.transform = transform

    return snapshot
  }

  func translatedCenter(toContainerView containerView: UIView) -> CGPoint {
    guard let superView = superview else { return .zero }

    var centerPoint = center
    if let scrollView = superView as? UIScrollView, scrollView.zoomScale != 1 {
      centerPoint.x += (scrollView.bounds.width - scrollView.contentSize.width) / 2 + scrollView.contentOffset.x
      centerPoint.y += (scrollView.bounds.height - scrollView.contentSize.height) / 2 + scrollView.contentOffset.y
    }
    return superView.convert(centerPoint, to: containerView)
  }

}
