//
//  ScaleTransformView.swift
//  CollectionViewPagingLayout
//
//  Created by Amir on 15/02/2020.
//  Copyright © 2020 Amir Khorsandi. All rights reserved.
//

import UIKit

/// A protocol for adding scale transformation to `TransformableView`
public protocol ScaleTransformView: TransformableView {
    
    /// Options for controlling scale effect, see `ScaleTransformViewOptions.swift`
    var scaleOptions: ScaleTransformViewOptions { get }
    
    /// The view to apply scale effect on
    var scalableView: UIView { get }
    
    /// The view to apply blur effect on
    var blurViewHost: UIView { get }
    
    /// the main function for applying transforms
    func applyScaleTransform(progress: CGFloat)
}


public extension ScaleTransformView {
    
    /// The default value is the super view of `scalableView`
    var blurViewHost: UIView {
        scalableView.superview ?? scalableView
    }
}


public extension ScaleTransformView where Self: UICollectionViewCell {
    
    /// Default `scalableView` for `UICollectionViewCell` is the first subview of
    /// `contentView` or the content view itself if there is no subview
    var scalableView: UIView {
        contentView.subviews.first ?? contentView
    }
}


public extension ScaleTransformView {
    
    // MARK: Properties
    
    var scaleOptions: ScaleTransformViewOptions {
        .init()
    }
    
    
    // MARK: TransformableView
    
    func transform(progress: CGFloat) {
        applyScaleTransform(progress: progress)
    }
    
    
    // MARK: Public functions
    
    func applyScaleTransform(progress: CGFloat) {
        applyStyle(progress: progress)
        applyScaleAndTranslation(progress: progress)
        applyCATransform3D(progress: progress)
        
        if #available(iOS 10, *) {
            applyBlurEffect(progress: progress)
        }
        
    }
    
    
    // MARK: Private functions
    
    private func applyStyle(progress: CGFloat) {
        guard scaleOptions.shadowEnabled else {
            return
        }
        let layer = scalableView.layer
        layer.shadowColor = scaleOptions.shadowColor.cgColor
        let offset = CGSize(
            width: max(scaleOptions.shadowOffsetMin.width, (1 - abs(progress)) * scaleOptions.shadowOffsetMax.width),
            height: max(scaleOptions.shadowOffsetMin.height, (1 - abs(progress)) * scaleOptions.shadowOffsetMax.height)
        )
        layer.shadowOffset = offset
        layer.shadowRadius = max(scaleOptions.shadowRadiusMin, (1 - abs(progress)) * scaleOptions.shadowRadiusMax)
        layer.shadowOpacity = max(scaleOptions.shadowOpacityMin, (1 - abs(Float(progress))) * scaleOptions.shadowOpacityMax)
    }
    
    private func applyScaleAndTranslation(progress: CGFloat) {
        var transform = CGAffineTransform.identity
        var xAdjustment: CGFloat = 0
        var yAdjustment: CGFloat = 0
        let scaleProgress = scaleOptions.scaleCurve.computeFromLinear(progress: abs(progress))
        var scale = 1 - scaleProgress * scaleOptions.scaleRatio
        scale = max(scale, scaleOptions.minScale)
        scale = min(scale, scaleOptions.maxScale)
        
        if scaleOptions.keepHorizontalSpacingEqual {
            xAdjustment = ((1 - scale) * scalableView.bounds.width) / 2
            if progress > 0 {
                xAdjustment *= -1
            }
        }
        
        if scaleOptions.keepVerticalSpacingEqual {
            yAdjustment = ((1 - scale) * scalableView.bounds.height) / 2
        }
        
        let translateProgress = scaleOptions.translationCurve.computeFromLinear(progress: abs(progress))
        var translateX = scalableView.bounds.width * scaleOptions.translationRatio.x * (translateProgress * (progress < 0 ? -1 : 1)) - xAdjustment
        var translateY = scalableView.bounds.height * scaleOptions.translationRatio.y * abs(translateProgress) - yAdjustment
        if let min = scaleOptions.minTranslationRatio {
            translateX = max(translateX, scalableView.bounds.width * min.x)
            translateY = max(translateY, scalableView.bounds.height * min.y)
        }
        if let max = scaleOptions.maxTranslationRatio {
            translateX = min(translateX, scalableView.bounds.width * max.x)
            translateY = min(translateY, scalableView.bounds.height * max.y)
        }
        transform = transform
            .translatedBy(x: translateX, y: translateY)
            .scaledBy(x: scale, y: scale)
        scalableView.transform = transform
    }
    
    private func applyCATransform3D(progress: CGFloat) {
        var transform = CATransform3DMakeAffineTransform(scalableView.transform)
        
        if let options = self.scaleOptions.rotation3d {
            var angle = options.angle * progress
            angle = max(angle, options.minAngle)
            angle = min(angle, options.maxAngle)
            transform.m34 = options.m34
            transform = CATransform3DRotate(transform, angle, options.x, options.y, options.z)
            scalableView.layer.isDoubleSided = options.isDoubleSided
        }
        
        if let options = self.scaleOptions.translation3d {
            var x = options.translateRatios.0 * progress
            var y = options.translateRatios.1 * abs(progress)
            var z = options.translateRatios.2 * abs(progress)
            x = max(x, options.minTranslates.0)
            x = min(x, options.maxTranslates.0)
            y = max(y, options.minTranslates.1)
            y = min(y, options.maxTranslates.1)
            z = max(z, options.minTranslates.2)
            z = min(z, options.maxTranslates.2)
            
            transform = CATransform3DTranslate(transform, x, y, z)
        }
        scalableView.layer.transform = transform
    }
    
    @available(iOS 10.0, *)
    private func applyBlurEffect(progress: CGFloat) {
        guard scaleOptions.blurEffectRadiusRatio > 0, scaleOptions.blurEffectEnabled else {
            return
        }
        let blurView: BlurEffectView
        if let view = blurViewHost.subviews.first(where: { $0 is BlurEffectView }) as? BlurEffectView {
            blurView = view
        } else {
            blurView = BlurEffectView(effect: UIBlurEffect(style: scaleOptions.blurEffectStyle))
            blurViewHost.fill(with: blurView)
        }
        blurView.setBlurRadius(radius: abs(progress) * scaleOptions.blurEffectRadiusRatio)
        blurView.transform = CGAffineTransform.identity.translatedBy(x: scalableView.transform.tx, y: scalableView.transform.ty)
    }
    
}
