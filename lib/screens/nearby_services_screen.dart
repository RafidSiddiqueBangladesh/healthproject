import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/liquid_glass.dart';

class NearbyServicesScreen extends StatefulWidget {
  const NearbyServicesScreen({super.key});

  @override
  State<NearbyServicesScreen> createState() => _NearbyServicesScreenState();
}

class _NearbyServicesScreenState extends State<NearbyServicesScreen> {
  final MapController _mapController = MapController();

  Position? _position;
  bool _isLoading = true;
  String? _error;

  _ServicePoint? _nearestHospital;
  _ServicePoint? _nearestPharmacy;
  _ServicePoint? _nearestAmbulance;

  _ServicePoint get _hospitalForMap => _nearestHospital ?? _hospitals.first;
  _ServicePoint get _pharmacyForMap => _nearestPharmacy ?? _pharmacies.first;
  _ServicePoint get _ambulanceForMap => _nearestAmbulance ?? _ambulances.first;

  final List<_ServicePoint> _hospitals = const [
    _ServicePoint(
      id: 'h1',
      name: 'City Care Hospital',
      address: '12 Main Road',
      phone: '+8801711111111',
      lat: 23.7890,
      lng: 90.4010,
      kind: _ServiceKind.hospital,
    ),
    _ServicePoint(
      id: 'h2',
      name: 'Green Life Medical',
      address: '22 Lake Avenue',
      phone: '+8801722222222',
      lat: 23.7801,
      lng: 90.4153,
      kind: _ServiceKind.hospital,
    ),
    _ServicePoint(
      id: 'h3',
      name: 'Evercare Mock Center',
      address: '88 Health Street',
      phone: '+8801733333333',
      lat: 23.8046,
      lng: 90.4219,
      kind: _ServiceKind.hospital,
    ),
  ];

  final List<_ServicePoint> _pharmacies = const [
    _ServicePoint(
      id: 'p1',
      name: 'MediPlus Pharmacy',
      address: '5 Central Point',
      phone: '+8801744444444',
      lat: 23.7861,
      lng: 90.4084,
      kind: _ServiceKind.pharmacy,
    ),
    _ServicePoint(
      id: 'p2',
      name: 'Care Drug House',
      address: '9 Clinic Lane',
      phone: '+8801755555555',
      lat: 23.7758,
      lng: 90.3989,
      kind: _ServiceKind.pharmacy,
    ),
    _ServicePoint(
      id: 'p3',
      name: 'Health First Medicine',
      address: '33 Relief Road',
      phone: '+8801766666666',
      lat: 23.8122,
      lng: 90.4101,
      kind: _ServiceKind.pharmacy,
    ),
  ];

