// lib/platform/stripe_js_bridge_web.dart
// هذا الملف يُستخدم فقط على الويب (يدعم dart:js)

import 'dart:js' as js;
import 'dart:js_util' as js_util;

Future<String> openStripeCardFormImpl(String clientSecret) {
  return js_util.promiseToFuture<String>(
    js.context.callMethod(
      "openStripeCardForm",
      [clientSecret],
    ),
  );
}
