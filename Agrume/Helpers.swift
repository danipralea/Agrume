//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import Foundation

func delay(_ delay: DispatchTimeInterval, closure: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: closure)
}
