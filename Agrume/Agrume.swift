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
  public var download: ((_ url: URL, _ completion: @escaping DownloadCompletion) -> Void)?

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

}

extension Agrume: OverlayViewDelegate {

  func didClose(overlayView view: OverlayView) {
    dismiss()
  }
  
}

//  private static let transitionAnimationDuration: TimeInterval = 0.3
//  private static let initialScalingToExpandFrom: CGFloat = 0.6
//  private static let maxScalingForExpandingOffscreen: CGFloat = 1.25
//  private static let reuseIdentifier = "reuseIdentifier"
//
//  private var images: [AgrumeImage]!
//  private var startIndex: Int?
//  private let backgroundBlurStyle: UIBlurEffectStyle?
//  private let backgroundColor: UIColor?
//  private let dataSource: AgrumeDataSource?
//

//
//  /// Optional closure to call whenever Agrume is dismissed.
//  public var didDismiss: (() -> Void)?
//  /// Optional closure to call whenever Agrume scrolls to the next image in a collection. Passes the "page" index
//  public var didScroll: ((_ index: Int) -> Void)?
//  /// An optional download handler. Passed the URL that is supposed to be loaded. Call the completion with the image
//  /// when the download is done.
//  public var download: ((_ url: URL, _ completion: @escaping DownloadCompletion) -> Void)?
//  /// Status bar style when presenting
//  public var statusBarStyle: UIStatusBarStyle? {
//    didSet {
//      setNeedsStatusBarAppearanceUpdate()
//    }
//  }
//  /// Hide status bar when presenting. Defaults to `false`
//  public var hideStatusBar = false
//
//  /// Initialize with a single image
//  ///
//  /// - Parameter image: The image to present
//  /// - Parameter backgroundBlurStyle: The UIBlurEffectStyle to apply to the background when presenting
//  /// - Parameter backgroundColor: The background color when presenting
//  public convenience init(image: UIImage, backgroundBlurStyle: UIBlurEffectStyle? = nil, backgroundColor: UIColor? = nil) {
//    self.init(image: image, imageUrl: nil, backgroundBlurStyle: backgroundBlurStyle, backgroundColor: backgroundColor)
//  }
//
//  /// Initialize with a single image url
//  ///
//  /// - Parameter imageUrl: The image url to present
//  /// - Parameter backgroundBlurStyle: The UIBlurEffectStyle to apply to the background when presenting
//  /// - Parameter backgroundColor: The background color when presenting
//  public convenience init(imageUrl: URL, backgroundBlurStyle: UIBlurEffectStyle? = .dark, backgroundColor: UIColor? = nil) {
//    self.init(image: nil, imageUrl: imageUrl, backgroundBlurStyle: backgroundBlurStyle, backgroundColor: backgroundColor)
//  }
//
//  /// Initialize with a data source
//  ///
//  /// - Parameter dataSource: The `AgrumeDataSource` to use
//  /// - Parameter startIndex: The optional start index when showing multiple images
//  /// - Parameter backgroundBlurStyle: The UIBlurEffectStyle to apply to the background when presenting
//  /// - Parameter backgroundColor: The background color when presenting
//  public convenience init(dataSource: AgrumeDataSource, startIndex: Int? = nil,
//                          backgroundBlurStyle: UIBlurEffectStyle? = .dark, backgroundColor: UIColor? = nil) {
//    self.init(image: nil, images: nil, dataSource: dataSource, startIndex: startIndex,
//              backgroundBlurStyle: backgroundBlurStyle, backgroundColor: backgroundColor)
//  }
//
//  /// Initialize with an array of images
//  ///
//  /// - Parameter images: The images to present
//  /// - Parameter startIndex: The optional start index when showing multiple images
//  /// - Parameter backgroundBlurStyle: The UIBlurEffectStyle to apply to the background when presenting
//  /// - Parameter backgroundColor: The background color when presenting
//  public convenience init(images: [UIImage], startIndex: Int? = nil, backgroundBlurStyle: UIBlurEffectStyle? = .dark,
//                          backgroundColor: UIColor? = nil) {
//    self.init(image: nil, images: images, startIndex: startIndex, backgroundBlurStyle: backgroundBlurStyle,
//              backgroundColor: backgroundColor)
//  }
//
//  /// Initialize with an array of image urls
//  ///
//  /// - Parameter imageUrls: The image urls to present
//  /// - Parameter startIndex: The optional start index when showing multiple images
//  /// - Parameter backgroundBlurStyle: The UIBlurEffectStyle to apply to the background when presenting
//  /// - Parameter backgroundColor: The background color when presenting
//  public convenience init(imageUrls: [URL], startIndex: Int? = nil, backgroundBlurStyle: UIBlurEffectStyle? = .dark,
//                          backgroundColor: UIColor? = nil) {
//    self.init(image: nil, imageUrls: imageUrls, startIndex: startIndex, backgroundBlurStyle: backgroundBlurStyle,
//              backgroundColor: backgroundColor)
//  }
//
//  private init(image: UIImage? = nil, imageUrl: URL? = nil, images: [UIImage]? = nil,
//               dataSource: AgrumeDataSource? = nil, imageUrls: [URL]? = nil, startIndex: Int? = nil,
//               backgroundBlurStyle: UIBlurEffectStyle? = nil, backgroundColor: UIColor? = nil) {
//    switch (backgroundBlurStyle, backgroundColor) {
//    case (let blur, .none):
//      self.backgroundBlurStyle = blur
//      self.backgroundColor = nil
//    case (.none, let color):
//      self.backgroundColor = color
//      self.backgroundBlurStyle = nil
//    default:
//      self.backgroundBlurStyle = .dark
//      self.backgroundColor = nil
//    }
//
//    if let image = image {
//      self.images = [AgrumeImage(image: image)]
//    } else if let imageURL = imageUrl {
//      self.images = [AgrumeImage(url: imageURL)]
//    } else if let images = images {
//      self.images = images.map { AgrumeImage(image: $0) }
//    } else if let imageUrls = imageUrls {
//      self.images = imageUrls.map { AgrumeImage(url: $0) }
//    }
//
//    self.dataSource = dataSource
//    self.startIndex = startIndex
//    super.init(nibName: nil, bundle: nil)
//
//    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
//    NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange),
//                                           name: .UIDeviceOrientationDidChange, object: nil)
//  }
//
//  deinit {
//    downloadTask?.cancel()
//    UIDevice.current.endGeneratingDeviceOrientationNotifications()
//    NotificationCenter.default.removeObserver(self)
//  }
//
//  required public init?(coder aDecoder: NSCoder) {
//    fatalError("Not implemented")
//  }
//
//  private func frameForCurrentDeviceOrientation() -> CGRect {
//    let bounds = view.bounds
//    if UIDeviceOrientationIsLandscape(currentDeviceOrientation()) {
//      if bounds.width / bounds.height > bounds.height / bounds.width {
//        return bounds
//      } else {
//        return CGRect(origin: bounds.origin, size: CGSize(width: bounds.height, height: bounds.width))
//      }
//    }
//    return bounds
//  }
//
//  private func currentDeviceOrientation() -> UIDeviceOrientation {
//    return UIDevice.current.orientation
//  }
//
//  private var backgroundSnapshot: UIImage!
//  private var backgroundImageView: UIImageView!
//  private var _blurContainerView: UIView?
//  private var blurContainerView: UIView {
//    if _blurContainerView == nil {
//      let view = UIView(frame: self.view.frame)
//      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//      view.backgroundColor = backgroundColor ?? .clear
//      _blurContainerView = view
//    }
//    return _blurContainerView!
//  }
//  private var _blurView: UIVisualEffectView?
//  private var blurView: UIVisualEffectView {
//    if _blurView == nil {
//      let blurView = UIVisualEffectView(effect: UIBlurEffect(style: self.backgroundBlurStyle!))
//      blurView.frame = self.view.frame
//      blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//      _blurView = blurView
//    }
//    return _blurView!
//  }
//  private var _collectionView: UICollectionView?
//  private var collectionView: UICollectionView {
//    if _collectionView == nil {
//      let layout = UICollectionViewFlowLayout()
//      layout.minimumInteritemSpacing = 0
//      layout.minimumLineSpacing = 0
//      layout.scrollDirection = .horizontal
//      layout.itemSize = self.view.frame.size
//
//      let collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: layout)
//      collectionView.register(AgrumeCell.self, forCellWithReuseIdentifier: Agrume.reuseIdentifier)
//      collectionView.dataSource = self
//      collectionView.delegate = self
//      collectionView.isPagingEnabled = true
//      collectionView.backgroundColor = .clear
//      collectionView.delaysContentTouches = false
//      collectionView.showsHorizontalScrollIndicator = false
//      _collectionView = collectionView
//    }
//    return _collectionView!
//  }
//  private var _spinner: UIActivityIndicatorView?
//  private var spinner: UIActivityIndicatorView {
//    if _spinner == nil {
//      let activityIndicatorStyle: UIActivityIndicatorViewStyle = self.backgroundBlurStyle == .dark ? .whiteLarge : .gray
//      let spinner = UIActivityIndicatorView(activityIndicatorStyle: activityIndicatorStyle)
//      spinner.center = self.view.center
//      spinner.startAnimating()
//      spinner.alpha = 0
//      _spinner = spinner
//    }
//    return _spinner!
//  }
//  private var downloadTask: URLSessionDataTask?
//
//  override public func viewDidLoad() {
//    super.viewDidLoad()
//    view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//    backgroundImageView = UIImageView(frame: view.frame)
//    backgroundImageView.image = backgroundSnapshot
//    view.addSubview(backgroundImageView)
//  }
//
//  private var lastUsedOrientation: UIDeviceOrientation?
//
//  public override func viewWillAppear(_ animated: Bool) {
//    super.viewWillAppear(animated)
//    lastUsedOrientation = currentDeviceOrientation()
//  }
//
//  private func deviceOrientationFromStatusBarOrientation() -> UIDeviceOrientation {
//    return UIDeviceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
//  }
//
//  private var initialOrientation: UIDeviceOrientation!
//
//  public func showFrom(_ viewController: UIViewController, backgroundSnapshotVC: UIViewController? = nil) {
//    backgroundSnapshot = (backgroundSnapshotVC ?? viewControllerForSnapshot(fromViewController: viewController))?.view.snapshot()
//    view.frame = frameForCurrentDeviceOrientation()
//    view.isUserInteractionEnabled = false
//    addSubviews()
//    initialOrientation = deviceOrientationFromStatusBarOrientation()
//    updateLayoutsForCurrentOrientation()
//    showFrom(viewController)
//  }
//
//  private func addSubviews() {
//    if backgroundBlurStyle != nil {
//      blurContainerView.addSubview(blurView)
//    }
//    view.addSubview(blurContainerView)
//    view.addSubview(collectionView)
//    if let index = startIndex {
//      collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: [], animated: false)
//    }
//    view.addSubview(spinner)
//  }
//
//  private func showFrom(_ viewController: UIViewController) {
//    DispatchQueue.main.async {
//      self.blurContainerView.alpha = 1
//      self.collectionView.alpha = 0
//      self.collectionView.frame = self.view.frame
//      let scaling = Agrume.initialScalingToExpandFrom
//      self.collectionView.transform = CGAffineTransform(scaleX: scaling, y: scaling)
//
//      viewController.present(self, animated: false) {
//        UIView.animate(withDuration: Agrume.transitionAnimationDuration,
//                       delay: 0,
//                       options: .beginFromCurrentState,
//                       animations: { [weak self] in
//                        self?.collectionView.alpha = 1
//                        self?.collectionView.transform = .identity
//          }, completion: { [weak self] _ in
//            self?.view.isUserInteractionEnabled = true
//          })
//      }
//    }
//  }
//
//  private func viewControllerForSnapshot(fromViewController viewController: UIViewController) -> UIViewController? {
//    var presentingVC = viewController.view.window?.rootViewController
//    while presentingVC?.presentedViewController != nil {
//      presentingVC = presentingVC?.presentedViewController
//    }
//    return presentingVC
//  }
//
//  public func dismiss() {
//    self.dismissAfterFlick()
//  }
//
//  public func showImage(atIndex index : Int) {
//    collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: [], animated: true)
//  }
//
//  public func reload() {
//    DispatchQueue.main.async {
//      self.collectionView.reloadData()
//    }
//  }
//
//  public override var prefersStatusBarHidden: Bool {
//    return hideStatusBar
//  }
//
//  // MARK: Rotation
//
//  @objc
//  private func orientationDidChange() {
//    let orientation = currentDeviceOrientation()
//    guard let lastOrientation = lastUsedOrientation else { return }
//    let landscapeToLandscape = UIDeviceOrientationIsLandscape(orientation) && UIDeviceOrientationIsLandscape(lastOrientation)
//    let portraitToPortrait = UIDeviceOrientationIsPortrait(orientation) && UIDeviceOrientationIsPortrait(lastOrientation)
//    guard (landscapeToLandscape || portraitToPortrait) && orientation != lastUsedOrientation else { return }
//    lastUsedOrientation = orientation
//    UIView.animate(withDuration: 0.6) { [weak self] in
//      self?.updateLayoutsForCurrentOrientation()
//    }
//  }
//
//  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//    coordinator.animate(alongsideTransition: { [weak self] _ in
//      self?.updateLayoutsForCurrentOrientation()
//    }, completion: { [weak self] _ in
//      self?.lastUsedOrientation = self?.deviceOrientationFromStatusBarOrientation()
//    })
//  }
//
//  private func updateLayoutsForCurrentOrientation() {
//    let transform = newTransform()
//
//    backgroundImageView.center = view.center
//    backgroundImageView.transform = transform.concatenating(CGAffineTransform(scaleX: 1, y: 1))
//
//    spinner.center = view.center
//
//    collectionView.performBatchUpdates({ [unowned self] in
//      self.collectionView.collectionViewLayout.invalidateLayout()
//      self.collectionView.frame = self.view.frame
//      let width = self.collectionView.frame.width
//      let page = Int((self.collectionView.contentOffset.x + (0.5 * width)) / width)
//      let updatedOffset = CGFloat(page) * self.collectionView.frame.width
//      self.collectionView.contentOffset = CGPoint(x: updatedOffset, y: self.collectionView.contentOffset.y)
//
//      let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
//      layout?.itemSize = self.view.frame.size
//    }, completion: { _ in
//      for visibleCell in self.collectionView.visibleCells as! [AgrumeCell] {
//        visibleCell.updateScrollViewAndImageViewForCurrentMetrics()
//      }
//    })
//  }
//
//  private func newTransform() -> CGAffineTransform {
//    switch initialOrientation {
//    case .portrait:
//      return transformPortrait()
//    case .portraitUpsideDown:
//      return transformPortraitUpsideDown()
//    case .landscapeLeft:
//      return transformLandscapeLeft()
//    case .landscapeRight:
//      return transformLandscapeRight()
//    default:
//      return .identity
//    }
//  }
//
//  private func transformPortrait() -> CGAffineTransform {
//    switch currentDeviceOrientation() {
//    case .landscapeLeft:
//      return CGAffineTransform(rotationAngle: .pi / 2)
//    case .landscapeRight:
//      return CGAffineTransform(rotationAngle: -(.pi / 2))
//    case .portraitUpsideDown:
//      return CGAffineTransform(rotationAngle: .pi)
//    default:
//      return .identity
//    }
//  }
//
//  private func transformPortraitUpsideDown() -> CGAffineTransform {
//    switch currentDeviceOrientation() {
//    case .landscapeLeft:
//      return CGAffineTransform(rotationAngle: -(.pi / 2))
//    case .landscapeRight:
//      return CGAffineTransform(rotationAngle: .pi / 2)
//    case .portrait:
//      return CGAffineTransform(rotationAngle: .pi)
//    default:
//      return .identity
//    }
//  }
//
//  private func transformLandscapeLeft() -> CGAffineTransform {
//    switch currentDeviceOrientation() {
//    case .landscapeRight:
//      return CGAffineTransform(rotationAngle: .pi)
//    case .portrait:
//      return CGAffineTransform(rotationAngle: -(.pi / 2))
//    case .portraitUpsideDown:
//      return CGAffineTransform(rotationAngle: .pi / 2)
//    default:
//      return .identity
//    }
//  }
//
//  private func transformLandscapeRight() -> CGAffineTransform {
//    switch currentDeviceOrientation() {
//    case .landscapeLeft:
//      return CGAffineTransform(rotationAngle: .pi)
//    case .portrait:
//      return CGAffineTransform(rotationAngle: .pi / 2)
//    case .portraitUpsideDown:
//      return CGAffineTransform(rotationAngle: -(.pi / 2))
//    default:
//      return .identity
//    }
//  }
//
//}
//
//extension Agrume: UICollectionViewDataSource {
//
//  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//    if let dataSource = dataSource {
//      return dataSource.numberOfImages
//    }
//    return images.count
//  }
//
//  public func collectionView(_ collectionView: UICollectionView,
//                             cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Agrume.reuseIdentifier,
//                                                  for: indexPath) as! AgrumeCell
//    if let dataSource = dataSource {
//      spinner.alpha = 1
//      let index = indexPath.row
//
//      dataSource.image(forIndex: index) { [weak self] image in
//        DispatchQueue.main.async {
//          cell.image = image
//          self?.spinner.alpha = 0
//        }
//      }
//    } else {
//      cell.image = images[indexPath.item].image
//    }
//
//    // Only allow panning if horizontal swiping fails. Horizontal swiping is only active for zoomed in images
//    collectionView.panGestureRecognizer.require(toFail: cell.swipeGesture)
//    cell.delegate = self
//    return cell
//  }
//
//}
//
//extension Agrume: UICollectionViewDelegate {
//
//  public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
//                             forItemAt indexPath: IndexPath) {
//    didScroll?(indexPath.row)
//
//    if let dataSource = dataSource {
//      let collectionViewCount = collectionView.numberOfItems(inSection: 0)
//      let dataSourceCount = dataSource.numberOfImages
//
//      if isDataSourceCountUnchanged(dataSourceCount: dataSourceCount, collectionViewCount: collectionViewCount) {
//        return
//      }
//
//      if isIndexPathOutOfBounds(indexPath, count: dataSourceCount) {
//        showImage(atIndex: dataSourceCount - 1)
//      }
//      reload()
//    } else if let url = images[indexPath.item].url {
//      let completion: DownloadCompletion = { [weak self] image in
//        (cell as! AgrumeCell).image = image
//        self?.spinner.alpha = 0
//      }
//      if let download = download {
//        download(url, completion)
//      } else if let download = AgrumeServiceLocator.shared.downloadHandler {
//        spinner.alpha = 1
//        download(url, completion)
//      } else {
//        spinner.alpha = 1
//        downloadImage(url, completion: completion)
//      }
//    }
//
//  }
//
//  private func downloadImage(_ url: URL, completion: @escaping DownloadCompletion) {
//    downloadTask = ImageDownloader.downloadImage(url) { image in
//      completion(image)
//    }
//  }
//
//  private func isDataSourceCountUnchanged(dataSourceCount: Int, collectionViewCount: Int) -> Bool {
//    return collectionViewCount == dataSourceCount
//  }
//
//  private func isIndexPathOutOfBounds(_ indexPath: IndexPath, count: Int) -> Bool {
//    return indexPath.item >= count
//  }
//
//  private func isLastElement(atIndexPath indexPath: IndexPath, count: Int) -> Bool {
//    return indexPath.item == count
//  }
//
//}
//
//extension Agrume: AgrumeCellDelegate {
//
//  private func dismissCompletion(_ finished: Bool) {
//    presentingViewController?.dismiss(animated: false) { [unowned self] in
//      self.cleanup()
//      self.didDismiss?()
//    }
//  }
//
//  private func cleanup() {
//    _blurContainerView?.removeFromSuperview()
//    _blurContainerView = nil
//    _blurView = nil
//    _collectionView?.visibleCells.forEach { cell in
//      (cell as? AgrumeCell)?.cleanup()
//    }
//    _collectionView?.removeFromSuperview()
//    _collectionView = nil
//    _spinner?.removeFromSuperview()
//    _spinner = nil
//  }
//
//  func dismissAfterFlick() {
//    UIView.animate(withDuration: Agrume.transitionAnimationDuration,
//                   delay: 0,
//                   options: .beginFromCurrentState,
//                   animations: { [unowned self] in
//                    self.collectionView.alpha = 0
//                    self.blurContainerView.alpha = 0
//      }, completion: dismissCompletion)
//  }
//
//  func dismissAfterTap() {
//    view.isUserInteractionEnabled = false
//
//    UIView.animate(withDuration: Agrume.transitionAnimationDuration,
//                   delay: 0,
//                   options: .beginFromCurrentState,
//                   animations: {
//                    self.collectionView.alpha = 0
//                    self.blurContainerView.alpha = 0
//                    let scaling = Agrume.maxScalingForExpandingOffscreen
//                    self.collectionView.transform = CGAffineTransform(scaleX: scaling, y: scaling)
//      }, completion: dismissCompletion)
//  }
//
//  func isSingleImageMode() -> Bool {
//    if let dataSource = dataSource {
//      return dataSource.numberOfImages == 1
//    }
//    return images.count == 1
//  }
//
//}
//
//extension Agrume {
//
//  // MARK: Status Bar
//
//  public override var preferredStatusBarStyle:  UIStatusBarStyle {
//    return statusBarStyle ?? super.preferredStatusBarStyle
//  }
//
//}
