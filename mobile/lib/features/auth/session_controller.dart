import 'package:flutter/foundation.dart';

class SessionController extends ChangeNotifier {
  bool _isGuest = false;
  int? _preferredTabIndex;

  bool get isGuest => _isGuest;
  int? get preferredTabIndex => _preferredTabIndex;

  void continueAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

  void clearGuest() {
    if (!_isGuest) return;
    _isGuest = false;
    notifyListeners();
  }

  void setPreferredTabIndex(int index) {
    _preferredTabIndex = index;
  }

  void clearPreferredTabIndex() {
    _preferredTabIndex = null;
  }
}

final sessionController = SessionController();
