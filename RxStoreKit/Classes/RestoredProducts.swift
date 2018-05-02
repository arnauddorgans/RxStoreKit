//
//  RestoredProducts.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 23/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import StoreKit

public struct RestoredProduct {
    
    public let product: SKProduct
    public let info: ProductInfo
    public let receipt: ReceiptInfoItem
    
    public var isValid: Bool {
        return receipt.validate(from: info)
    }
    
    public var expiresDate: Date? {
        return receipt.expiresDate(from: info)
    }
}

extension RestoredProduct: Equatable {
    
    public static func == (lhs: RestoredProduct, rhs: RestoredProduct) -> Bool {
        return lhs.receipt == rhs.receipt
    }
}

extension RestoredProduct: Comparable {
    
    public static func < (lhs: RestoredProduct, rhs: RestoredProduct) -> Bool {
        return lhs.receipt < rhs.receipt
    }
}

public struct RestoredProducts {
    
    private var _products: [RestoredProduct] = []
    private(set) var products: [RestoredProduct] {
        get { return _products }
        set {
            _products = newValue.sorted().reversed().reduce([]) { products, product in
                var products = products
                if !products.contains(product) {
                    products.append(product)
                }
                return products
            }.sorted()
        }
    }
    
    public var validProducts: [RestoredProduct] {
        return products.filter { $0.isValid }
    }
    
    public var invalidProducts: [RestoredProduct] {
        return products.filter { !$0.isValid }
    }
    
    public mutating func addProduct(_ product: RestoredProduct) {
        products.append(product)
    }
    
    init(products: [RestoredProduct]) {
        self.products = products
    }
}

extension RestoredProducts: RandomAccessCollection {
    
    public var startIndex: Int { return products.startIndex }
    public var endIndex: Int { return products.endIndex }
    
    public subscript(position: Int) -> RestoredProduct {
        return products[position]
    }
    
    public func makeIterator() -> IndexingIterator<[RestoredProduct]> {
        return products.makeIterator()
    }
}

extension RestoredProducts: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = RestoredProduct
    
    public init(arrayLiteral elements: RestoredProducts.ArrayLiteralElement...) {
        self.init(products: Array(elements))
    }
}
