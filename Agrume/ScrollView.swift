//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

final class ScrollView: UIScrollView {

  lazy var imageView: UIImageView = {
    let view = UIImageView(frame: self.bounds)
    self.addSubview(view)
    return view
  }()

  var image: UIImage? {
    didSet {
      updateImage()
    }
  }

  private func updateImage() {
    imageView.transform = .identity
    imageView.image = image

    let size = image?.size ?? .zero
    imageView.frame = CGRect(origin: .zero, size: size)
    contentSize = size

    updateZoom()
    centerContents()
  }

  override var frame: CGRect {
    didSet {
      updateZoom()
      centerContents()
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }

  private func setup() {
    setupScrollView()
    updateZoom()
  }

  private func updateZoom() {
    guard let image = imageView.image else { return }

    let scaleWidth = bounds.width / image.size.width
    let scaleHeight = bounds.height / image.size.height
    let minScale = min(scaleWidth, scaleHeight)

    minimumZoomScale = minScale
    maximumZoomScale = max(minScale, maximumZoomScale)

    zoomScale = minScale

    panGestureRecognizer.isEnabled = false
  }

  private func setupScrollView() {
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    bouncesZoom = true
    decelerationRate = UIScrollViewDecelerationRateFast
  }

  private func centerContents() {
    var horizontalInset: CGFloat = 0
    var verticalInset: CGFloat = 0

    if contentSize.width < bounds.width {
      horizontalInset = (bounds.width - contentSize.width) * 0.5
    }
    if self.contentSize.height < bounds.height {
      verticalInset = (bounds.height - contentSize.height) * 0.5
    }
    if let scale = window?.screen.scale, scale < 2 {
      horizontalInset = floor(horizontalInset)
      verticalInset = floor(verticalInset)
    }

    contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
  }

  override func didAddSubview(_ subview: UIView) {
    super.didAddSubview(subview)
    centerContents()
  }

}
