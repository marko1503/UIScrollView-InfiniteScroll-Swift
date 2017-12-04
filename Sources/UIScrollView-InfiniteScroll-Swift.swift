//
//  UIScrollView-InfiniteScroll-Swift.swift
//  UIScrollView-InfiniteScroll-Swift
//
//  Created by Maksym Prokopchuk on 12/1/17.
//  Copyright © 2017 UIScrollView-InfiniteScroll-Swift. All rights reserved.
//

import Foundation
import UIKit

protocol ActivityIndicatorViewInterface {

    var isAnimating: Bool { get }

    func startAnimating()

    func stopAnimating()

}

extension UIActivityIndicatorView: ActivityIndicatorViewInterface {}

protocol ScrollViewInfiniteActivityDelegate: class {

    func didRequestShowScrollViewInfiniteActivity(_ infiniteScrollActivity: ScrollViewInfiniteActivity)

}

class ScrollViewInfiniteActivity {

    weak var delegate: ScrollViewInfiniteActivityDelegate?

    // MARK: - UI Elements
    @objc dynamic private(set) weak var scrollView: UIScrollView?

    /**
     *  Infinite indicator view
     *
     *  You can set your own custom view instead of default activity indicator,
     *  make sure it implements methods below:
     *
     *  * `- (void)startAnimating`
     *  * `- (void)stopAnimating`
     *
     *  Infinite scroll will call implemented methods during user interaction.
     */
    lazy var activityIndicatorView: (UIView & ActivityIndicatorViewInterface) = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        return activityIndicator
    }()

    // MARK: -

    /// Flag that indicates whether activity indicator is animating
    private(set) var isAnimatingActivityIndicator: Bool = false

    /// Indicator view inset. Essentially is equal to indicator view height.
    var activityIndicatorInset: CGFloat = 0.0


    /// Vertical margin around indicator view (Default: 11)
    var activityIndicatorMargin: CGFloat = 11.0

    /// A row height for indicator view, in other words: indicator margin + indicator height.
    var acitivityIndicatorHeight: CGFloat {
        let height: CGFloat = self.activityIndicatorView.bounds.height
        return height + self.activityIndicatorMargin * 2
    }

    /**
     *  Sets the offset between the real end of the scroll view content and the scroll position, so the handler can be triggered before reaching end.
     *  Defaults to 0.0;
     */
    var triggerOffset: CGFloat = 0.0


    /// Default value is true.
    var isEnabled: Bool = true

    private var contentOffsetObservation: NSKeyValueObservation? = nil

    private var contentSizeObservation: NSKeyValueObservation? = nil

    // MARK: - Init
    init(scrollView: UIScrollView) {
        self.scrollView = scrollView

        self.contentOffsetObservation = scrollView.observe(\.contentOffset) { [weak self] (scrollView, change) in
            self?.p_loadingMoreItemsIfNeeded(with: scrollView)
        }

        self.contentSizeObservation = scrollView.observe(\.contentSize) { [weak self] (scrollView, change) in
            guard self?.isAnimatingActivityIndicator == true else { return }
            self?.p_positionActitivityIndicator(with: scrollView.contentSize)
        }

    }

    // MARK: -
    func startActivityIndicator() {
        guard let scrollView = scrollView else { return }
        self.p_startAnimatingActivityIndicator(at: scrollView)
    }

    func stopActivityIndicator() {
        guard let scrollView = scrollView else { return }
        self.p_stopAnimatingActivityIndicator(at: scrollView)
    }

    /**
     *  Start animating infinite indicator
     */
    private func p_startAnimatingActivityIndicator(at scrollView: UIScrollView) {
        // Add activity indicator into scroll view if needed
        if (self.activityIndicatorView.superview !== self.scrollView) {
            self.activityIndicatorView.removeFromSuperview()
            scrollView.addSubview(self.activityIndicatorView)
        }

        // Calculate indicator view inset
        self.activityIndicatorInset = self.acitivityIndicatorHeight

        // Layout indicator view
        self.p_positionActitivityIndicator(with: scrollView.contentSize)

        // Make a room to accommodate indicator view
        var contentInset = scrollView.contentInset;
        contentInset.bottom += self.activityIndicatorInset;

        // It's show time!
        self.activityIndicatorView.isHidden = false
        self.activityIndicatorView.startAnimating()

        self.isAnimatingActivityIndicator = true

        // Animate content insets
        self.p_setContentInset(contentInset, forScrollView: scrollView, animated: true) { (finished: Bool) in
            if finished == true {
                self.p_scrollToActivityIndicatorIfNeeded(with: scrollView, reveal: true)
            }
        }
    }

    private func p_stopAnimatingActivityIndicator(at scrollView: UIScrollView) {
        //    UIView <ORZActivityIndicatorViewInterface> *activityIndicator = self.activityIndicatorView;
        var contentInset = scrollView.contentInset

        // Remove row height inset
        contentInset.bottom -= self.activityIndicatorInset

        // Reset indicator view inset
        self.activityIndicatorInset = 0.0

        // Animate content insets
        self.p_setContentInset(contentInset, forScrollView: scrollView, animated: true) { [weak self] (finished: Bool) in
            // Initiate scroll to the bottom if due to user interaction contentOffset.y
            // stuck somewhere between last cell and activity indicator
            if (finished == true) {
                self?.p_scrollToActivityIndicatorIfNeeded(with: scrollView, reveal: false)
            }

            // Curtain is closing they're throwing roses at my feet
            self?.activityIndicatorView.stopAnimating()
            self?.activityIndicatorView.isHidden = true

            // Reset scroll state
            self?.isAnimatingActivityIndicator = false
        }
    }

    // MARK: - Loading More Items
    private func p_isAvailableLoadingMoreItems(with scrollView: UIScrollView) -> Bool {
        guard self.isEnabled == true else { return false }
        guard scrollView.contentSize.height != 0.0 else { return false }
        guard self.isAnimatingActivityIndicator == false else { return false }

        let bottomOffset = scrollView.contentOffset.y + scrollView.frame.height
        let loadingMoreItemsOffset = scrollView.contentSize.height - self.triggerOffset
        let isAvailableLoadingMoreItems = bottomOffset >= loadingMoreItemsOffset
        return isAvailableLoadingMoreItems
    }

    private func p_loadingMoreItemsIfNeeded(with scrollView: UIScrollView) {
        guard self.p_isAvailableLoadingMoreItems(with: scrollView) == true else { return }
        self.delegate?.didRequestShowScrollViewInfiniteActivity(self)
        self.p_startAnimatingActivityIndicator(at: scrollView)
    }

    // MARK: - Animation
    /**
     *  Scrolls down to activity indicator if it is partially visible
     *
     *  @param reveal scroll to reveal or hide activity indicator
     */
    private func p_scrollToActivityIndicatorIfNeeded(with scrollView: UIScrollView, reveal: Bool) {
        // do not interfere with user
        guard scrollView.isDragging == false else { return }

        // filter out calls from pan gesture
        guard self.isAnimatingActivityIndicator == true else { return }

        let contentHeight: CGFloat = scrollView.contentSize.height
        let indicatorRowHeight: CGFloat = self.activityIndicatorInset

        let maxY: CGFloat = contentHeight
        let minY: CGFloat  = maxY - indicatorRowHeight
        let contentOffset: CGFloat = scrollView.contentOffset.y

        guard contentOffset > minY, contentOffset < maxY else { return }
        let newContentOffsetY = reveal ? maxY : minY
        let newContentOffset = CGPoint(x: 0.0, y:newContentOffsetY)
        scrollView.setContentOffset(newContentOffset, animated: true)
    }

    // Animation duration used for setContentOffset:
    let kInfiniteScrollAnimationDuration: TimeInterval = 0.35

    /**
     *  Set content inset with animation.
     *
     *  @param contentInset a new content inset
     *  @param animated     animate?
     *  @param completion   a completion block
     */
    private func p_setContentInset(_ contentInset: UIEdgeInsets,
                                   forScrollView scrollView: UIScrollView,
                                   animated: Bool,
                                   completion: ((Bool) -> Void)?) {
        let transformClosure: () -> Void = {
            scrollView.contentInset = contentInset
        }

        if animated == true {
            UIView.animate(withDuration: kInfiniteScrollAnimationDuration,
                           delay: 0.0,
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: transformClosure,
                           completion: completion)
        }
        else {
            UIView.performWithoutAnimation(transformClosure)
            if let completion = completion {
                completion(true)
            }
        }
    }

    /**
     *  Update infinite scroll indicator's position in view.
     *
     *  @param contentSize content size.
     */
    private func p_positionActitivityIndicator(with contentSize: CGSize) {
        let contentHeight = contentSize.height
        let indicatorRowHeight = self.activityIndicatorInset
        let centerX = contentSize.width / 2.0
        let centerY = contentHeight + indicatorRowHeight / 2.0
        let center = CGPoint(x: centerX, y: centerY)

        guard self.activityIndicatorView.center != center else { return }

        self.activityIndicatorView.center = center
    }

}
