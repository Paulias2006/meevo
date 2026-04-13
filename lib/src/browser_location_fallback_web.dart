import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class BrowserLocationResult {
  const BrowserLocationResult({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

Future<BrowserLocationResult> getBrowserCurrentLocation() async {
  final completer = Completer<BrowserLocationResult>();

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition position) {
        completer.complete(
          BrowserLocationResult(
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          ),
        );
      }.toJS,
      (web.GeolocationPositionError error) {
        completer.completeError(Exception(_browserLocationErrorMessage(error)));
      }.toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 0,
      ),
    );
  } catch (_) {
    completer.completeError(
      Exception(
        'La geolocalisation du navigateur est indisponible. Rechargez completement la page puis reessayez.',
      ),
    );
  }

  return completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw Exception(
      'La localisation du navigateur a pris trop de temps. Verifiez votre GPS ou votre permission de localisation.',
    ),
  );
}

String _browserLocationErrorMessage(web.GeolocationPositionError error) {
  switch (error.code) {
    case 1:
      return 'Autorisez la localisation dans votre navigateur pour continuer.';
    case 2:
      return 'Position introuvable pour le moment. Essayez a nouveau dans une zone avec un meilleur signal.';
    case 3:
      return 'La demande de localisation a expire. Reessayez.';
    default:
      return error.message.isNotEmpty
          ? error.message
          : 'Impossible de recuperer votre position actuelle.';
  }
}
