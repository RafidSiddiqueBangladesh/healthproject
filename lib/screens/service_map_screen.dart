import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/liquid_glass.dart';

enum ServiceMapType { hospital, ambulance, medicineShop }

class ServiceMapScreen extends StatefulWidget {
  const ServiceMapScreen({
    super.key,
    required this.type,
  });

  final ServiceMapType type;

  @override
  State<ServiceMapScreen> createState() => _ServiceMapScreenState();
}

class _ServiceMapScreenState extends State<ServiceMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Position? _position;
  bool _isLoading = true;
  String? _error;
  String _query = '';

  static const List<_PointItem> _hospitals = [
    _PointItem('h1', 'City Care Hospital', '12 Main Road', '+8801711111111', 23.7890, 90.4010),
    _PointItem('h2', 'Green Life Medical', '22 Lake Avenue', '+8801722222222', 23.7801, 90.4153),
    _PointItem('h3', 'Evercare Mock Center', '88 Health Street', '+8801733333333', 23.8046, 90.4219),
    _PointItem('h4', 'Northern Health Hospital', '4 River View', '+8801733300001', 23.7760, 90.4075),
    _PointItem('h5', 'People Care Hospital', '17 Sunrise Ave', '+8801733300002', 23.7941, 90.3964),
    _PointItem('h6', 'Central Medical Hub', '54 Link Road', '+8801733300003', 23.8032, 90.4130),
    _PointItem('h7', 'Apollo Mock Point', '101 Metro Lane', '+8801733300004', 23.7688, 90.4177),
    _PointItem('h8', 'Community Care Hospital', '8 Park Side', '+8801733300005', 23.8103, 90.4022),
    _PointItem('h9', 'Prime Health Clinic', '31 New Circular', '+8801733300006', 23.7843, 90.4240),
    _PointItem('h10', 'Metro Hospital Unit', '63 Healing Street', '+8801733300007', 23.7997, 90.3903),
  ];

  static const List<_PointItem> _ambulances = [
    _PointItem('a1', 'Rapid Ambulance Unit', 'Emergency Hub 1', '+8801777777777', 23.7922, 90.3920),
    _PointItem('a2', 'LifeLine Ambulance', 'Emergency Hub 2', '+8801788888888', 23.7704, 90.4258),
    _PointItem('a3', '24x7 Rescue Ambulance', 'Emergency Hub 3', '+8801799999999', 23.8001, 90.4051),
    _PointItem('a4', 'City Emergency Van', 'Responder Point A', '+8801788700001', 23.7813, 90.4104),
    _PointItem('a5', 'FastCare Ambulance', 'Responder Point B', '+8801788700002', 23.8078, 90.3982),
    _PointItem('a6', 'Green Cross Ambulance', 'Responder Point C', '+8801788700003', 23.7759, 90.4202),
    _PointItem('a7', 'MediRescue Unit', 'Responder Point D', '+8801788700004', 23.8115, 90.4160),
    _PointItem('a8', 'Pulse Ambulance', 'Responder Point E', '+8801788700005', 23.7851, 90.3941),
    _PointItem('a9', 'SafeRide Ambulance', 'Responder Point F', '+8801788700006', 23.7973, 90.4274),
    _PointItem('a10', 'Rapid Aid Ambulance', 'Responder Point G', '+8801788700007', 23.7665, 90.4048),
  ];

  static const List<_PointItem> _medicineShops = [
    _PointItem('m1', 'MediPlus Pharmacy', '5 Central Point', '+8801744444444', 23.7861, 90.4084),
    _PointItem('m2', 'Care Drug House', '9 Clinic Lane', '+8801755555555', 23.7758, 90.3989),
    _PointItem('m3', 'Health First Medicine', '33 Relief Road', '+8801766666666', 23.8122, 90.4101),
    _PointItem('m4', 'City Pharmacy', '71 Main Junction', '+8801766600001', 23.8039, 90.3976),
    _PointItem('m5', 'Trust Medicine Corner', '16 Wellness Rd', '+8801766600002', 23.7723, 90.4144),
    _PointItem('m6', 'Well Drug Store', '90 Central Blvd', '+8801766600003', 23.7928, 90.4225),
    _PointItem('m7', 'Life Care Pharmacy', '2 East Avenue', '+8801766600004', 23.7800, 90.3928),
    _PointItem('m8', 'Prime Drug House', '45 Metro Link', '+8801766600005', 23.8081, 90.4068),
    _PointItem('m9', 'Good Health Medics', '53 Green Street', '+8801766600006', 23.7681, 90.4209),
    _PointItem('m10', 'QuickMeds', '14 Park Plaza', '+8801766600007', 23.7988, 90.4015),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    _loadLocationAndFocusNearest();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PointItem> get _allItems {
    switch (widget.type) {
      case ServiceMapType.hospital:
        return _hospitals;
      case ServiceMapType.ambulance:
        return _ambulances;
      case ServiceMapType.medicineShop:
        return _medicineShops;
    }
  }

  List<_PointItem> get _filteredItems {
    if (_query.isEmpty) {
      return _allItems;
    }
    return _allItems.where((item) {
      final haystack = '${item.name} ${item.address}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  Future<void> _loadLocationAndFocusNearest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _error = 'Location service is disabled. Showing map with mock points.';
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied. Showing map with mock points.';
          _isLoading = false;
        });
        return;
      }

      const settings = LocationSettings(accuracy: LocationAccuracy.high);
      final current = await Geolocator.getCurrentPosition(locationSettings: settings);
      final nearest = _nearestFrom(current, _allItems);

      setState(() {
        _position = current;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(nearest.lat, nearest.lng), 15.6);
      });
    } catch (_) {
      setState(() {
        _error = 'Could not get location right now. Showing map with mock points.';
        _isLoading = false;
      });
    }
  }

  _PointItem _nearestFrom(Position pos, List<_PointItem> items) {
    _PointItem nearest = items.first;
    double best = Geolocator.distanceBetween(pos.latitude, pos.longitude, nearest.lat, nearest.lng);
    for (final item in items.skip(1)) {
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, item.lat, item.lng);
      if (d < best) {
        best = d;
        nearest = item;
      }
    }
    return nearest;
  }

  LatLng _initialCenter() {
    if (_position != null) {
      return LatLng(_position!.latitude, _position!.longitude);
    }
    final first = _allItems.first;
    return LatLng(first.lat, first.lng);
  }

  String get _screenTitle {
    switch (widget.type) {
      case ServiceMapType.hospital:
        return 'Nearest Hospital Map';
      case ServiceMapType.ambulance:
        return 'Nearest Ambulance Map';
      case ServiceMapType.medicineShop:
        return 'Nearest Medicine Shop Map';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case ServiceMapType.hospital:
        return Icons.local_hospital;
      case ServiceMapType.ambulance:
        return Icons.emergency;
      case ServiceMapType.medicineShop:
        return Icons.local_pharmacy;
    }
  }

  Color get _typeColor {
    switch (widget.type) {
      case ServiceMapType.hospital:
        return const Color(0xFFFF8A80);
      case ServiceMapType.ambulance:
        return const Color(0xFFFFCC80);
      case ServiceMapType.medicineShop:
        return const Color(0xFFA5D6A7);
    }
  }

  Future<void> _openInMaps(_PointItem item) async {
    final label = Uri.encodeComponent(item.name);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${item.lat},${item.lng}($label)');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPoint(_PointItem item) async {
    final uri = Uri.parse('tel:${item.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite(_PointItem item) async {
    final url = _websiteFor(item);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _websiteFor(_PointItem item) {
    final slug = item.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'https://$slug.mock-health.com';
  }

  int _doctorCountFor(_PointItem item) {
    final base = switch (widget.type) {
      ServiceMapType.hospital => 80,
      ServiceMapType.ambulance => 18,
      ServiceMapType.medicineShop => 12,
    };
    return base + (item.id.codeUnitAt(0) % 11) + (item.id.codeUnitAt(item.id.length - 1) % 7);
  }

  void _showItemDetails(_PointItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LiquidGlassCard(
              tint: const Color(0xFFE6DCFF),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: _typeColor, shape: BoxShape.circle),
                        child: Icon(_typeIcon, color: Colors.black87, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow('Phone', item.phone),
                  _detailRow('Website', _websiteFor(item)),
                  _detailRow('Total Doctors', _doctorCountFor(item).toString()),
                  _detailRow('Location', '${item.lat.toStringAsFixed(5)}, ${item.lng.toStringAsFixed(5)}'),
                  _detailRow('Address', item.address),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _callPoint(item),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openWebsite(item),
                        icon: const Icon(Icons.language),
                        label: const Text('Website'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openInMaps(item),
                        icon: const Icon(Icons.map),
                        label: const Text('Open Map'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 13),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(_screenTitle)),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    LiquidGlassCard(
                      tint: const Color(0xFFDDF0FF),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(_typeIcon, color: _typeColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Free map with ${_allItems.length} mock points. Search and focus in map.',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search by name or address',
                              hintStyle: const TextStyle(color: Color(0xCCFFFFFF)),
                              filled: true,
                              fillColor: const Color(0x22FFFFFF),
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: Color(0xFFFFE0E0))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _initialCenter(),
                            initialZoom: 13.8,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'nutricare.app',
                            ),
                            MarkerLayer(markers: _buildMarkers()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LiquidGlassCard(
                        tint: const Color(0xFFE7DEFF),
                        child: _filteredItems.isEmpty
                            ? const Center(
                                child: Text('No result for this search.', style: TextStyle(color: Colors.white)),
                              )
                            : ListView.separated(
                                itemCount: _filteredItems.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  return InkWell(
                                    onTap: () {
                                      _mapController.move(LatLng(item.lat, item.lng), 16);
                                      _showItemDetails(item);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0x26FFFFFF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(color: _typeColor, shape: BoxShape.circle),
                                            child: Icon(_typeIcon, color: Colors.black87, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                const SizedBox(height: 2),
                                                Text(item.address, style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _openInMaps(item),
                                            icon: const Icon(Icons.map, color: Colors.white),
                                          ),
                                          IconButton(
                                            onPressed: () => _callPoint(item),
                                            icon: const Icon(Icons.call, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_position != null) {
      markers.add(
        Marker(
          point: LatLng(_position!.latitude, _position!.longitude),
          width: 44,
          height: 44,
          child: _marker(Icons.my_location, const Color(0xFF80DEEA)),
        ),
      );
    }

    for (final item in _filteredItems) {
      markers.add(
        Marker(
          point: LatLng(item.lat, item.lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () {
              _mapController.move(LatLng(item.lat, item.lng), 16);
              _showItemDetails(item);
            },
            child: _marker(_typeIcon, _typeColor),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _marker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
    );
  }
}

class _PointItem {
  const _PointItem(this.id, this.name, this.address, this.phone, this.lat, this.lng);

  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
}
