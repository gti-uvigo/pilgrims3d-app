import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import '../widgets/cards/poi_card.dart';

class RelevantPoisScreen extends StatefulWidget {
  const RelevantPoisScreen({super.key});

  @override
  State<RelevantPoisScreen> createState() => _RelevantPoisScreenState();
}

class _RelevantPoisScreenState extends State<RelevantPoisScreen> {
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
    final result = await get_relevant_pois(lang);
    pois = List<Map<String, dynamic>>.from(
      result.where(
        (poi) =>
            poi['zenodo_url'] != null &&
            poi['zenodo_url'].toString().isNotEmpty,
      ),
    );
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
        title: Text(localeProvider.translate('important_points_of_interest')),
        leading:
            kIsWeb
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
          final double cardWidth =
              (screenWidth * 0.9) < maxCardWidth
                  ? (screenWidth * 0.9)
                  : maxCardWidth;
          final double cardHeight = MediaQuery.of(context).size.height / 2.5;
          return Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: PoiCard(
                poi: poi,
                localeProvider: localeProvider,
                theme: theme,
                dayIndex: 0,
                poiIndex: index,
                frontCardSize: null,
                fixedCardHeight: cardHeight,
                isFlipped: flipped,
                showHint: _showHint,
                onFlip: () => _toggleCard(index),
                frontCardKey: ValueKey('front_$index'),
              ),
            ),
          );
        },
      ),
    );
  }
}
