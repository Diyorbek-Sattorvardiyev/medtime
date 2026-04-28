import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/auth_api.dart';
import '../../widgets/app_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiClient();
  var _loading = true;
  String? _error;
  final _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarix')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(onPressed: _loadHistory, child: Text(_error!)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final text =
                    '${item['planned_at'] ?? ''} ${(item['name'] ?? 'Dori')} ${item['status'] ?? ''}';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        if (index != _items.length - 1)
                          Container(
                            width: 2,
                            height: 58,
                            color: AppColors.border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Text(text),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getHistory();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
