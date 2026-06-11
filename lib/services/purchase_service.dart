import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';

// ID du produit à créer dans Google Play Console
const _kRemoveAdsId = 'remove_ads';
const _kPrefKey = 'ads_removed';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _adsRemoved = false;
  bool _storeAvailable = false;
  ProductDetails? _product;
  bool _loading = false;
  String? _error;

  bool get adsRemoved => _adsRemoved;
  bool get storeAvailable => _storeAvailable;
  ProductDetails? get product => _product;
  bool get loading => _loading;
  String? get error => _error;

  String get priceLabel {
    if (_product != null) return _product!.price;
    return '0,99 €';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_kPrefKey) ?? false;

    if (_adsRemoved) {
      notifyListeners();
      return;
    }

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});

    final response = await _iap.queryProductDetails({_kRemoveAdsId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }

    notifyListeners();
  }

  Future<void> purchase() async {
    if (_product == null || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: _product!);
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _loading = true;
    notifyListeners();
    await _iap.restorePurchases();
    _loading = false;
    notifyListeners();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != _kRemoveAdsId) continue;

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _markAdsRemoved();
        await _iap.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        _error = p.error?.message;
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _markAdsRemoved() async {
    _adsRemoved = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, true);
    AdService.instance.disposeAds();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
