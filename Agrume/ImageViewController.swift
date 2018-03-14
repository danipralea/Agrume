//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

protocol ImageViewControllerDelegate: class {

  func dismiss()

}

final class ImageViewController: UIViewController {

  private static let minFlickDismissVelocity: CGFloat = 800

  let agrumeImage: AgrumeImage

  weak var delegate: ImageViewControllerDelegate?

  private var isDraggingImage = false
  private var imageDragStartLocation: CGPoint!
  private var imageDragOffsetFromActualTranslation: UIOffset!
  private var imageDragOffsetFromImageCenter: UIOffset!
  private var attachmentBehavior: UIAttachmentBehavior?
  private var downloadTask: URLSessionDataTask?

  lazy var scrollView: ScrollView = {
    let scrollView = ScrollView()
    scrollView.delegate = self
    scrollView.frame = view.bounds
    scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return scrollView
  }()

  private lazy var animator: UIDynamicAnimator = {
    let animator = UIDynamicAnimator(referenceView: self.scrollView)
    return animator
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

  private lazy var panGesture: UIPanGestureRecognizer = {
    let gesture = UIPanGestureRecognizer(target: self, action: #selector(self.pan))
    gesture.maximumNumberOfTouches = 1
    gesture.delegate = self
    return gesture
  }()

  deinit {
    downloadTask?.cancel()
  }

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
    scrollView.addGestureRecognizer(panGesture)

    if let image = agrumeImage.image {
      scrollView.image = image
      activityIndicator.stopAnimating()
    } else if let url = agrumeImage.url {
      downloadTask = ImageDownloader.downloadImage(url) { [weak self] image in
        self?.scrollView.image = image
        self?.activityIndicator.stopAnimating()
      }
    }
  }

  @objc
  private func doubleTap(_ gesture: UITapGestureRecognizer) {
    let zoomScale = scale()
    let size = scrollView.bounds.size
    let width = size.width / zoomScale
    let height = size.height / zoomScale
    let point = gesture.location(in: scrollView.imageView)
    let x = point.x - (width / 2)
    let y = point.y - (height / 2)

    let zoomRect = CGRect(x: x, y: y, width: width, height: height)
    scrollView.zoom(to: zoomRect, animated: true)
  }

  private func scale() -> CGFloat {
    if scrollView.zoomScale >= scrollView.maximumZoomScale || abs(scrollView.zoomScale - scrollView.maximumZoomScale) <= 0.01 {
      return scrollView.minimumZoomScale
    } else {
      return scrollView.maximumZoomScale
    }
  }

  @objc
  private func pan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: scrollView.imageView)
    let location = gesture.location(in: scrollView.imageView)
    let velocity = gesture.velocity(in: scrollView.imageView)
    let vectorDistance = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))

    switch gesture.state {
    case .began:
      isDraggingImage = scrollView.imageView.frame.contains(location)
      if isDraggingImage {
        startImageDragging(locationInView: location, translationOffset: .zero)
      }
    case .changed:
      if isDraggingImage {
        guard var newAnchor = imageDragStartLocation else { return }
        newAnchor.x = translation.x + imageDragOffsetFromActualTranslation.horizontal
        newAnchor.y = translation.y + imageDragOffsetFromActualTranslation.vertical
        attachmentBehavior?.anchorPoint = newAnchor
      } else {
        isDraggingImage = scrollView.imageView.frame.contains(location)
        if isDraggingImage {
          let translationOffset = UIOffset(horizontal: -(translation.x), vertical: -(translation.y))
          startImageDragging(locationInView: location, translationOffset: translationOffset)
        }
      }
    default:
      if vectorDistance > ImageViewController.minFlickDismissVelocity {
        if isDraggingImage {
          dismissWithFlick(velocity: velocity)
        } else {
          dismiss()
        }
      } else {
        snapBack()
      }
    }
  }

  private func startImageDragging(locationInView: CGPoint, translationOffset: UIOffset) {
    imageDragStartLocation = locationInView
    imageDragOffsetFromActualTranslation = translationOffset

    let anchor = imageDragStartLocation
    let imageCenter = scrollView.imageView.center
    let offset = UIOffset(horizontal: locationInView.x - imageCenter.x, vertical: locationInView.y - imageCenter.y)
    imageDragOffsetFromImageCenter = offset
    attachmentBehavior = UIAttachmentBehavior(item: scrollView.imageView, offsetFromCenter: offset,
                                              attachedToAnchor: anchor!)
    animator.addBehavior(attachmentBehavior!)

    let modifier = UIDynamicItemBehavior(items: [scrollView.imageView])
    modifier.angularResistance = angularResistance(in: scrollView.imageView)
    modifier.density = density(in: scrollView.imageView)
    animator.addBehavior(modifier)
  }

  private func dismissWithFlick(velocity: CGPoint) {
    let push = UIPushBehavior(items: [scrollView.imageView], mode: .instantaneous)
    push.pushDirection = CGVector(dx: velocity.x * 0.1, dy: velocity.y * 0.1)
    push.setTargetOffsetFromCenter(imageDragOffsetFromImageCenter, for: scrollView.imageView)
    push.action = pushAction
    animator.removeBehavior(attachmentBehavior!)
    animator.addBehavior(push)
  }

  private func pushAction() {
    if isImageViewOffscreen() {
      animator.removeAllBehaviors()
      attachmentBehavior = nil
//      scrollView.imageView.removeFromSuperview()
      dismiss()
    }
  }

  private func isImageViewOffscreen() -> Bool {
    let visibleRect = scrollView.convert(view.bounds, from: view)
    return animator.items(in: visibleRect).isEmpty
  }

  private func dismiss() {
    delegate?.dismiss()
  }

  private func snapBack() {
    animator.removeAllBehaviors()
    attachmentBehavior = nil
    isDraggingImage = false

    UIView.animate(withDuration: 0.7,
                   delay: 0,
                   usingSpringWithDamping: 0.7,
                   initialSpringVelocity: 0,
                   options: [.allowUserInteraction, .beginFromCurrentState],
                   animations: {
                    guard !self.isDraggingImage else { return }

                    self.scrollView.imageView.transform = .identity

                    guard !self.scrollView.isDragging && !self.scrollView.isDecelerating else { return }

                    let zoomScale = self.scale()
                    let size = self.scrollView.bounds.size
                    let width = size.width / zoomScale
                    let height = size.height / zoomScale
                    let zoomRect = CGRect(x: 0, y: 0, width: width, height: height)
                    self.scrollView.zoom(to: zoomRect, animated: false)

                    self.scrollView.imageView.center = CGPoint(x: self.scrollView.contentSize.width / 2,
                                                               y: self.scrollView.contentSize.height / 2)
    })
  }

  private func angularResistance(in view: UIView) -> CGFloat {
    let defaultResistance: CGFloat = 4
    return appropriateValue(defaultValue: defaultResistance) * factor(forView: view)
  }

  private func appropriateValue(defaultValue: CGFloat) -> CGFloat {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    // Default value that works well for the screenSize adjusted for the actual size of the device
    return defaultValue * ((320 * 480) / (screenWidth * screenHeight))
  }

  private func factor(forView view: UIView) -> CGFloat {
    let actualArea = self.view.bounds.height * view.bounds.height
    let referenceArea = self.view.bounds.height * self.view.bounds.width
    return referenceArea / actualArea
  }

  private func density(in view: UIView) -> CGFloat {
    let defaultDensity: CGFloat = 0.5
    return appropriateValue(defaultValue: defaultDensity) * factor(forView: view)
  }

}

extension ImageViewController: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return self.scrollView.imageView
  }

}

extension ImageViewController: UIGestureRecognizerDelegate {

  private var isZoomed: Bool {
    return scrollView.zoomScale > 1
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if let pan = gestureRecognizer as? UIPanGestureRecognizer, !isZoomed {
      let velocity = pan.velocity(in: scrollView)
      return abs(velocity.y) > abs(velocity.x)
    }
    return true
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    if let _ = gestureRecognizer as? UIPanGestureRecognizer {
      return !isZoomed
    }
    return true
  }

}
