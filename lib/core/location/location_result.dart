/// Outcome of a device-location request, distinguishing the handful of ways
/// it can fail so the UI can offer the right recovery action for each (retry
/// the prompt vs. open the OS location settings vs. open the app's own
/// permission settings) instead of a single generic "couldn't get location"
/// message.
sealed class LocationResult {
  const LocationResult();
}

class LocationAvailable extends LocationResult {
  const LocationAvailable(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// The device's location services (GPS) are off system-wide — not specific
/// to this app, so the recovery action is the OS location settings screen.
class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

/// Permission was denied but can still be asked for again (the OS-standard
/// "Ask again" state) — retrying the request re-prompts the user.
class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied();
}

/// Permission was permanently denied ("Don't ask again" / iOS's equivalent)
/// — the OS will no longer show a prompt, so the only recovery is this
/// app's own settings page.
class LocationPermissionDeniedForever extends LocationResult {
  const LocationPermissionDeniedForever();
}
