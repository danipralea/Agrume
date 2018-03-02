//
//  Copyright © 2018 Schnaub. All rights reserved.
//

import UIKit

final class TransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

  var animator: UIViewControllerAnimatedTransitioning?
  var startView: UIView?
  var finalView: UIView?
  var startViewForAnimation: UIView?
  var finalViewForAnimation: UIView?
  var viewToHideOnInteractiveTransition: UIView?

  var isDismissing = false
  var isAnimatingUsingAnimator = false

  private var transitionContext: UIViewControllerContextTransitioning?

  func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
    viewToHideOnInteractiveTransition?.alpha = 0
    self.transitionContext = transitionContext
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.5
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    setupViewHierarchy(using: transitionContext)
    zoom(using: transitionContext)
    fadeIn(using: transitionContext)
  }

  private func setupViewHierarchy(using transitionContext: UIViewControllerContextTransitioning) {
    if let toView = transitionContext.view(forKey: .to), let toViewController = transitionContext.viewController(forKey: .to) {
      toView.frame = transitionContext.finalFrame(for: toViewController)
      if !toView.isDescendant(of: transitionContext.containerView) {
        transitionContext.containerView.addSubview(toView)
      }
    }

    guard isDismissing, let fromView = transitionContext.view(forKey: .from) else { return }
    transitionContext.containerView.bringSubview(toFront: fromView)
  }

  private func zoom(using transitionContext: UIViewControllerContextTransitioning) {
    guard let startView = startView,
          let finalView = finalView,
          let startViewForAnimation = startViewForAnimation ?? startView.snapshotView(),
          let finalViewForAnimation = finalViewForAnimation ?? finalView.snapshotView() else { return }

    let containerView = transitionContext.containerView
    let finalViewTransform = finalView.transform
    let finalViewInitialTransform = startViewForAnimation.frame.height / finalViewForAnimation.frame.height
    let translatedViewCenter = startView.translatedCenter(toContainerView: containerView)

    startViewForAnimation.center = translatedViewCenter

    finalViewForAnimation.transform = finalViewForAnimation.transform.scaledBy(x: finalViewInitialTransform,
                                                                               y: finalViewInitialTransform)
    finalViewForAnimation.center = translatedViewCenter
    finalViewForAnimation.alpha = 0

    containerView.addSubview(startViewForAnimation)
    containerView.addSubview(finalViewForAnimation)

    startView.alpha = 0
    finalView.alpha = 0

    let fadeInDuration = transitionDuration(using: transitionContext) * 0.1
    let fadeOutDuration = transitionDuration(using: transitionContext) * 0.05
    let animationOptions: UIViewAnimationOptions = [.allowAnimatedContent, .beginFromCurrentState]

    UIView.animate(withDuration: fadeInDuration, delay: 0, options: animationOptions,
                   animations: {
                    finalViewForAnimation.alpha = 1
    })
    UIView.animate(withDuration: fadeOutDuration, delay: fadeInDuration, options: animationOptions,
                   animations: {
                    startViewForAnimation.alpha = 0
    }, completion: { _ in
      startViewForAnimation.removeFromSuperview()
    })

    let startViewFinalTransform = 1 / finalViewInitialTransform
    let translatedFinalCenter = finalView.translatedCenter(toContainerView: containerView)

    UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 0.9,
                   initialSpringVelocity: 0, options: animationOptions,
                   animations: {
                    finalViewForAnimation.transform = finalViewTransform
                    finalViewForAnimation.center = translatedFinalCenter
                    startViewForAnimation.transform = startViewForAnimation.transform.scaledBy(x: startViewFinalTransform,
                                                                                               y: startViewFinalTransform)
                    startViewForAnimation.center = translatedFinalCenter
    }, completion: { _ in
      finalViewForAnimation.removeFromSuperview()
      finalView.alpha = 1
      startView.alpha = 1
      self.completeTransition(using: transitionContext)
    })
  }

  private func completeTransition(using transitionContext: UIViewControllerContextTransitioning) {
    if transitionContext.isInteractive {
      if transitionContext.transitionWasCancelled {
        transitionContext.cancelInteractiveTransition()
      } else {
        transitionContext.finishInteractiveTransition()
      }
    }
    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
  }

  private func fadeIn(using transitionContext: UIViewControllerContextTransitioning) {
    let view = isDismissing ? transitionContext.view(forKey: .from) : transitionContext.view(forKey: .to)
    let startAlpha: CGFloat = isDismissing ? 1 : 0
    let finalAlpha: CGFloat = isDismissing ? 0 : 1

    view?.alpha = startAlpha

    UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
      view?.alpha = finalAlpha
    }, completion: { _ in
      self.completeTransition(using: transitionContext)
    })
  }

}
