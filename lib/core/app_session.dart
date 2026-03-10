class AppSession {
  AppSession._();

  static bool _isGuestMode = false;

  static bool get isGuestMode => _isGuestMode;

  static void enterGuestMode() {
    _isGuestMode = true;
  }

  static void clearGuestMode() {
    _isGuestMode = false;
  }
}
