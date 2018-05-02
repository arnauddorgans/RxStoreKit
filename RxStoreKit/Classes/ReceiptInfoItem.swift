//
//  ReceiptInfoItem.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 18/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import ObjectMapper

public struct ReceiptInfoItem: Mappable {
    
    public var productIdentifier: String = ""
    public var transactionID: String = ""
    public var originalTransactionID: String = ""
    
    public var purchaseDate: Date = Date()
    private var renewingExpiresDate: Date?
    
    public var quantity: Int = 0
    
    public var isTrialPeriod = false
    public var isInIntroOfferPeriod = false
    
    internal func expiresDate(from productInfo: ProductInfo) -> Date? {
        switch productInfo.type {
        case .renewingSubscription:
            return renewingExpiresDate
        case .nonRenewingSubscription:
            if let subscriptionDuration = productInfo.subscriptionDuration {
                return Locale.current.calendar.date(byAdding: subscriptionDuration.unit, value: subscriptionDuration.value, to: purchaseDate)
            }
        default:
            break
        }
        return nil
    }
    
    internal func validate(from productInfo: ProductInfo) -> Bool {
        guard productInfo.isSubscription else {
            return true
        }
        guard let expiresDate = self.expiresDate(from: productInfo) else {
            return false
        }
        return expiresDate.timeIntervalSinceNow > 0
    }

    public init?(map: Map) {
        guard let _: Int = try? map.value("quantity", using: IntTransform()),
            let _: String = try? map.value("product_id"),
            let _: String = try? map.value("transaction_id"),
            let _: String = try? map.value("original_transaction_id") else {
            return nil
        }
    }
    
    public mutating func mapping(map: Map) {
        quantity <- (map["quantity"], IntTransform())
        purchaseDate <- (map["purchase_date_ms"], DateTransform())
        renewingExpiresDate <- (map["expires_date_ms"], DateTransform())
        transactionID <- map["transaction_id"]
        originalTransactionID <- map["original_transaction_id"]
        productIdentifier <- map["product_id"]
        isTrialPeriod <- (map["is_trial_period"], BoolTransform())
        isInIntroOfferPeriod <- (map["is_in_intro_offer_period"], BoolTransform())
    }
}

extension ReceiptInfoItem: Equatable {
    
    public static func == (lhs: ReceiptInfoItem, rhs: ReceiptInfoItem) -> Bool {
        return lhs.originalTransactionID == rhs.originalTransactionID
    }
}

extension ReceiptInfoItem: Comparable {
    
    public static func < (lhs: ReceiptInfoItem, rhs: ReceiptInfoItem) -> Bool {
        return lhs.purchaseDate < rhs.purchaseDate
    }
}

private struct BoolTransform: TransformType {
    typealias Object = Bool
    typealias JSON = String
    
    func transformFromJSON(_ value: Any?) -> Bool? {
        guard let value = value as? String else {
            return nil
        }
        return value == "true"
    }
    
    func transformToJSON(_ value: Bool?) -> String? {
        return value.flatMap { $0 ? "true" : "false" }
    }
}

private struct IntTransform: TransformType {
    typealias Object = Int
    typealias JSON = String
    
    func transformFromJSON(_ value: Any?) -> Int? {
        guard let value = (value as? String).flatMap({ Int($0) }) else {
            return nil
        }
        return value
    }
    
    func transformToJSON(_ value: Int?) -> String? {
        return value.flatMap { String($0) }
    }
}

private struct DateTransform: TransformType {
    typealias Object = Date
    typealias JSON = String
    
    func transformFromJSON(_ value: Any?) -> Date? {
        guard let value = (value as? String).flatMap({ TimeInterval($0) }) else {
            return nil
        }
        return Date(timeIntervalSince1970: value / 1000)
    }
    
    func transformToJSON(_ value: Date?) -> String? {
        return value.flatMap { String($0.timeIntervalSince1970 * 1000) }
    }
}
