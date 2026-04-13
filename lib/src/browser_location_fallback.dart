class BrowserLocationResult {
  const BrowserLocationResult({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

Future<BrowserLocationResult> getBrowserCurrentLocation() {
  throw UnsupportedError(
    'La geolocalisation navigateur n est disponible que sur Flutter Web.',
  );
}
