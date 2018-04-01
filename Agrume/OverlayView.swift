//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

public final class OverlayView: UIView {

  private lazy var navigationBar: UINavigationBar = {
    let navigationbar = UINavigationBar()
    navigationbar.isTranslucent = true
    navigationbar.shadowImage = UIImage()
    navigationItem = UINavigationItem(title: "")
    navigationbar.items = [navigationItem]
    return navigationbar
  }()

  private var navigationItem: UINavigationItem!
  private(set) lazy var descriptionLabel: UILabel = {
    let label = UILabel()
    label.usesAutolayout(true)
    label.numberOfLines = 0
    return label
  }()

  private var leftBarButtonItem: UIBarButtonItem! {
    didSet {
      navigationItem.leftBarButtonItem = leftBarButtonItem
    }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setupNavigationBar()
    setupDescription()
  }

  private func setupNavigationBar() {
    addSubview(navigationBar)
    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: portableTopAnchor),
      navigationBar.widthAnchor.constraint(equalTo: widthAnchor),
      navigationBar.centerXAnchor.constraint(equalTo: centerXAnchor)
    ])

    leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(close))
  }
  
  private func setupDescription() {
    addSubview(descriptionLabel)
    NSLayoutConstraint.activate([
      descriptionLabel.bottomAnchor.constraint(equalTo: portableBottomAnchor, constant: 8),
      descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8)
    ])
  }

  @objc
  private func close() {
    
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}
