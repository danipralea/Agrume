//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit

/// The background type
public enum Background {
  /// Overlay with a color
  case colored(UIColor)
  /// Overlay with a UIBlurEffectStyle
  case blurred(UIBlurEffectStyle)
}

/// The Agrume configuration
public struct Configuration: OptionSet {
  public let rawValue: Int
  
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  /// Display an overlay on top of images
  public static let withOverlay = Configuration(rawValue: 1 << 0)
  /// Physics to drag and dismiss images
  public static let withPhysics = Configuration(rawValue: 1 << 1)
}

public protocol AgrumeDataSource: class {
	
  /// The number of images contained in the data source
	var numberOfImages: Int { get }
  
  /// Return the image for the passed in index
  ///
  /// - Parameter index: The index (collection view item) being displayed
  /// - Returns: The AgrumeImage at the passed in index
	func image(at index: Int) -> AgrumeImage?

  /// Return the index of the passed in image
  ///
  /// - Parameter image: The AgrumeImage whose index we're requesting
  /// - Returns: The index of the passed in image
  func index(of image: AgrumeImage) -> Int

}

public final class Agrume: UIViewController {

  public typealias DownloadCompletion = (_ image: UIImage?) -> Void

  private let transitionAnimator = TransitionAnimator()
  private let background: Background
  private let configuration: Configuration
  private let images: [AgrumeImage]
  private let startIndex: Int

  private weak var dataSource: AgrumeDataSource?

  /// Hide status bar when presenting. Defaults to `false`
  public var isStatusBarHidden = false

  /// Status bar style when presenting
  public var statusBarStyle: UIStatusBarStyle? {
    didSet {
      setNeedsStatusBarAppearanceUpdate()
    }
  }

  private lazy var pageViewController: UIPageViewController = {
    let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    controller.view.addGestureRecognizer(singleTapGesture)
    controller.view.backgroundColor = .clear
    controller.delegate = self
    controller.dataSource = self
    return controller
  }()

  private var _blurView: UIVisualEffectView?
  private var blurView: UIVisualEffectView {
    guard case .blurred(let style) = background, _blurView == nil else {
      return _blurView!
    }

    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: style))
    blurView.frame = view.frame
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _blurView = blurView

    return blurView
  }
  
  private lazy var overlayView: OverlayView = {
    let overlay = OverlayView(frame: .zero)
    overlay.frame = view.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.delegate = self
    return overlay
  }()

  private lazy var singleTapGesture: UITapGestureRecognizer = {
    return UITapGestureRecognizer(target: self, action: #selector(singleTap))
  }()

  /// An optional download handler. Passed the URL that is supposed to be loaded. Call the completion with the image
  /// when the download is done.
  public var downloadHandler: ((_ url: URL, _ completion: @escaping DownloadCompletion) -> Void)?

  public override var prefersStatusBarHidden: Bool {
    return presentingViewController?.prefersStatusBarHidden ?? isStatusBarHidden
  }

  public convenience init(image: AgrumeImage, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(agrumeImages: [image], background: background, configuration: configuration)
  }

  public convenience init(image: UIImage, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(images: [image], urls: nil, background: background, configuration: configuration)
  }

  public convenience init(url: URL, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(urls: [url], background: background, configuration: configuration)
  }

  public convenience init(images: [UIImage], startIndex: Int = 0, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(images: images, urls: nil, startIndex: startIndex, background: background, configuration: configuration)
  }
  
  public convenience init(images: [AgrumeImage], startIndex: Int = 0, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(agrumeImages: images, startIndex: startIndex, background: background, configuration: configuration)
  }

  public convenience init(urls: [URL], startIndex: Int = 0, background: Background = .colored(.black),
                          configuration: Configuration = [.withPhysics]) {
    self.init(images: nil, urls: urls, startIndex: startIndex, background: background, configuration: configuration)
  }

  private init(images: [UIImage]? = nil, urls: [URL]? = nil, agrumeImages: [AgrumeImage]? = nil,
               startIndex: Int = 0, background: Background, configuration: Configuration,
               dataSource: AgrumeDataSource? = nil) {
    switch (images, urls, agrumeImages) {
    case (let images?, nil, nil):
      self.images = images.map { AgrumeImage(image: $0) }
    case (_, let urls?, nil):
      self.images = urls.map { AgrumeImage(url: $0) }
    case (_, _, let images?):
      self.images = images
    default:
      fatalError("Impossible initialiser call")
    }

    self.background = background
    self.configuration = configuration
    self.startIndex = startIndex

    super.init(nibName: nil, bundle: nil)

    self.dataSource = dataSource ?? self

    modalPresentationStyle = .custom
    transitioningDelegate = self
    modalPresentationCapturesStatusBarAppearance = true
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    switch background {
    case .colored(let color):
      view.backgroundColor = color
    case .blurred:
      view.addSubview(blurView)
    }

    addChildViewController(pageViewController)
    view.addSubview(pageViewController.view)
    pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    pageViewController.didMove(toParentViewController: self)

    guard let image = dataSource?.image(at: startIndex) else { return }
    let controller = newImageViewController(for: image)
    pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)

    if configuration.contains(.withOverlay) {
      view.addSubview(overlayView)
      delay(.seconds(2)) { [weak self] in
        self?.overlayView.setHidden(true)
      }
    }
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    updateOverlay(for: image(at: startIndex))
  }
  
  private func updateOverlay(for image: AgrumeImage?) {
    guard configuration.contains(.withOverlay), let image = image, let total = dataSource?.numberOfImages else { return }
    overlayView.updateOverlay(title: image.title, current: index(of: image) + 1, total: total)
  }

  @objc
  private func singleTap() {
    guard configuration.contains(.withOverlay) else { return }
    overlayView.setHidden(!overlayView.isHidden)
  }

}

