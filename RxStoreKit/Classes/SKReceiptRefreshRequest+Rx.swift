//
//  SKReceiptRefreshRequest+Rx.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 18/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import RxCocoa
import StoreKit
import RxSwift
import RxAlamofire
import Alamofire
import RxAlamofire_ObjectMapper

public enum ReceiptEnvironment {
    case production
    case sandbox
    
    static let `default` = production
    
    var next: ReceiptEnvironment {
        switch self {
        case .sandbox:
            return .production
        case .production:
            return .sandbox
        }
    }
    
    var nextCode: Int? {
        switch self {
        case .production:
            return 21007
        default:
            return nil
        }
    }
    
    var url: URLConvertible {
        switch self {
        case .production:
            return "https://buy.itunes.apple.com/verifyReceipt"
        case .sandbox:
            return "https://sandbox.itunes.apple.com/verifyReceipt"
        }
    }
}

private class RxSKReceiptRefreshRequestDelegate: DelegateProxy<SKReceiptRefreshRequest, SKRequestDelegate>, DelegateProxyType, SKRequestDelegate {
    
    let receiptRefreshRequest: SKReceiptRefreshRequest
    var receiptURL: URL! {
        return Bundle.main.appStoreReceiptURL
    }
    
    init(receiptRefreshRequest: SKReceiptRefreshRequest) {
        self.receiptRefreshRequest = receiptRefreshRequest
        super.init(parentObject: receiptRefreshRequest, delegateProxy: RxSKReceiptRefreshRequestDelegate.self)
    }
    
    static func registerKnownImplementations() {
        self.register(make: { RxSKReceiptRefreshRequestDelegate(receiptRefreshRequest: $0) })
    }
    
    static func currentDelegate(for object: SKReceiptRefreshRequest) -> SKRequestDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: SKRequestDelegate?, to object: SKReceiptRefreshRequest) {
        object.delegate = delegate
    }
    
    let didFinish = PublishSubject<Void>()
    func requestDidFinish(_ request: SKRequest) {
        didFinish.onNext(())
        didFinish.onCompleted()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        didFinish.onError(error)
    }
    
    func start(password: String?, environment: ReceiptEnvironment) -> Observable<[ReceiptInfoItem]> {
        return Observable.create { observer in
            let disposable = self.didFinish.bind(to: observer)
            self.receiptRefreshRequest.start()
            return Disposables.create {
                disposable.dispose()
                self.receiptRefreshRequest.cancel()
            }
            }.flatMapLatest {
                self.verify(password: password, environment: environment)
            }
    }
    
    private func verify(password: String?, environment: ReceiptEnvironment) -> Observable<[ReceiptInfoItem]> {
        do {
            let data = try Data(contentsOf: self.receiptURL)
            var parameters: [String: Any] = ["receipt-data": data.base64EncodedString(options: [])]
            if let password = password {
                parameters["password"] = password
            }
            return requestJSON(.post, environment.url, parameters: parameters, encoding: JSONEncoding.default)
                .flatMapLatest { value -> Observable<[ReceiptInfoItem]> in
                    guard value.0.statusCode != environment.nextCode else {
                        return self.verify(password: password, environment: environment.next)
                    }
                    return Observable.just(value).mappableArray(as: ReceiptInfoItem.self, keyPath: "latest_receipt_info")
                }
        } catch {
            return Observable.error(error)
        }
    }
}

extension Reactive where Base: SKReceiptRefreshRequest {
    
    private var delegate: RxSKReceiptRefreshRequestDelegate {
        return RxSKReceiptRefreshRequestDelegate.proxy(for: self.base)
    }
    
    func start(password: String? = nil, environment: ReceiptEnvironment) -> Observable<[ReceiptInfoItem]> {
        return delegate.start(password: password, environment: environment)
    }
}
