import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MaterialApp(home: GoongRoutingMap()));
}

class GoongRoutingMap extends StatefulWidget {
  const GoongRoutingMap({super.key});

  @override
  State<GoongRoutingMap> createState() => _GoongRoutingMapState();
}

class _GoongRoutingMapState extends State<GoongRoutingMap> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointManager;
  mapbox.PolylineAnnotationManager? _polylineManager;

  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();

  final String? _goongMapKey = dotenv.env["GOONG_MAP_KEY"];
  final String? _goongApiKey = dotenv.env["GOONG_API_KEY"];

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(dotenv.env["ASSCESS_TOKEN"]!);
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
  }

  /// 🗺️ Geocode địa chỉ -> toạ độ
  Future<Map<String, double>?> _geocode(String address) async {
    final url = Uri.parse(
        "https://rsapi.goong.io/Geocode?address=$address&api_key=$_goongApiKey");
    final res = await http.get(url);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data["results"] == null || data["results"].isEmpty) return null;

    final loc = data["results"][0]["geometry"]["location"];
    return {"lat": loc["lat"], "lng": loc["lng"]};
  }

  /// 🔄 Reverse geocode (tọa độ -> địa chỉ)
  Future<String?> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
        "https://rsapi.goong.io/Geocode?latlng=$lat,$lng&api_key=$_goongApiKey");
    final res = await http.get(url);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data["results"] == null || data["results"].isEmpty) return null;

    return data["results"][0]["formatted_address"];
  }

  /// 🚗 Vẽ tuyến đường từ A -> B
  Future<void> _drawRoute(String start, String end) async {
    if (_mapboxMap == null) return;

    final from = await _geocode(start);
    final to = await _geocode(end);
    if (from == null || to == null) {
      _showSnack("Không tìm thấy địa chỉ");
      return;
    }

    final url = Uri.parse(
        "https://rsapi.goong.io/Direction?origin=${from["lat"]},${from["lng"]}&destination=${to["lat"]},${to["lng"]}&vehicle=car&api_key=$_goongApiKey");
    final res = await http.get(url);
    if (res.statusCode != 200) {
      _showSnack("Không lấy được tuyến đường");
      return;
    }

    final data = jsonDecode(res.body);
    if (data["routes"] == null || data["routes"].isEmpty) {
      _showSnack("Không tìm thấy tuyến đường");
      return;
    }

    final encoded = data["routes"][0]["overview_polyline"]["points"];
    final routePoints = PolylinePoints.decodePolyline(encoded);
    final coords = routePoints
        .map((p) => mapbox.Position(p.longitude, p.latitude))
        .toList();

    // Xoá cũ
    await _polylineManager?.deleteAll();
    await _pointManager?.deleteAll();

    // Vẽ line
    await _polylineManager?.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(coordinates: coords),
        lineColor: Colors.blue.value,
        lineWidth: 5.0,
      ),
    );

    // Thêm marker Start - End
    await _pointManager?.create(mapbox.PointAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(from["lng"]!, from["lat"]!),
      ),
      textField: "Start",
      textSize: 14,
    ));
    await _pointManager?.create(mapbox.PointAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(to["lng"]!, to["lat"]!),
      ),
      textField: "End",
      textSize: 14,
    ));

    // Focus camera
    await _mapboxMap?.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
              (from["lng"]! + to["lng"]!) / 2, (from["lat"]! + to["lat"]!) / 2),
        ),
        zoom: 12,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  /// 📍 Định vị người dùng + điền vào ô “Địa chỉ bắt đầu”
  Future<void> _locateMe() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra dịch vụ
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack("Vui lòng bật GPS");
      return;
    }

    // Kiểm tra quyền
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack("Bạn đã từ chối quyền vị trí");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnack("Quyền vị trí bị chặn vĩnh viễn");
      return;
    }

    // Lấy vị trí hiện tại
    final pos = await Geolocator.getCurrentPosition();

    // 🔄 Lấy địa chỉ từ tọa độ
    final address = await _reverseGeocode(pos.latitude, pos.longitude);
    if (address != null) {
      setState(() {
        _startCtrl.text = address;
      });
    }

    // Thêm marker
    await _pointManager?.deleteAll();
    await _pointManager?.create(mapbox.PointAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(pos.longitude, pos.latitude),
      ),
      textField: "Vị trí của bạn",
      textSize: 14,
    ));

    // Di chuyển camera
    await _mapboxMap?.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(pos.longitude, pos.latitude),
        ),
        zoom: 15,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Goong Map Routing + Định vị tự động"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _locateMe,
            tooltip: "Định vị tôi",
          ),
        ],
      ),
      body: Column(
        children: [
          // ô nhập địa chỉ
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _startCtrl,
                  decoration: const InputDecoration(
                    labelText: "Địa chỉ bắt đầu",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _endCtrl,
                  decoration: const InputDecoration(
                    labelText: "Địa chỉ kết thúc",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route),
                  label: const Text("Vẽ tuyến đường"),
                  onPressed: () =>
                      _drawRoute(_startCtrl.text.trim(), _endCtrl.text.trim()),
                ),
              ],
            ),
          ),
          // bản đồ
          Expanded(
            child: mapbox.MapWidget(
              key: const ValueKey("mapWidget"),
              styleUri:
                  "https://tiles.goong.io/assets/goong_map_web.json?api_key=$_goongMapKey",
              onMapCreated: _onMapCreated,
              cameraOptions: mapbox.CameraOptions(
                center: mapbox.Point(
                  coordinates: mapbox.Position(106.700981, 10.776889),
                ),
                zoom: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
