//
//  RxPaymentTransactionObserver.swift
//  In App Test
//
//  Created by Arnaud Dorgans on 18/04/2018.
//  Copyright © 2018 La Noosphere. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import StoreKit
import Alamofire

typealias DownloadProgressObservable = (download: SKDownload, progress: Observable<SKDownload>)

private class RxPaymentTransactionObserverManager {
    
    let queue: SKPaymentQueue
    
    private var _observer: SKPaymentTransactionObserver?
    var observer: SKPaymentTransactionObserver? {
        get { return _observer }
        set {
            if let observer = observer {
                queue.remove(observer)
            }
            if let observer = newValue {
                queue.add(observer)
            }
            _observer = newValue
        }
    }
    
    init(queue: SKPaymentQueue) {
        self.queue = queue
    }
}

private enum RxPaymentTransactionType {
    case add
    case restore
    case none
}

private class RxPaymentTransactionObserver: DelegateProxy<RxPaymentTransactionObserverManager, SKPaymentTransactionObserver>, DelegateProxyType, SKPaymentTransactionObserver {
    
    private let manager: RxPaymentTransactionObserverManager
    private var currentTransactionType = BehaviorRelay<RxPaymentTransactionType>(value: .none)
    
    private static var shared = [SKPaymentQueue: RxPaymentTransactionObserver]()
    
    static func proxy(for queue: SKPaymentQueue) -> RxPaymentTransactionObserver {
        guard let proxy = shared[queue] else {
            let proxy = RxPaymentTransactionObserver(queue: queue)
            shared[queue] = proxy
            return self.proxy(for: proxy.manager)
        }
        return proxy
    }
    
    private convenience init(queue: SKPaymentQueue) {
        self.init(manager: RxPaymentTransactionObserverManager(queue: queue))
    }
    
    private init(manager: RxPaymentTransactionObserverManager) {
        self.manager = manager
        super.init(parentObject: manager, delegateProxy: RxPaymentTransactionObserver.self)
    }
    
    static func registerKnownImplementations() {
        self.register(make: { (manager: RxPaymentTransactionObserverManager) in self.proxy(for: manager.queue) })
    }
    
    static func currentDelegate(for object: RxPaymentTransactionObserverManager) -> SKPaymentTransactionObserver? {
        return object.observer
    }
    
    static func setCurrentDelegate(_ delegate: SKPaymentTransactionObserver?, to object: RxPaymentTransactionObserverManager) {
        object.observer = delegate
    }
    
