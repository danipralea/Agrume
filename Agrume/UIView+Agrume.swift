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
  
  var portableBottomAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {
    if #available(iOS 11.0, *) {
      return safeAreaLayoutGuide.bottomAnchor
    } else {
      return bottomAnchor
    }
  }

  func snapshotView() -> UIView? {
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, 0)
    defer {
      UIGraphicsEndImageContext()
    }
    guard let context = UIGraphicsGetCurrentContext() else {
      return nil
    }
    layer.render(in: context)
    return UIImageView(image: UIGraphicsGetImageFromCurrentImageContext())
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
  
  func usesAutolayout(_ toggle: Bool) {
    translatesAutoresizingMaskIntoConstraints = !toggle
  }

}