extension Agrume: AgrumeDataSource {

  public var numberOfImages: Int {
    return images.count
  }

  public func image(at index: Int) -> AgrumeImage? {
    guard index >= 0 && index < images.count else { return nil }
    return images[index]
  }

  public func index(of image: AgrumeImage) -> Int {
    guard let idx = images.index(where: { $0 == image }) else { fatalError("Unknown image") }
    return idx
  }

}

extension Agrume: UIPageViewControllerDataSource {

  public func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerBefore viewController: UIViewController) -> UIViewController? {
    guard let controller = viewController as? ImageViewController,
          let idx = dataSource?.index(of: controller.agrumeImage),
          let previous = dataSource?.image(at: idx - 1) else { return nil }
    return newImageViewController(for: previous)
  }

  private func newImageViewController(for image: AgrumeImage) -> ImageViewController {
    let controller = ImageViewController(image: image, withPhysics: configuration.contains(.withPhysics))
    controller.delegate = self
    singleTapGesture.require(toFail: controller.doubleTapGesture)
    return controller
  }

  public func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerAfter viewController: UIViewController) -> UIViewController? {
    guard let controller = viewController as? ImageViewController,
          let idx = dataSource?.index(of: controller.agrumeImage),
          let next = dataSource?.image(at: idx + 1) else { return nil }
    return newImageViewController(for: next)
  }

}

extension Agrume: UIPageViewControllerDelegate {

  public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                 previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    guard completed, let currentImageViewController = currentImageViewController else { return }
    updateOverlay(for: currentImageViewController.agrumeImage)
  }

  private var currentImageViewController: ImageViewController? {
    return pageViewController.viewControllers?.first as? ImageViewController
  }

  private var currentImage: AgrumeImage? {
    return currentImageViewController?.agrumeImage
  }

}

extension Agrume: UIViewControllerTransitioningDelegate {

  public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                  source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    transitionAnimator.isDismissing = false
    return transitionAnimator
  }

  public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    transitionAnimator.isDismissing = true
    return transitionAnimator
  }

}

extension Agrume: ImageViewControllerDelegate {

  func dismiss() {
    guard presentedViewController == nil else {
      super.dismiss(animated: true, completion: nil)
      return
    }
    var startView: UIView?
    if let _ = currentImageViewController?.scrollView.imageView.image {
      startView = currentImageViewController?.scrollView.imageView
    }
    transitionAnimator.startView = startView
//    transitionAnimator.finalView = nil

    super.dismiss(animated: true, completion: nil)
  }
  
  func download(url: URL, completion: @escaping (_ image: UIImage?) -> Void) -> URLSessionDataTask? {
    if let downloadHandler = downloadHandler {
      downloadHandler(url, completion)
      return nil
    } else if let downloadHandler = AgrumeServiceLocator.shared.downloadHandler {
      downloadHandler(url, completion)
      return nil
    }
    return ImageDownloader.downloadImage(url, completion: completion)
  }

}

extension Agrume: OverlayViewDelegate {

  func didClose(overlayView view: OverlayView) {
    dismiss()
  }
  
}
