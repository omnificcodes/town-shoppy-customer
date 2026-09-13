/// Which "face" of the app a signed-in account is currently using.
///
/// An account that owns (or staffs) a merchant can use the very same app as
/// either a shopper ([customer]) or a business operator ([business]). The
/// two modes share one session/token and one `/auth/me` account; they differ
/// only in which route tree and shell the router lets the user into -- see
/// `app_router.dart`'s `_redirect`, which is the single enforcement point.
enum AppMode {
  customer,
  business;

  static AppMode? tryParse(String? raw) => switch (raw) {
        'customer' => AppMode.customer,
        'business' => AppMode.business,
        _ => null,
      };
}
