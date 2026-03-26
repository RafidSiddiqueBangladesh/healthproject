import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bd_admin_mock_data.dart';
import '../widgets/beautified_tab_heading.dart';
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
  static const int _nearbyLimit = 12;

  static final List<_DistrictArea> _districtAreas = _buildDistrictAreas();
  static const int _pointsPerDistrict = 10;

  static List<_DistrictArea> _buildDistrictAreas() {
    final areas = <_DistrictArea>[];
    var index = 0;
    for (final division in bdDivisionsMockData) {
      for (final district in division.districts) {
        // Deterministic spread across Bangladesh bounding box for mock map points.
        final row = index ~/ 8;
        final col = index % 8;
        final lat = 20.95 + (row * 0.47) + ((col % 2) * 0.03);
        final lng = 88.15 + (col * 0.43) + ((row % 2) * 0.04);
        areas.add(
          _DistrictArea(
            id: 'd${index + 1}',
            division: division.name,
            district: district.name,
            lat: lat,
            lng: lng,
          ),
        );
        index++;
      }
    }
    return areas;
  }

  List<_PointItem> _itemsForType(ServiceMapType type) {
    final items = <_PointItem>[];
    for (final entry in _districtAreas.asMap().entries) {
      final i = entry.key;
      final area = entry.value;
      final district = area.district;
      final division = area.division;

      for (var unit = 1; unit <= _pointsPerDistrict; unit++) {
        final offsetLat = ((unit - 5) * 0.006) + ((i % 3) * 0.0012);
        final offsetLng = ((unit % 5) * 0.005) - 0.012 + ((i % 4) * 0.001);
        final suffix = '${i + 1}${unit.toString().padLeft(2, '0')}';

        switch (type) {
          case ServiceMapType.hospital:
            items.add(
              _PointItem(
                'h-${area.id}-$unit',
                '$district District Hospital $unit',
                'Unit $unit, $district Sadar, $division',
                '+880171$suffix',
                area.lat + offsetLat,
                area.lng + offsetLng,
                district,
                division,
                'Hospital',
              ),
            );
            break;
          case ServiceMapType.ambulance:
            items.add(
              _PointItem(
                'a-${area.id}-$unit',
                '$district Ambulance Service $unit',
                'Responder Unit $unit, $district, $division',
                '+880181$suffix',
                area.lat + offsetLat + 0.004,
                area.lng + offsetLng - 0.004,
                district,
                division,
                'Ambulance',
              ),
            );
            break;
          case ServiceMapType.medicineShop:
            items.add(
              _PointItem(
                'm-${area.id}-$unit',
                '$district Medical Shop $unit',
                'Market Unit $unit, $district, $division',
                '+880191$suffix',
                area.lat + offsetLat - 0.004,
                area.lng + offsetLng + 0.004,
                district,
                division,
                'Medicine Shop',
              ),
            );
            break;
        }
      }
    }
    return items;
  }

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
    return _itemsForType(widget.type);
  }

  List<_PointItem> get _filteredItems {
    if (_query.isEmpty) {
      return _allItems;
    }
    return _allItems.where((item) {
      final haystack = '${item.name} ${item.address} ${item.district} ${item.division}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  List<_PointItem> get _visibleItems {
    if (_position == null) {
      return _filteredItems;
    }
    return _nearestItemsFrom(_position!, _filteredItems, _nearbyLimit);
  }

  List<_PointItem> _nearestItemsFrom(Position pos, List<_PointItem> items, int limit) {
    final sorted = List<_PointItem>.from(items);
    sorted.sort((a, b) {
      final da = Geolocator.distanceBetween(pos.latitude, pos.longitude, a.lat, a.lng);
      final db = Geolocator.distanceBetween(pos.latitude, pos.longitude, b.lat, b.lng);
      return da.compareTo(db);
    });
    if (sorted.length <= limit) {
      return sorted;
    }
    return sorted.take(limit).toList();
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

  String _staffLabel() {
    return switch (widget.type) {
      ServiceMapType.hospital => 'Total Doctors',
      ServiceMapType.ambulance => 'Emergency Staff',
      ServiceMapType.medicineShop => 'Pharmacy Staff',
    };
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
                  _detailRow('District', item.district),
                  _detailRow('Division', item.division),
                  _detailRow('Service Type', item.serviceType),
                  _detailRow('Website', _websiteFor(item)),
                  _detailRow(_staffLabel(), _doctorCountFor(item).toString()),
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
      appBar: AppBar(
        title: BeautifiedTabHeading(
          title: _screenTitle,
          icon: _typeIcon,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
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
                          const SizedBox(height: 6),
                          Text(
                            _position == null
                                ? 'Showing all available points (location not ready).'
                                : 'Showing nearest ${_visibleItems.length} of ${_filteredItems.length} matched points from 64 district locations.',
                            style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 12),
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
                                itemCount: _visibleItems.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _visibleItems[index];
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

    for (final item in _visibleItems) {
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
  const _PointItem(
    this.id,
    this.name,
    this.address,
    this.phone,
    this.lat,
    this.lng,
    this.district,
    this.division,
    this.serviceType,
  );

  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final String district;
  final String division;
  final String serviceType;
}

class _DistrictArea {
  const _DistrictArea({
    required this.id,
    required this.division,
    required this.district,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String division;
  final String district;
  final double lat;
  final double lng;
}