  final List<_ServicePoint> _ambulances = const [
    _ServicePoint(
      id: 'a1',
      name: 'Rapid Ambulance Unit',
      address: 'Emergency Hub 1',
      phone: '+8801777777777',
      lat: 23.7922,
      lng: 90.3920,
      kind: _ServiceKind.ambulance,
    ),
    _ServicePoint(
      id: 'a2',
      name: 'LifeLine Ambulance',
      address: 'Emergency Hub 2',
      phone: '+8801788888888',
      lat: 23.7704,
      lng: 90.4258,
      kind: _ServiceKind.ambulance,
    ),
    _ServicePoint(
      id: 'a3',
      name: '24x7 Rescue Ambulance',
      address: 'Emergency Hub 3',
      phone: '+8801799999999',
      lat: 23.8001,
      lng: 90.4051,
      kind: _ServiceKind.ambulance,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNearestServices();
  }

  Future<void> _loadNearestServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location service is disabled. Please enable GPS/location.';
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied. Please allow location permission.';
          _isLoading = false;
        });
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      setState(() {
        _position = position;
        _nearestHospital = _nearestFrom(position, _hospitals);
        _nearestPharmacy = _nearestFrom(position, _pharmacies);
        _nearestAmbulance = _nearestFrom(position, _ambulances);
        _isLoading = false;
      });

      // Center map on nearest hospital after first successful fetch.
      if (_nearestHospital != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusOnService(_nearestHospital!);
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Could not get location right now. Please try again.';
        _isLoading = false;
      });
    }
  }

  _ServicePoint? _nearestFrom(Position position, List<_ServicePoint> list) {
    if (list.isEmpty) {
      return null;
    }
    _ServicePoint nearest = list.first;
    double best = _distanceMeters(position.latitude, position.longitude, nearest.lat, nearest.lng);

    for (final item in list.skip(1)) {
      final nextDistance = _distanceMeters(position.latitude, position.longitude, item.lat, item.lng);
      if (nextDistance < best) {
        best = nextDistance;
        nearest = item;
      }
    }
    return nearest.copyWith(distanceMeters: best);
  }

  double _distanceMeters(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  void _focusOnService(_ServicePoint service) {
    _mapController.move(LatLng(service.lat, service.lng), 16);
  }

  Future<void> _openInMaps(_ServicePoint service) async {
    final label = Uri.encodeComponent(service.name);
    final googleUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${service.lat},${service.lng}($label)');
    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callService(_ServicePoint service) async {
    final phoneUri = Uri.parse('tel:${service.phone}');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nearest Services'),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LiquidGlassCard(
                        tint: const Color(0xFFD8F3FF),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location Status',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            if (_error != null)
                              Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFFFEBEE)),
                              )
                            else if (_position != null)
                              Text(
                                'Current location: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(color: Color(0xFFEAF6FF)),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadNearestServices,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Refresh Nearest'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LiquidGlassCard(
                        tint: const Color(0xFFE3F0FF),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nearest Services Map (Free)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'OpenStreetMap is shown here like Google Maps style, but free.',
                              style: TextStyle(color: Color(0xFFEAF6FF), fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 320,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _initialCenter(),
                                    initialZoom: 14,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'nutricare.app',
                                    ),
                                    MarkerLayer(
                                      markers: _buildMapMarkers(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _LegendChip(label: 'You', color: Color(0xFF80DEEA)),
                                _LegendChip(label: 'Hospital', color: Color(0xFFFF8A80)),
                                _LegendChip(label: 'Medicine Shop', color: Color(0xFFA5D6A7)),
                                _LegendChip(label: 'Ambulance', color: Color(0xFFFFCC80)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_nearestHospital != null) _serviceCard(_nearestHospital!),
                      if (_nearestPharmacy != null) ...[
                        const SizedBox(height: 12),
                        _serviceCard(_nearestPharmacy!),
                      ],
                      if (_nearestAmbulance != null) ...[
                        const SizedBox(height: 12),
                        _serviceCard(_nearestAmbulance!),
                      ],
                      const SizedBox(height: 16),
                      LiquidGlassCard(
                        tint: const Color(0xFFE7DEFF),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mock Data List (Replace Later)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            ..._hospitals.map((e) => _listTile(e)),
                            const SizedBox(height: 8),
                            ..._pharmacies.map((e) => _listTile(e)),
                            const SizedBox(height: 8),
                            ..._ambulances.map((e) => _listTile(e)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    if (_position != null) {
      markers.add(
        Marker(
          point: LatLng(_position!.latitude, _position!.longitude),
          width: 44,
          height: 44,
          child: _markerDot(Icons.my_location, const Color(0xFF80DEEA)),
        ),
      );
    }

    markers.addAll([
      Marker(
        point: LatLng(_hospitalForMap.lat, _hospitalForMap.lng),
        width: 44,
        height: 44,
        child: _markerDot(Icons.local_hospital, const Color(0xFFFF8A80)),
      ),
      Marker(
        point: LatLng(_pharmacyForMap.lat, _pharmacyForMap.lng),
        width: 44,
        height: 44,
        child: _markerDot(Icons.local_pharmacy, const Color(0xFFA5D6A7)),
      ),
      Marker(
        point: LatLng(_ambulanceForMap.lat, _ambulanceForMap.lng),
        width: 44,
        height: 44,
        child: _markerDot(Icons.emergency, const Color(0xFFFFCC80)),
      ),
    ]);

    return markers;
  }

  LatLng _initialCenter() {
    if (_position != null) {
      return LatLng(_position!.latitude, _position!.longitude);
    }
    return LatLng(_hospitalForMap.lat, _hospitalForMap.lng);
  }

  Widget _markerDot(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
    );
  }

  Widget _serviceCard(_ServicePoint service) {
    final color = switch (service.kind) {
      _ServiceKind.hospital => const Color(0xFFFFDDE6),
      _ServiceKind.pharmacy => const Color(0xFFD9FFE7),
      _ServiceKind.ambulance => const Color(0xFFFFF2D8),
    };

    final typeText = switch (service.kind) {
      _ServiceKind.hospital => 'Nearest Hospital',
      _ServiceKind.pharmacy => 'Nearest Medicine Shop',
      _ServiceKind.ambulance => 'Nearest Ambulance',
    };

    final distanceKm = ((service.distanceMeters ?? 0) / 1000).toStringAsFixed(2);

    return GestureDetector(
      onTap: () => _focusOnService(service),
      child: LiquidGlassCard(
        tint: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    typeText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const Icon(Icons.center_focus_strong, color: Color(0xFFEAF6FF), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(service.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Text(service.address, style: const TextStyle(color: Color(0xFFEAF6FF))),
            const SizedBox(height: 4),
            Text('Distance: $distanceKm km', style: const TextStyle(color: Color(0xFFEAF6FF))),
            const SizedBox(height: 6),
            const Text('Tap card to auto focus on map', style: TextStyle(color: Color(0xFFDDEEFF), fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openInMaps(service),
                  icon: const Icon(Icons.map),
                  label: const Text('Open Map'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _callService(service),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listTile(_ServicePoint item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '${item.kind.label}: ${item.name} (${item.address})',
        style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 13),
      ),
    );
  }
}

enum _ServiceKind { hospital, pharmacy, ambulance }

extension on _ServiceKind {
  String get label => switch (this) {
        _ServiceKind.hospital => 'Hospital',
        _ServiceKind.pharmacy => 'Medicine Shop',
        _ServiceKind.ambulance => 'Ambulance',
      };
}

class _ServicePoint {
  const _ServicePoint({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.kind,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final _ServiceKind kind;
  final double? distanceMeters;

  _ServicePoint copyWith({double? distanceMeters}) {
    return _ServicePoint(
      id: id,
      name: name,
      address: address,
      phone: phone,
      lat: lat,
      lng: lng,
      kind: kind,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
