//
//  SKDownload+Helpers.swift
//  RxStoreKit
//
//  Created by Arnaud Dorgans on 26/04/2018.
//

import UIKit
import StoreKit

extension SKDownload {
    
    var isEnded: Bool {
        switch self.downloadState {
        case .finished, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}
