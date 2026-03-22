// Active screen: environment/debug utility wired from main.dart via /debug_env.

import 'package:flutter/material.dart';

import 'package:giveaway_app/utils/constants.dart';

class DebugEnvScreen extends StatelessWidget {
  const DebugEnvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (label: 'Environment', value: apiEnvironmentLabel),
      (label: 'API_BASE_URL', value: apiBaseUrl),
      (label: 'API host', value: apiBaseUri.host),
      (label: 'collect_device_geo', value: collectGeoUri.toString()),
      (label: 'device_report', value: deviceReportUri.toString()),
      (label: 'GEO_SERVICE_URL', value: geoServiceUrl),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Debug'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final row = rows[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  row.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
