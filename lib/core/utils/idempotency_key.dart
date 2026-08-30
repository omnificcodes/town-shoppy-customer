import 'dart:math';

/// A random 32-character hex key for the `Idempotency-Key` header
/// `POST /redemptions` requires. No `uuid` package dependency needed for
/// this — `Random.secure()` is already part of `dart:math`.
String generateIdempotencyKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
