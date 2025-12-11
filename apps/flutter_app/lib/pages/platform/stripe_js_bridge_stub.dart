// lib/platform/stripe_js_bridge_stub.dart
// للمنصّات غير الويب (Android, iOS, Windows...)

Future<String> openStripeCardFormImpl(String clientSecret) async {
  throw UnsupportedError('Stripe JS bridge is only available on Web.');
}
