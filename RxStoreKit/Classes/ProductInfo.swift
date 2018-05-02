//
//  ProductInfo.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 19/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import StoreKit

public enum ProductInfoType {
    case consumable
    case nonConsumable
    case nonRenewingSubscription
    case renewingSubscription
}

public typealias ProductInfoSubscriptionDuration = (unit: Calendar.Component, value: Int)

public struct ProductInfo {

    public var type: ProductInfoType = .nonConsumable
    public var productIdentifier: String = ""
    public var subscriptionDuration: ProductInfoSubscriptionDuration? // only for Non-Renewing Subscription
    
    public var isSubscription: Bool {
        return type == .nonRenewingSubscription || type == .renewingSubscription
    }
    
    public init?(type: ProductInfoType, productIdentifier: String, subscriptionDuration: ProductInfoSubscriptionDuration? = nil) {
        guard type != .nonRenewingSubscription || subscriptionDuration != nil else {
            return nil
        }
        self.type = type
        self.productIdentifier = productIdentifier
        self.subscriptionDuration = subscriptionDuration
    }
    
    public init?(type: ProductInfoType, product: SKProduct, subscriptionDuration: ProductInfoSubscriptionDuration? = nil) {
        self.init(type: type, productIdentifier: product.productIdentifier, subscriptionDuration: subscriptionDuration)
    }
}

extension ProductInfo: Equatable {
    
    public static func == (lhs: ProductInfo, rhs: ProductInfo) -> Bool {
        return lhs.productIdentifier == rhs.productIdentifier
    }
}
