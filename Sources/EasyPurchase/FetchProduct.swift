//
//  FetchProduct.swift
//  EasyPurchase
//
//  Created by Sadat Ahmed on 19.09.2023.
//

import Foundation
import StoreKit

/// A protocol defining the fundamental actions for managing in-app purchase requests, allowing them to be started and canceled.
public protocol InAppRequestActions: AnyObject {
    func start()
    func cancel()
}

extension SKProductsRequest: InAppRequestActions{  }

/// A protocol defining the requirements for an in-app product request, including actions to start and cancel the request, tracking completion status, and caching product information.
public protocol InAppProductRequest: InAppRequestActions {
    var isCompleted: Bool { get }
    var cachedProducts: InAppProduct? { get }
}

/// A class responsible for fetching in-app products from the Apple Store and managing the product request lifecycle.
class FetchProduct : NSObject, InAppProductRequest {
    var productCompletionHandler: ProductCompletionHandler?
    var refreshCompletionHandler: RefreshCompletionHandler?
    var productRequest: SKProductsRequest?
    var receiptRequest: SKReceiptRefreshRequest?
    var isCompleted: Bool = false
    var cachedProducts: InAppProduct?

    /// Initializes a FetchProduct instance with the specified product identifiers and a completion handler.
    /// - Parameters:
    ///   - productIds: A set of product identifiers for the requested in-app products.
    ///   - productComplitionHandler: A closure to be called when the product request is completed.
    init(productIds: Set<String>, productCompletionHandler: @escaping ProductCompletionHandler) {
        super.init()
        self.productCompletionHandler = productCompletionHandler
        productRequest = SKProductsRequest(productIdentifiers: productIds)
        productRequest?.delegate = self
    }
    
    /// Initializes a FetchProduct instance with a closure to handle the completion of an app receipt refresh request.
    /// - Parameters:
    ///   - refreshCompletionHandler: A closure to be called when the app receipt refresh request is completed.
    init(refreshCompletionHandler: @escaping RefreshCompletionHandler) {
        super.init()
        self.refreshCompletionHandler = refreshCompletionHandler
        receiptRequest = SKReceiptRefreshRequest()
        receiptRequest?.delegate = self
        receiptRequest?.start()
    }

    // Method to start the product request
    func start() {
        productRequest?.start()
    }

    // Method to cancel the product request
    func cancel() {
        productRequest?.cancel()
    }
}

extension FetchProduct: SKProductsRequestDelegate {
    /// Called when an SKProductsRequest receives a response containing product information.
    /// - Parameters:
    ///   - request: The SKProductsRequest that received the response.
    ///   - response: The SKProductsResponse containing product information.
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let retrievedProducts = response.products
        let invalidProductIDs = response.invalidProductIdentifiers

        let products = InAppProduct(retrievedProducts: Set(retrievedProducts), invalidProductIDs: Set(invalidProductIDs), error: nil)
        cachedProducts = products
        isCompleted = true
        productCompletionHandler?(products)
        productRequest = nil
    }
    
    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            guard let handler = refreshCompletionHandler else {
                return
            }
            handler(RefreshReceiptStatus(error: nil))
            refreshCompletionHandler = nil
            receiptRequest?.cancel()
        }
    }

    /// Called when an SKRequest encounters an error during execution.
    /// - Parameters:
    ///   - request: The SKRequest that encountered an error.
    ///   - error: The error that occurred during the request.
    func request(_ request: SKRequest, didFailWithError error: Error) {
        // Check if the request is a refresh request for the app receipt.
        if request is SKReceiptRefreshRequest {
            // Ensure that a refresh completion handler is available.
            guard let handler = refreshCompletionHandler else {
                return
            }
            // Call the refresh completion handler with a RefreshReceiptStatus indicating a refresh failure.
            handler(RefreshReceiptStatus(error: .RefreshFailed))
            // Reset the refresh completion handler to avoid multiple invocations.
            refreshCompletionHandler = nil
            receiptRequest?.cancel()
            return
        }
        let products = InAppProduct(retrievedProducts: nil, invalidProductIDs: nil, error: error)
        cachedProducts = products
        isCompleted = true
        productCompletionHandler?(products)
        productRequest = nil
    }
}
