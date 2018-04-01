//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

protocol OverlayViewDelegate: class {
  func didClose(overlayView view: OverlayView)
}

final class OverlayView: UIView {

  private lazy var navigationBar: UINavigationBar = {
    let navigationbar = UINavigationBar()
    navigationbar.usesAutolayout(true)
    navigationbar.isTranslucent = true
    navigationbar.shadowImage = UIImage()
    navigationbar.setBackgroundImage(UIImage(), for: .default)
    navigationbar.items = [navigationItem]
    return navigationbar
  }()
  
  private lazy var navigationItem: UINavigationItem = {
    return UINavigationItem(title: "")
  }()
  
  private lazy var descriptionLabel: UILabel = {
    let label = UILabel()
    label.usesAutolayout(true)
    label.numberOfLines = 0
    return label
  }()
  
  private lazy var formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    return formatter
  }()

  private var leftBarButtonItem: UIBarButtonItem! {
    didSet {
      navigationItem.leftBarButtonItem = leftBarButtonItem
    }
  }
  
  weak var delegate: OverlayViewDelegate?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupNavigationBar()
    setupDescription()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupNavigationBar() {
    addSubview(navigationBar)
    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: portableTopAnchor),
      navigationBar.widthAnchor.constraint(equalTo: widthAnchor),
      navigationBar.centerXAnchor.constraint(equalTo: centerXAnchor)
    ])

    leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Close", comment: "Close"), style: .plain, target: self,
                                        action: #selector(close))
  }
  
  @objc
  private func close() {
    delegate?.didClose(overlayView: self)
  }
  
  private func setupDescription() {
    addSubview(descriptionLabel)
    NSLayoutConstraint.activate([
      descriptionLabel.bottomAnchor.constraint(equalTo: portableBottomAnchor, constant: -8),
      descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8)
    ])
  }
  
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if let view = super.hitTest(point, with: event), view != self {
      return view
    }
    return nil
  }
  
  func updateOverlay(title: NSAttributedString?, current: Int, total: Int) {
    navigationItem.title = navigationTitle(current: current, total: total)
    descriptionLabel.attributedText = title
  }
  
  private func navigationTitle(current: Int, total: Int) -> String {
    let formattedCurrent = formatter.string(from: NSNumber(value: current))!
    let formattedTotal = formatter.string(from: NSNumber(value: total))!
    return String(format: NSLocalizedString("%@ of %@", comment: "{current} of {total}"), formattedCurrent, formattedTotal)
  }

}
