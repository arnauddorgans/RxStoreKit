//
//  SKPaymentTransactionState+Helpers.swift
//  RxStoreKit
//
//  Created by Arnaud Dorgans on 26/04/2018.
//

import UIKit
import StoreKit

extension SKPaymentTransaction {
    
    var shouldFinish: Bool {
        switch self.transactionState {
        case .restored, .purchased, .failed:
            return true
        default:
            return false
        }
    }
    
    var isValid: Bool {
        switch self.transactionState {
        case .restored, .purchased:
            return true
        default:
            return false
        }
    }
}
