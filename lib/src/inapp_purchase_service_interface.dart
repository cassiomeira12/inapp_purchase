import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract class InAppPurchaseServiceInterface {
  ValueChanged<bool>? hasSubscribe;

  ValueChanged<PurchaseDetails>? onSucessful;
  ValueChanged<PurchaseDetails>? onError;

  List<PurchaseDetails> purchases = [];

  InAppPurchaseServiceInterface();

  @protected
  Future<bool> validateAndroid(PurchaseDetails purchase);

  @protected
  Future<bool> validateIOS(PurchaseDetails purchase);

  Future<bool> validate(PurchaseDetails purchase);

  Future<ProductDetails?> getItem(String id);

  Future<void> buyProduct(
    String id, {
    required String userUniqueID,
    ValueChanged<PurchaseDetails>? onSucessful,
    ValueChanged<PurchaseDetails>? onError,
  });

  Future<void> subscribe(
    String plan, {
    required String userUniqueID,
    ValueChanged<PurchaseDetails>? onSucessful,
    ValueChanged<PurchaseDetails>? onError,
  });

  Future<void> unsubscribe({String? plan});

  Future<void> upgradeSubscribe();

  Future<void> downgradeSubscribe();

  Future<void> restoreSubscribe(String userUniqueID);

  Future<List<ProductDetails>> getProducts(List<String> ids);
}
