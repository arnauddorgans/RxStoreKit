//
//  SKProductsRequest+Rx.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 18/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import StoreKit
import RxCocoa
import RxSwift

private class RxSKProductsRequestDelegate: DelegateProxy<SKProductsRequest, SKProductsRequestDelegate>, DelegateProxyType, SKProductsRequestDelegate {
    
    let productsRequest: SKProductsRequest
    
    init(productsRequest: SKProductsRequest) {
        self.productsRequest = productsRequest
        super.init(parentObject: productsRequest, delegateProxy: RxSKProductsRequestDelegate.self)
    }
    
    static func registerKnownImplementations() {
        self.register(make: { RxSKProductsRequestDelegate(productsRequest: $0) })
    }
    
    static func currentDelegate(for object: SKProductsRequest) -> SKProductsRequestDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: SKProductsRequestDelegate?, to object: SKProductsRequest) {
        object.delegate = delegate
    }
    
    let didReceiveResponse = PublishSubject<SKProductsResponse>()
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        didReceiveResponse.onNext(response)
        didReceiveResponse.onCompleted()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        didReceiveResponse.onError(error)
    }
    
    func start() -> Observable<SKProductsResponse> {
        return Observable.create { observer in
            let disposable = self.didReceiveResponse.bind(to: observer)
            self.productsRequest.start()
            return Disposables.create {
                disposable.dispose()
                self.productsRequest.cancel()
            }
        }
    }
    
    static func restoreProducts(fromProducts products: [SKProduct], productInfos: [ProductInfo], password: String? = nil, environment: ReceiptEnvironment) -> Observable<RestoredProducts> {
        return SKReceiptRefreshRequest().rx.start(password: password, environment: environment)
            .map { items in
                items.reduce([]) { values, receipt -> RestoredProducts in
                    var values = values
                    if let product = products.first(where: { $0.productIdentifier == receipt.productIdentifier }),
                        let info = productInfos.first(where: { $0.productIdentifier == receipt.productIdentifier }) {
                        values.addProduct(RestoredProduct(product: product, info: info, receipt: receipt))
                    }
                    return values
                }
        }
    }
    
    static func restoreProducts(fromProductInfos productInfos: [ProductInfo], password: String? = nil, environment: ReceiptEnvironment) -> Observable<RestoredProducts> {
        return SKProductsRequest(productInfos: productInfos).rx
            .start()
            .map { $0.products }
            .flatMapLatest { products in
                self.restoreProducts(fromProducts: products, productInfos: productInfos, password: password, environment: environment)
        }
    }
}

extension SKProductsRequest {
    
    public convenience init(productInfos: [ProductInfo]) {
        self.init(productIdentifiers: Set(productInfos.map { $0.productIdentifier }))
    }
}

extension Reactive where Base: SKProductsRequest {
    
    private var delegate: RxSKProductsRequestDelegate {
        return RxSKProductsRequestDelegate.proxy(for: self.base)
    }
    
    public func start() -> Observable<SKProductsResponse> {
        return delegate.start()
    }
    
    public static func restoreProducts(fromProductInfos productInfos: [ProductInfo], password: String? = nil, environment: ReceiptEnvironment) -> Observable<RestoredProducts> {
        return RxSKProductsRequestDelegate.restoreProducts(fromProductInfos: productInfos, password: password, environment: environment)
    }
    
    public static func restoreProducts(fromProducts products: [SKProduct], productInfos: [ProductInfo], password: String? = nil, environment: ReceiptEnvironment) -> Observable<RestoredProducts> {
        return RxSKProductsRequestDelegate.restoreProducts(fromProducts: products, productInfos: productInfos, password: password, environment: environment)
    }
}
