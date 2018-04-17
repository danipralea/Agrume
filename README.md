[![Build Status](https://travis-ci.org/JanGorman/Agrume.svg?branch=master)](https://travis-ci.org/JanGorman/Agrume) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/Agrume.svg?style=flat)](http://cocoapods.org/pods/Agrume)
[![License](https://img.shields.io/cocoapods/l/Agrume.svg?style=flat)](http://cocoapods.org/pods/Agrume)
[![Platform](https://img.shields.io/cocoapods/p/Agrume.svg?style=flat)](http://cocoapods.org/pods/Agrume)

# Agrume

An iOS image viewer written in Swift with support for multiple images.

![Agrume](https://www.dropbox.com/s/bdt6sphcyloa38u/Agrume.gif?raw=1)

## Requirements

- Swift 4.1 (for Swift 3 support, use version 3.x)
- iOS 8.0+
- Xcode 9+

## Installation

The easiest way is through [CocoaPods](http://cocoapods.org). Simply add the dependency to your `Podfile` and then `pod install`:

```ruby
pod 'Agrume', :git => 'https://github.com/JanGorman/Agrume.git'
```

Or [Carthage](https://github.com/Carthage/Carthage). Add the dependency to your `Cartfile` and then `carthage update`:

```ogdl
github "JanGorman/Agrume"
```

## How

There are multiple ways you can use the image viewer (and the included sample project shows them all).

For just a single image it's as easy as

### Basic

```swift
import Agrume

@IBAction func openImage(_ sender: Any) {
  guard let image = UIImage(named: "…") else { return }

  let agrume = Agrume(image: image)
  // Present Agrume like any regular UIViewController
  present(agrume, animated: true)
}
```

You can also pass in a `URL` and Agrume will take care of the download for you.

### Background Configuration

Agrume has different background configurations. You can have it blur the view it's covering or supply a background color:

```swift
let agrume = Agrume(image: UIImage(named: "…")!, background: .blurred(.regular))
// or
let agrume = Agrume(image: UIImage(named: "…")!, background: .colored(.green))
```

### Image With Description

There's support to show a description beneath each image. By passing a wrapper type `AgrumeImage` instead of just a regular `UIImage` or `URL` you can supply an `NSAttributedString`:

```swift
let title = NSAttributedString(string: "…")
let image = AgrumeImage(image: UIImage(named: "…")!, title: title)
let agrume = Agrume(image: image, background: .colored(.black), configuration: [.withOverlay])
present(agrume, animated: true)
```

### Multiple Images

If you're displaying a `UICollectionView` and want to add support for zooming, you can also call Agrume with an array of either images or URLs.

```swift
let agrume = Agrume(images: images, startIndex: indexPath.row, background: .blurred(.regular))
// Keep image in sync with what's going on in Agrume
agrume.didScroll = { [unowned self] index in
  self.collectionView?.scrollToItem(at: IndexPath(row: index, section: 0),
                                    at: [],
                                    animated: false)
}
present(agrume, animated: true)
```

### Custom Download Handler

If you want to take control of downloading images (e.g. for caching), you can also set a download closure that calls back to Agrume to set the image. For example, let's use [MapleBacon](https://github.com/JanGorman/MapleBacon).

```swift
import Agrume
import MapleBacon

@IBAction func openURL(_ sender: Any) {
  let agrume = Agrume(imageUrl: URL(string: "https://dl.dropboxusercontent.com/u/512759/MapleBacon.png")!)
  agrume.download = { url, completion in
    Downloader.default.download(url) { image in
      completion(image)
    }
  }
  present(agrume, animated: true)
}
```

### Global Custom Download Handler

Instead of having to define a handler on a per instance basis you can instead set a handler on the `AgrumeServiceLocator`. Agrume will use this handler for all downloads unless overriden on an instance as described above:

```swift
import Agrume

AgrumeServiceLocator.shared.setDownloadHandler { url, completion in
  // Download data, cache it and remember to call the completion
}

// Some other place
present(agrume, animated: true)

```

### Custom Data Source

For more dynamic library needs you can implement the `AgrumeDataSource` protocol that supplies images to Agrume. Agrume will query the data source for the number of images and if that number changes, reload it's scrolling image view.

```swift
import Agrume

let dataSource: AgrumeDataSource = MyDataSourceImplementation()
let agrume = Agrume(dataSource: dataSource)

agrume.showFrom(self)

```

### Status Bar Appearance

You can customize the status bar appearance when displaying the zoomed in view. `Agrume` has a `statusBarStyle` property:

```swift
let agrume = Agrume(image: image)
agrume.statusBarStyle = .lightContent
present(agrume, animated: true)
```

## Licence

Agrume is released under the MIT license. See LICENSE for details
