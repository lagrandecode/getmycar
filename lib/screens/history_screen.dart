import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/parking_service.dart';
import '../services/ai_service.dart';
import '../models/parking_session_model.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchWithAI(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final parkingService = context.read<ParkingService>();
      final aiService = context.read<AIService>();

      // Get recent sessions
      final sessions = await parkingService.getRecentSessions(limit: 50);

      // Convert to summary format
      final sessionsSummary = sessions.map((s) {
        return {
          'id': s.id,
          'place': s.place?.label ?? 'Unknown',
          'date': s.savedAt.toIso8601String(),
          'aiParsed': s.aiParsed?.toJson(),
          'rawNote': s.rawNote,
        };
      }).toList();

      // Search with AI
      final sessionId = await aiService.searchParkingSession(query, sessionsSummary);

      if (mounted) {
        if (sessionId != null) {
          context.go('/navigate/$sessionId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No matching parking session found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parkingService = context.watch<ParkingService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking History'),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search (e.g., "stadium last month")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () => _searchWithAI(_searchController.text),
                        tooltip: 'AI Search',
                      ),
              ),
              onSubmitted: _searchWithAI,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ParkingSession>>(
              stream: parkingService.watchSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Center(
                    child: Text('No parking sessions yet'),
                  );
                }

                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Icon(
                          session.active ? Icons.directions_car : Icons.directions_car_outlined,
                          color: session.active ? Colors.red : Colors.grey,
                        ),
                        title: Text(
                          session.place?.label ?? 'Parking Spot',
                          style: TextStyle(
                            fontWeight: session.active ? FontWeight.bold : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, y • h:mm a').format(session.savedAt),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${session.lat.toStringAsFixed(6)}, Lng: ${session.lng.toStringAsFixed(6)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                            if (session.altitude != null) ...[
                              Text(
                                'Alt: ${session.altitude!.toStringAsFixed(1)}m',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (session.aiParsed != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  session.aiParsed!.level,
                                  session.aiParsed!.gate,
                                  session.aiParsed!.zone,
                                ].where((s) => s != null).join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (session.rawNote != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                session.rawNote!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: session.active
                            ? const Chip(
                                label: Text('Active'),
                                backgroundColor: Colors.red,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : null,
                        onTap: () => context.go('/navigate/${session.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

