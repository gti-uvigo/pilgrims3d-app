import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import '../widgets/cards/poi_card_simple.dart';

class MyPoisScreen extends StatefulWidget {
  const MyPoisScreen({super.key});

  @override
  State<MyPoisScreen> createState() => _MyPoisScreenState();
}

class _MyPoisScreenState extends State<MyPoisScreen> {
  late List<Map<String, dynamic>> pois = [];
  bool _loading = true;
  bool _showHint = false;
  final Set<int> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _loadPois();
    _checkIfShouldShowHint();
  }

  Future<void> _checkIfShouldShowHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool('has_seen_poi_hint_simple') ?? false;
    if (!hasSeenHint) {
      setState(() => _showHint = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showHint = false);
          prefs.setBool('has_seen_poi_hint_simple', true);
        }
      });
    }
  }

  Future<void> _loadPois() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
  final lang = localeProvider.currentLangId;
    final result = await get_pois_by_user_email(lang);
    pois = List<Map<String, dynamic>>.from(result);
    if (mounted) setState(() => _loading = false);
  }

  void _toggleCard(int index) {
    setState(() {
      if (_flippedCards.contains(index)) {
        _flippedCards.remove(index);
      } else {
        _flippedCards.add(index);
      }
    });
  }

  bool _isFlipped(int index) => _flippedCards.contains(index);

  void _showMoreInfo(BuildContext context, Map<String, dynamic> poi) {
    final String title = poi['title'] ?? poi['description'] ?? 'Sin título';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (poi['description'] != null) ...[
                          Text(poi['description']),
                          const SizedBox(height: 16),
                        ],
                        if (poi['types'] != null && (poi['types'] as List).isNotEmpty) ...[
                          Text(
                            'Tipos: ${(poi['types'] as List).join(', ')}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (poi['address'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16),
                              const SizedBox(width: 4),
                              Expanded(child: Text(poi['address'])),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (poi['website'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.language, size: 16),
                              const SizedBox(width: 4),
                              Expanded(child: Text(poi['website'])),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (poi['rating'] != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text('${poi['rating']}'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(localeProvider.translate('my_points_of_interest')),
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.home),
                onPressed: () => context.push('/'),
              )
            : null,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24),
        itemCount: pois.length,
        itemBuilder: (context, index) {
          final poi = pois[index];
          final flipped = _isFlipped(index);
          final double screenWidth = MediaQuery.of(context).size.width;
          const double maxCardWidth = 800;
          final double cardWidth = (screenWidth * 0.9) < maxCardWidth ? (screenWidth * 0.9) : maxCardWidth;
          final double cardHeight = cardWidth * (9 / 16);
          return Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: PoiCardSimple(
                poi: poi,
                localeProvider: localeProvider,
                theme: theme,
                index: index,
                isFlipped: flipped,
                showHint: _showHint,
                onFlip: () => _toggleCard(index),
                onLongPress: () async {
                  await HapticService().longPress();
                  _showMoreInfo(context, poi);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