    // MARK: Transactions
    let updatedTransactions = PublishRelay<[SKPaymentTransaction]>()
    private var restoredTransactions = [SKPaymentTransaction]()
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        let transactions = transactions.filter { $0.shouldFinish }
        self.restoredTransactions.append(contentsOf: transactions.filter { $0.isValid })
        updatedTransactions.accept(transactions)
    }
    
    let removedTransactions = PublishRelay<[SKPaymentTransaction]>()
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        removedTransactions.accept(transactions)
    }
    
    // MARK: Restore
    let restoreCompletedTransactionsFinished = PublishRelay<Result<Void>>()
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        restoreCompletedTransactionsFinished.accept(.success(()))
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        restoreCompletedTransactionsFinished.accept(.failure(error))
    }
    
    // MARK: Downloads
    let updatedDownloads = PublishRelay<[SKDownload]>()
    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        updatedDownloads.accept(downloads)
    }
    
    func download(_ transaction: SKPaymentTransaction) -> Observable<[DownloadProgressObservable]> {
        guard !transaction.downloads.isEmpty else {
            return .just([])
        }
        return Observable.combineLatest(transaction.downloads.map { self.download($0) })
    }
    
    func download(_ download: SKDownload) -> Observable<DownloadProgressObservable> {
        let progress = Observable<SKDownload>.create { observer in
            let observable = self.updatedDownloads
                .map { $0.first(where: { $0 == download }) }
                .unwrap()
                .share()
            return observable.takeUntil(observable.skipWhile { !$0.isEnded })
                .map { download -> SKDownload in
                    if let error = download.error {
                        throw error
                    }
                    return download
                }.bind(to: observer)
        }
        return Observable.just(download).map { DownloadProgressObservable($0, progress) }
    }
    
    // MARK: Transactions
    private func updateCurrentTransaction(to type: RxPaymentTransactionType, _ update: (()->Void)? = nil) {
        guard currentTransactionType.value == .none || type == .none else {
            fatalError()
        }
        currentTransactionType.accept(type)
        update?()
    }
    
    private func action<T: ObservableType>(on observable: Observable<[SKPaymentTransaction]>,
                                           limit: Int = 1,
                                           start: (()->Void)? = nil,
                                           end: (()->Void)? = nil,
                                           _ actionObservable: @escaping (SKPaymentTransaction)->T) -> Observable<[SKPaymentTransaction]> {
        return (limit > 0 ? observable.take(limit) : observable)
            .flatMapLatest { transactions -> Observable<[SKPaymentTransaction]> in
                guard !transactions.isEmpty else {
                    return .just([])
                }
                let observables = transactions.map { transaction -> Observable<SKPaymentTransaction> in
                    return actionObservable(transaction)
                        .map { _ in transaction }
                        .take(1)
                        .do(onNext: { transaction in
                            self.manager.queue.finishTransaction(transaction)
                        })
                }
                return Observable.combineLatest(observables)
            }.do(onSubscribed: {
                start?()
            }, onDispose: {
                end?()
            })
    }
    
    func add<T: ObservableType>(_ payment: SKPayment, _ purchasedAction: @escaping (SKPaymentTransaction)->T) -> Observable<SKPaymentTransaction> {
        return Observable.create { observer in
            let observable = self.updatedTransactions.map { $0.first(where: { $0.payment == payment }) }
                .unwrap()
                .map { transaction -> [SKPaymentTransaction] in
                    if let error = transaction.error {
                        throw error
                    }
                    return [transaction]
                }
                
            return self.action(on: observable,
                               start: {
                                self.updateCurrentTransaction(to: .add) {
                                    self.manager.queue.add(payment)
                                }
            },
                               end: { self.updateCurrentTransaction(to: .none) },
                               purchasedAction)
                .map { $0[0] }
                .bind(to: observer)
        }
    }
    
    func restoreCompletedTransactions<T: ObservableType>(withApplicationUsername applicationUsername: String? = nil, _ restoreAction: @escaping (SKPaymentTransaction)->T) -> Observable<[SKPaymentTransaction]> {
        return Observable.create { observer in
            return self.action(on: self.restoreCompletedTransactionsFinished.dematerializeResult()
                .map { _ in self.restoredTransactions },
                               start: {
                                self.updateCurrentTransaction(to: .restore) {
                                    self.restoredTransactions.removeAll()
                                    self.manager.queue.restoreCompletedTransactions(withApplicationUsername: applicationUsername)
                                }
            },
                               end: { self.updateCurrentTransaction(to: .none) },
                               restoreAction)
                .bind(to: observer)
        }
    }
    
    private var completeTransactionsDisposable: Disposable?
    func completeTransactions<T: ObservableType>(_ completeAction: @escaping (SKPaymentTransaction)->T) {
        guard completeTransactionsDisposable == nil else {
            fatalError()
        }
        completeTransactionsDisposable = self.action(on: self.updatedTransactions.filter { _ in self.currentTransactionType.value == .none }, limit: 0) { transaction -> Observable<SKPaymentTransaction> in
            guard transaction.isValid else { // autocomplete invalid transactions
                return .just(transaction)
            }
            return completeAction(transaction).map { _ in transaction }
            }
            .materialize()
            .publish()
            .connect()
    }
}

extension Reactive where Base: SKPaymentQueue {
    
    private var delegate: RxPaymentTransactionObserver {
        return RxPaymentTransactionObserver.proxy(for: self.base)
    }
    
    public func add<T: ObservableType>(_ payment: SKPayment, _ purchasedAction: @escaping (SKPaymentTransaction)->T) -> Observable<SKPaymentTransaction> {
        return delegate.add(payment, purchasedAction)
    }
    
    public func add(_ payment: SKPayment) -> Observable<SKPaymentTransaction> {
        return self.add(payment) { Observable.just($0) }
    }
    
    public func restoreCompletedTransactions<T: ObservableType>(withApplicationUsername applicationUsername: String? = nil, _ restoreAction: @escaping (SKPaymentTransaction)->T) -> Observable<[SKPaymentTransaction]> {
        return delegate.restoreCompletedTransactions(withApplicationUsername: applicationUsername, restoreAction)
    }
    
    public func restoreCompletedTransactions(withApplicationUsername applicationUsername: String? = nil) -> Observable<[SKPaymentTransaction]> {
        return self.restoreCompletedTransactions(withApplicationUsername: applicationUsername) { Observable.just($0) }
    }
    
    public func completeTransactions<T: ObservableType>(_ completeAction: @escaping (SKPaymentTransaction)->T) {
        delegate.completeTransactions(completeAction)
    }
    
    public func completeTransactions() {
        delegate.completeTransactions { Observable.just($0) }
    }
}
