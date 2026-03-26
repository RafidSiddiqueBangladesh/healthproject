import 'package:flutter/material.dart';

import '../data/bd_admin_mock_data.dart';
import '../widgets/liquid_glass.dart';

class BdDistrictsMockScreen extends StatefulWidget {
  const BdDistrictsMockScreen({super.key});

  @override
  State<BdDistrictsMockScreen> createState() => _BdDistrictsMockScreenState();
}

class _BdDistrictsMockScreenState extends State<BdDistrictsMockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BdDivisionData> get _filteredDivisions {
    if (_query.isEmpty) {
      return bdDivisionsMockData;
    }

    final result = <BdDivisionData>[];
    for (final division in bdDivisionsMockData) {
      final filteredDistricts = division.districts.where((district) {
        final districtMatch = district.name.toLowerCase().contains(_query);
        final upazilaMatch = district.upazilas.any((u) => u.toLowerCase().contains(_query));
        return districtMatch || upazilaMatch;
      }).toList();

      if (division.name.toLowerCase().contains(_query) || filteredDistricts.isNotEmpty) {
        result.add(BdDivisionData(name: division.name, districts: filteredDistricts.isEmpty ? division.districts : filteredDistricts));
      }
    }
    return result;
  }

  int get _districtCount => bdDivisionsMockData.fold<int>(0, (sum, d) => sum + d.districts.length);

  @override
  Widget build(BuildContext context) {
    final divisions = _filteredDivisions;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Bangladesh 64 Districts')),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: Column(
            children: [
              LiquidGlassCard(
                tint: const Color(0xFFDFF1FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administrative Data (Mock)',
                      style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Divisions: ${bdDivisionsMockData.length} | Districts: $_districtCount',
                      style: const TextStyle(color: Color(0xFFEAF6FF)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Note: This is mock data for UI/testing purpose.',
                      style: TextStyle(color: Color(0xFFFFE5B4), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search division, district, or upazila',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: divisions.isEmpty
                    ? const LiquidGlassCard(
                        tint: Color(0xFFE6DCFF),
                        child: Center(
                          child: Text('No data found for this search.', style: TextStyle(color: Colors.white)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: divisions.length,
                        itemBuilder: (context, index) {
                          final division = divisions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LiquidGlassCard(
                              tint: const Color(0xFFE6DCFF),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                iconColor: Colors.white,
                                collapsedIconColor: Colors.white,
                                title: Text(
                                  '${division.name} (${division.districts.length} Districts)',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                children: division.districts.map((district) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0x20FFFFFF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            district.name,
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: district.upazilas
                                                .map(
                                                  (u) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0x2FFFFFFF),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(
                                                      u,
                                                      style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 12),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
