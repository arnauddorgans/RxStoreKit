//
//  ObservableType+Helpers.swift
//  RxStoreKit
//
//  Created by Arnaud Dorgans on 26/04/2018.
//

import UIKit
import RxSwift
import Alamofire

extension ObservableType {
    
    func materializeResult() -> Observable<Result<E>> {
        return self.map { .success($0) }
            .catchError { Observable.just(.failure($0)) }
    }
    
    func dematerializeResult<T>() -> Observable<T> where E == Result<T> {
        return self.map { result in
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }
    
    func unwrap<T>() -> Observable<T> where E == T? {
        return self.filter { $0 != nil }.map { $0! }
    }
}
