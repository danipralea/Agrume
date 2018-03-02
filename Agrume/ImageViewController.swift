//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

final class ImageViewController: UIViewController {

  let agrumeImage: AgrumeImage

  private lazy var scrollView: ScrollView = {
    let scrollView = ScrollView()
    scrollView.delegate = self
    scrollView.frame = view.bounds
    scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return scrollView
  }()

  private lazy var activityIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    indicator.startAnimating()
    indicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    indicator.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
    indicator.sizeToFit()
    return indicator
  }()

  private(set) lazy var doubleTapGesture: UITapGestureRecognizer = {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(self.doubleTap))
    gesture.numberOfTapsRequired = 2
    return gesture
  }()

  init(image: AgrumeImage) {
    self.agrumeImage = image
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(scrollView)
    view.addSubview(activityIndicator)
    view.addGestureRecognizer(doubleTapGesture)

    if let image = agrumeImage.image {
      scrollView.image = image
      activityIndicator.stopAnimating()
    } else if let url = agrumeImage.url {
      // Tell delegate to load the image
    }
  }

  @objc
  private func doubleTap(_ gesture: UITapGestureRecognizer) {
    let zoomScale: CGFloat
    if scrollView.zoomScale >= scrollView.maximumZoomScale || abs(scrollView.zoomScale - scrollView.maximumZoomScale) <= 0.01 {
      zoomScale = scrollView.minimumZoomScale
    } else {
      zoomScale = scrollView.maximumZoomScale
    }

    let size = scrollView.bounds.size
    let width = size.width / zoomScale
    let height = size.height / zoomScale
    let point = gesture.location(in: scrollView.imageView)
    let x = point.x - (width / 2)
    let y = point.y - (height / 2)

    let zoomRect = CGRect(x: x, y: y, width: width, height: height)
    scrollView.zoom(to: zoomRect, animated: true)
  }

}

extension ImageViewController: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return self.scrollView.imageView
  }

}
