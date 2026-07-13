import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiReading {
  final String? ssid;
  final String? bssid;
  const WifiReading(this.ssid, this.bssid);

  bool get hasWifi => (bssid != null && bssid!.isNotEmpty) || (ssid != null && ssid!.isNotEmpty);
}

/// Reads the currently connected WiFi SSID + BSSID. Requires location
/// permission on Android to access the BSSID.
Future<WifiReading> readWifi() async {
  await Permission.locationWhenInUse.request();
  final info = NetworkInfo();
  var ssid = await info.getWifiName();
  final bssid = await info.getWifiBSSID();
  // Some platforms wrap the SSID in quotes.
  ssid = ssid?.replaceAll('"', '');
  return WifiReading(ssid, bssid);
}
