import 'package:flutter/material.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:provider/provider.dart';

class RouteReviewBottomSheet extends StatefulWidget {
  final String routeId;
  final String routeName;
  final bool isLoggedIn;

  const RouteReviewBottomSheet({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.isLoggedIn,
  });

  @override
  State<RouteReviewBottomSheet> createState() => _RouteReviewBottomSheetState();
}

class _RouteReviewBottomSheetState extends State<RouteReviewBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _reviewsListKey = GlobalKey<_ReviewsListTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.routeName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                icon: const Icon(Icons.forum_outlined, size: 20),
                text: localeProvider.translate('reviews_tab'),
              ),
              Tab(
                icon: const Icon(Icons.edit_outlined, size: 20),
                text: localeProvider.translate('write_review_tab'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReviewsListTab(key: _reviewsListKey, routeId: widget.routeId),
                _WriteReviewTab(
                  routeId: widget.routeId,
                  isLoggedIn: widget.isLoggedIn,
                  onSubmitted: () async {
                    _tabController.animateTo(0);
                    await Future.delayed(const Duration(milliseconds: 300));
                    _reviewsListKey.currentState?.refresh();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Santos ───────────────────────────────────────────────────────────────────

const List<String> _kSaintNames = [
  'San Andrés',
  'San Bartolomé',
  'San Bernardo',
  'San Blas',
  'San Bruno',
  'San Camilo',
  'San Casimiro',
  'San Cayetano',
  'San Cipriano',
  'San Clemente',
  'San Cornelio',
  'San Damián',
  'San Demetrio',
  'San Diego',
  'San Dionisio',
  'San Domingo',
  'San Elías',
  'San Emilio',
  'San Ernesto',
  'San Esteban',
  'San Fabián',
  'San Felipe',
  'San Fermín',
  'San Fernando',
  'San Francisco',
  'San Gregorio',
  'San Guillermo',
  'San Ignacio',
  'San Isidro',
  'San Jacobo',
  'San Jerónimo',
  'San Joaquín',
  'San Jorge',
  'San José',
  'San Juan',
  'San Julián',
  'San Justo',
  'San León',
  'San Lorenzo',
  'San Lucas',
  'San Luis',
  'San Marcos',
  'San Martín',
  'San Mateo',
  'San Miguel',
  'San Nicolás',
  'San Pablo',
  'San Patricio',
  'San Pedro',
  'San Rafael',
  'San Raimundo',
  'San Ramón',
  'San Roberto',
  'San Roque',
  'San Rosendo',
  'San Sebastián',
  'San Silvestre',
  'San Simón',
  'San Teodoro',
  'San Timoteo',
  'San Tomás',
  'San Valentín',
  'San Vicente',
  'San Víctor',
  'San Zenón',
  'Santa Águeda',
  'Santa Ana',
  'Santa Bárbara',
  'Santa Beatriz',
  'Santa Blanca',
  'Santa Catalina',
  'Santa Cecilia',
  'Santa Clara',
  'Santa Elena',
  'Santa Elvira',
  'Santa Eulalia',
  'Santa Gema',
  'Santa Inés',
  'Santa Irene',
  'Santa Isabel',
  'Santa Laura',
  'Santa Lucía',
  'Santa María',
  'Santa Marta',
  'Santa Mónica',
  'Santa Natalia',
  'Santa Olga',
  'Santa Paula',
  'Santa Rita',
  'Santa Rosa',
  'Santa Sofía',
  'Santa Teresa',
  'Santa Verónica',
  'Santa Victoria',
  'Santa Yolanda',
];

String _saintNameFor(String userId, String routeId) {
  if (userId.isEmpty) return _kSaintNames[0];
  int hash = 0;
  for (final c in '$userId:$routeId'.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return _kSaintNames[hash % _kSaintNames.length];
}

// ─── Tab: Lista de reseñas ────────────────────────────────────────────────────

class _ReviewsListTab extends StatefulWidget {
  final String routeId;
  const _ReviewsListTab({super.key, required this.routeId});

  @override
  State<_ReviewsListTab> createState() => _ReviewsListTabState();
}

class _ReviewsListTabState extends State<_ReviewsListTab> {
  List<dynamic>? _reviews;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final data = await get_route_reviews(widget.routeId);
    if (mounted) {
      // Deduplicar por user_id, quedándonos con la más reciente de cada usuario
      final seen = <String>{};
      final deduped = <dynamic>[];
      for (final r in data) {
        final uid = (r as Map<String, dynamic>)['user_id']?.toString() ?? '';
        if (seen.add(uid)) deduped.add(r);
      }
      setState(() {
        _reviews = deduped;
        _loading = false;
      });
    }
  }

  void refresh() {
    setState(() => _loading = true);
    _loadReviews();
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              localeProvider.translate('reviews_loading'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_reviews == null || _reviews!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: colorScheme.onSurface.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(
                localeProvider.translate('no_reviews_yet'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _reviews!.length,
      separatorBuilder:
          (_, __) => Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
      itemBuilder: (context, index) {
        final review = _reviews![index] as Map<String, dynamic>;
        final comment = review['comment']?.toString() ?? '';
        final userId = review['user_id']?.toString() ?? '';
        final author = _saintNameFor(userId, widget.routeId);
        final date = review['created_at']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  author.isNotEmpty
                      ? author.split(' ').last[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            author,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            _formatDate(date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(comment, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Tab: Escribir reseña ─────────────────────────────────────────────────────

class _WriteReviewTab extends StatefulWidget {
  final String routeId;
  final bool isLoggedIn;
  final VoidCallback onSubmitted;

  const _WriteReviewTab({
    required this.routeId,
    required this.isLoggedIn,
    required this.onSubmitted,
  });

  @override
  State<_WriteReviewTab> createState() => _WriteReviewTabState();
}

class _WriteReviewTabState extends State<_WriteReviewTab> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _checkingExisting = true;
  bool _alreadyReviewed = false;
  late final AnimationController _successAnimController;
  late final Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 500),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
    if (widget.isLoggedIn) _checkExistingReview();
  }

  Future<void> _checkExistingReview() async {
    try {
      final reviews = await get_route_reviews(widget.routeId);
      if (mounted) {
        final userToken = idToken;
        final has = reviews.any(
          (r) =>
              (r as Map<String, dynamic>)['user_id']?.toString() == userToken,
        );
        setState(() {
          _alreadyReviewed = has;
          _checkingExisting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingExisting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(LocaleProvider localeProvider) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await rate_route(widget.routeId, comment: text);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
        _successAnimController.forward();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localeProvider.translate('rate_route_error')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!widget.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                localeProvider.translate('rate_route_login_required'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_checkingExisting) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_alreadyReviewed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                localeProvider.translate('already_reviewed'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child:
          _submitted
              ? ScaleTransition(
                scale: _successScaleAnim,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade500,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      localeProvider.translate('rate_route_success'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: localeProvider.translate(
                        'rate_route_comment_hint',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest
                          .withOpacity(0.4),
                      counterStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _commentController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return FilledButton(
                        onPressed:
                            hasText && !_isSubmitting
                                ? () {
                                  HapticService().medium();
                                  _submitReview(localeProvider);
                                }
                                : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                                : Text(
                                  localeProvider.translate('rate_route_submit'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      );
                    },
                  ),
                ],
              ),
    );
  }
}
