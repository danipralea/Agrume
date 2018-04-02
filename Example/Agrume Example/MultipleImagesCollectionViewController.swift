//
//  Copyright © 2016 Schnaub. All rights reserved.
//

import UIKit
import Agrume

final class MultipleImagesCollectionViewController: UICollectionViewController {

  private let identifier = "Cell"
  
  private let attributes: [NSAttributedStringKey: Any] = [.foregroundColor: UIColor.white,
                                                          .font: UIFont.systemFont(ofSize: 14)]

  private var images: [AgrumeImage] = []

  override func viewDidLoad() {
    super.viewDidLoad()

    let layout = collectionView?.collectionViewLayout as! UICollectionViewFlowLayout
    layout.itemSize = CGSize(width: view.bounds.width, height: view.bounds.height)
    
    images.append(AgrumeImage(image: #imageLiteral(resourceName: "MapleBacon"), title: NSAttributedString(string: "A lemony fresh image view", attributes: attributes)))
    images.append(AgrumeImage(image: #imageLiteral(resourceName: "EvilBacon"), title: NSAttributedString(string: "Written in Swift", attributes: attributes)))
  }

  // MARK: UICollectionViewDataSource

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return images.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! DemoCell
    cell.imageView.image = images[indexPath.row].image
    return cell
  }

  // MARK: UICollectionViewDelegate

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let agrume = Agrume(images: images, startIndex: indexPath.item, configuration: [.withOverlay])
//    agrume.didScroll = { [unowned self] index in
//      self.collectionView?.scrollToItem(at: IndexPath(item: index, section: 0), at: [], animated: false)
//    }
    present(agrume, animated: true)
  }

}
