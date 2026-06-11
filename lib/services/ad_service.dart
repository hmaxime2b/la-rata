import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const _interstitialAdUnitId = 'ca-app-pub-1786577323206502/1465620325';

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  static const bannerAdUnitId = 'ca-app-pub-1786577323206502/6717947000';

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
        },
        onAdFailedToLoad: (_) {
          _interstitialReady = false;
        },
      ),
    );
  }

  void showInterstitial({VoidCallback? onComplete}) {
    if (!_interstitialReady || _interstitialAd == null) {
      onComplete?.call();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialReady = false;
        _loadInterstitial();
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialReady = false;
        _loadInterstitial();
        onComplete?.call();
      },
    );
    _interstitialAd!.show();
  }

  void disposeAds() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialReady = false;
  }
}
