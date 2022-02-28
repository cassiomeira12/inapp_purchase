import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

import 'inapp_purchase_service_interface.dart';

class InAppPurchaseService implements InAppPurchaseServiceInterface {
  InAppPurchase get _inAppPurchase => InAppPurchase.instance;

  InAppPurchaseService({this.hasSubscribe}) {
    _init();
  }

  @override
  ValueChanged<bool>? hasSubscribe;

  @override
  ValueChanged<PurchaseDetails>? onSucessful;

  @override
  ValueChanged<PurchaseDetails>? onError;

  @override
  List<PurchaseDetails> purchases = [];

  void _init() async {
    var status = await _inAppPurchase.isAvailable();
    debugPrint('InAppPurchaseService Status -> $status');
    if (status) {
      _inAppPurchase.purchaseStream.listen((purchaseList) async {
        if (purchaseList.isEmpty) hasSubscribe?.call(false);
        for (var purchaseDetails in purchaseList) {
          if (purchaseDetails is AppStorePurchaseDetails) {
            SKPaymentTransactionWrapper skProduct =
                (purchaseDetails as AppStorePurchaseDetails)
                    .skPaymentTransaction;
            print(skProduct.transactionState);
          }

          switch (purchaseDetails.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.purchased:
              purchases.add(purchaseDetails);
              hasSubscribe?.call(true);
              onSucessful?.call(purchaseDetails);
              onSucessful = null;
              onError = null;
              break;
            case PurchaseStatus.error:
              debugPrint(purchaseDetails.error!.message.toString());
              onError?.call(purchaseDetails);
              onSucessful = null;
              onError = null;
              break;
            case PurchaseStatus.restored:
              purchases.add(purchaseDetails);
              hasSubscribe?.call(true);
              onSucessful?.call(purchaseDetails);
              onSucessful = null;
              onError = null;
              break;
            case PurchaseStatus.canceled:
              onError?.call(purchaseDetails);
              onSucessful = null;
              onError = null;
              break;
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchaseDetails);
          }
        }
      }, onError: (error) {
        debugPrint(error);
      });
    }
  }

  @override
  Future<void> subscribe(
    String plan, {
    required String userUniqueID,
    ValueChanged<PurchaseDetails>? onSucessful,
    ValueChanged<PurchaseDetails>? onError,
  }) async {
    if (await _inAppPurchase.isAvailable()) {
      if (Platform.isIOS) {
        final paymentWrapper = SKPaymentQueueWrapper();
        final transactions = await paymentWrapper.transactions();
        for (var skPaymentTransactionWrapper in transactions) {
          SKPaymentQueueWrapper()
              .finishTransaction(skPaymentTransactionWrapper);
        }
        //await Future.wait(transactions.map(
        //    (transaction) => paymentWrapper.finishTransaction(transaction)));
      }
      final product = await getItem(plan);
      if (product == null) throw Exception('plan $plan not found');
      this.onSucessful = onSucessful;
      this.onError = onError;
      await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: userUniqueID,
        ),
      );
    }
  }

  @override
  Future<void> unsubscribe({String? plan}) async {
    if (Platform.isAndroid) {
      if (plan == null) throw Exception('Expected plan id');
      var packageInfo = await PackageInfo.fromPlatform();
      String package = packageInfo.packageName;
      var link =
          'https://play.google.com/store/account/subscriptions?sku=$plan&package=$package';
      if (await canLaunch(link)) {
        launch(link);
      } else {
        throw Exception();
      }
    }
    if (Platform.isIOS) {
      var link = 'https://apps.apple.com/account/subscriptions';
      if (await canLaunch(link)) {
        launch(link);
      } else {
        throw Exception();
      }
    }
  }

  @override
  Future<void> buyProduct(
    String id, {
    required String userUniqueID,
    ValueChanged<PurchaseDetails>? onSucessful,
    ValueChanged<PurchaseDetails>? onError,
  }) async {
    if (await _inAppPurchase.isAvailable()) {
      final product = await getItem(id);
      if (product == null) throw Exception('Product $id not found');
      this.onSucessful = onSucessful;
      this.onError = onError;
      await _inAppPurchase.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: userUniqueID,
        ),
      );
    }
  }

  @override
  Future<void> restoreSubscribe(String userUniqueID) {
    return _inAppPurchase.restorePurchases(
      applicationUserName: userUniqueID,
    );
  }

  @override
  Future<void> downgradeSubscribe() {
    // TODO: implement downgradeSubscribe
    throw UnimplementedError();
  }

  @override
  Future<void> upgradeSubscribe() async {
    if (Platform.isAndroid) {
      // final product = await getItem('374ec79f07as15d');

      /* final PurchaseDetails oldPurchaseDetails = null;

      PurchaseParam purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        changeSubscriptionParam: ChangeSubscriptionParam(
          oldPurchaseDetails:
              GooglePlayPurchaseDetails.fromPurchase(_purchases.first),
          prorationMode: ProrationMode.immediateWithTimeProration,
        ),
      );
      InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam); */

      /* final androidAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      var priceChangeConfirmationResult = await androidAddition
          .launchPriceChangeConfirmationFlow(sku: '374ec79f07as15d');
      if (priceChangeConfirmationResult.responseCode == BillingResponse.ok) {
        // TODO acknowledge price change
      } else {
        // TODO show error
      } */
    }
  }

  @override
  Future<bool> validate(PurchaseDetails purchase) async {
    if (Platform.isAndroid) {
      return validateAndroid(purchase);
    } else if (Platform.isIOS) {
      return validateIOS(purchase);
    }
    return false;
  }

  @override
  Future<bool> validateAndroid(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
    return purchase.status == PurchaseStatus.purchased;
  }

  @override
  Future<bool> validateIOS(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
    return purchase.status == PurchaseStatus.purchased;
  }

  @override
  Future<ProductDetails?> getItem(String id) async {
    final result = await _inAppPurchase.queryProductDetails({id});
    if (result.notFoundIDs.isNotEmpty) return null;
    var map = {
      'id': result.productDetails.first.id,
      'title': result.productDetails.first.title,
      'description': result.productDetails.first.description,
      'price': result.productDetails.first.price,
      'rawPrice': result.productDetails.first.rawPrice,
      'currencyCode': result.productDetails.first.currencyCode,
      'currencySymbol': result.productDetails.first.currencySymbol,
    };
    debugPrint(map.toString());
    return result.productDetails.first;
  }

  @override
  Future<List<ProductDetails>> getProducts(List<String> ids) async {
    if (await _inAppPurchase.isAvailable()) {
      final result = await _inAppPurchase.queryProductDetails(ids.toSet());
      return result.productDetails;
    }
    return [];
  }
}
