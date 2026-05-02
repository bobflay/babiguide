import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../constants.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool showFilterSheet;
  final ValueChanged<String>? onOpenRestaurant;
  final String? initialQuery;
  final String? initialNeighborhoodId;
  final int? initialSortIndex;

  const SearchScreen({
    super.key,
    this.onBack,
    this.showFilterSheet = false,
    this.onOpenRestaurant,
    this.initialQuery,
    this.initialNeighborhoodId,
    this.initialSortIndex,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Filters {
  final bool openNow;
  final double? maxDistanceKm;
  final double? minRating;
  final Set<int> priceTiers; // 1..4 (1-indexed)
  final Set<String> cuisines;
  final Set<String> amenities;
  final int sortIndex;

  const _Filters({
    this.openNow = false,
    this.maxDistanceKm,
    this.minRating,
    this.priceTiers = const {},
    this.cuisines = const {},
    this.amenities = const {},
    this.sortIndex = 0,
  });

  _Filters copyWith({
    bool? openNow,
    double? maxDistanceKm,
    bool clearMaxDistance = false,
    double? minRating,
    bool clearMinRating = false,
    Set<int>? priceTiers,
    Set<String>? cuisines,
    Set<String>? amenities,
    int? sortIndex,
  }) {
    return _Filters(
      openNow: openNow ?? this.openNow,
      maxDistanceKm:
          clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      priceTiers: priceTiers ?? this.priceTiers,
      cuisines: cuisines ?? this.cuisines,
      amenities: amenities ?? this.amenities,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }
}

class _SearchScreenState extends State<SearchScreen> {
  late bool _showFilter = widget.showFilterSheet;
  final _q = TextEditingController();
  Timer? _debounce;
  Future<PagedList<Place>>? _resultsFuture;
  Future<List<SearchSuggestion>>? _suggestionsFuture;
  late _Filters _filters = _Filters(
    sortIndex: (widget.initialSortIndex ?? 0).clamp(0, sortKeys.length - 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _q.text = widget.initialQuery!;
      _q.selection = TextSelection.collapsed(offset: _q.text.length);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSearch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSuggestions();
      _runSearch();
    });
  }

  void _runSearch() {
    if (!mounted) return;
    final api = AppScope.of(context).placesApi;
    final f = _filters;
    final priceList =
        f.priceTiers.toList()..sort();
    setState(() {
      _resultsFuture = api.getPlaces(
        q: _q.text.trim().isEmpty ? null : _q.text.trim(),
        sort: sortKeys[f.sortIndex.clamp(0, sortKeys.length - 1)],
        openNow: f.openNow ? true : null,
        maxDistanceKm: f.maxDistanceKm,
        minRating: f.minRating,
        price: priceList.map((i) => '$i').toList(),
        cuisines: f.cuisines.toList(),
        amenities: f.amenities.toList(),
        neighborhood: widget.initialNeighborhoodId,
      );
    });
  }

  Future<void> _refreshResults() async {
    _runSearch();
    final fut = _resultsFuture;
    if (fut == null) return;
    try {
      await fut;
    } catch (_) {}
  }

  void _runSuggestions() {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestionsFuture = null);
      return;
    }
    final api = AppScope.of(context).placesApi;
    setState(() {
      _suggestionsFuture = api.getSuggestions(q: q);
    });
  }

  void _applyFilters(_Filters next) {
    setState(() {
      _filters = next;
      _showFilter = false;
    });
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Stack(
      children: [
        Container(
          color: p.bg,
          child: Column(
            children: [
              _SearchBar(
                p: p,
                l: l,
                controller: _q,
                onChanged: _onQueryChanged,
                onClear: () {
                  _q.clear();
                  _onQueryChanged('');
                },
                onBack: widget.onBack,
              ),
              _QuickChips(
                p: p,
                l: l,
                filters: _filters,
                onChange: (f) {
                  setState(() => _filters = f);
                  _runSearch();
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshResults,
                  color: p.orange,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 30),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_q.text.trim().isNotEmpty)
                        _SuggestionsBlock(
                          future: _suggestionsFuture,
                          p: p,
                          onPick: (s) {
                            if (s.type == 'place' && s.id != null) {
                              widget.onOpenRestaurant?.call(s.id!);
                              return;
                            }
                            _q.text = s.label;
                            _q.selection = TextSelection.collapsed(
                                offset: s.label.length);
                            _onQueryChanged(s.label);
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: _ResultsHeader(
                          p: p,
                          l: l,
                          future: _resultsFuture,
                          sortIndex: _filters.sortIndex,
                          onTapSort: () => setState(() => _showFilter = true),
                        ),
                      ),
                      _ResultsList(
                        future: _resultsFuture,
                        p: p,
                        l: l,
                        onOpenRestaurant: widget.onOpenRestaurant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showFilter)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showFilter = false),
              child: Container(color: const Color(0x73140C04)),
            ),
          ),
        if (_showFilter)
          _FilterSheet(
            initial: _filters,
            l: l,
            onApply: _applyFilters,
            onCancel: () => setState(() => _showFilter = false),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final BgPalette p;
  final L l;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onBack;

  const _SearchBar({
    required this.p,
    required this.l,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
              child: Icon(Icons.chevron_left, size: 20, color: p.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: p.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: l.searchPlaceholder,
                        hintStyle: BgFonts.body(size: 14, color: p.inkMuted),
                      ),
                      style: BgFonts.body(size: 14, color: p.ink),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close, size: 16, color: p.inkMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final BgPalette p;
  final L l;
  final _Filters filters;
  final ValueChanged<_Filters> onChange;

  const _QuickChips({
    required this.p,
    required this.l,
    required this.filters,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      _Chip(
        label: l.searchChips[1], // "Ouvert" / "Open now"
        on: filters.openNow,
        onTap: () => onChange(filters.copyWith(openNow: !filters.openNow)),
      ),
      _Chip(
        label: l.searchChips[2], // "< 2 km"
        on: filters.maxDistanceKm == 2,
        onTap: () => onChange(filters.copyWith(
          maxDistanceKm: filters.maxDistanceKm == 2 ? null : 2,
          clearMaxDistance: filters.maxDistanceKm == 2,
        )),
      ),
      _Chip(
        label: l.searchChips[3], // "4★+"
        on: filters.minRating == 4,
        onTap: () => onChange(filters.copyWith(
          minRating: filters.minRating == 4 ? null : 4,
          clearMinRating: filters.minRating == 4,
        )),
      ),
      _Chip(
        label: l.searchChips[4], // "₣₣ ou moins"
        on: filters.priceTiers.contains(1) && filters.priceTiers.contains(2),
        onTap: () {
          final hasBoth =
              filters.priceTiers.contains(1) && filters.priceTiers.contains(2);
          onChange(filters.copyWith(
            priceTiers: hasBoth ? <int>{} : <int>{1, 2},
          ));
        },
      ),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i].build(context, p),
      ),
    );
  }
}

class _Chip {
  final String label;
  final bool on;
  final VoidCallback onTap;
  _Chip({required this.label, required this.on, required this.onTap});

  Widget build(BuildContext context, BgPalette p) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? p.ink : p.card,
          borderRadius: BorderRadius.circular(999),
          border: on ? null : Border.all(color: p.cardBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: BgFonts.body(
            size: 13,
            weight: FontWeight.w600,
            color: on ? p.bg : p.ink,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SuggestionsBlock extends StatelessWidget {
  final Future<List<SearchSuggestion>>? future;
  final BgPalette p;
  final ValueChanged<SearchSuggestion> onPick;

  const _SuggestionsBlock({
    required this.future,
    required this.p,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<SearchSuggestion>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final items = snap.data!;
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(height: 1, color: p.cardBorder),
                  GestureDetector(
                    onTap: () => onPick(items[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(_iconFor(items[i].type), size: 16, color: p.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i].label,
                                  style: BgFonts.body(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                                if ((items[i].sub ?? '').isNotEmpty)
                                  Text(
                                    items[i].sub!,
                                    style: BgFonts.body(
                                      size: 11,
                                      color: p.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'place':
        return Icons.restaurant;
      case 'neighborhood':
        return Icons.location_on_outlined;
      case 'cuisine':
        return Icons.category_outlined;
      default:
        return Icons.search;
    }
  }
}

class _ResultsHeader extends StatelessWidget {
  final BgPalette p;
  final L l;
  final Future<PagedList<Place>>? future;
  final int sortIndex;
  final VoidCallback onTapSort;

  const _ResultsHeader({
    required this.p,
    required this.l,
    required this.future,
    required this.sortIndex,
    required this.onTapSort,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PagedList<Place>>(
      future: future,
      builder: (context, snap) {
        final total = snap.data?.total;
        return Row(
          children: [
            Expanded(
              child: Text(
                total == null
                    ? (snap.connectionState == ConnectionState.waiting
                        ? l.pick('Recherche…', 'Searching…')
                        : '')
                    : l.resultsFound(total),
                style: BgFonts.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: p.inkMuted,
                ),
              ),
            ),
            GestureDetector(
              onTap: onTapSort,
              child: Row(
                children: [
                  Icon(Icons.tune, size: 13, color: p.ink),
                  const SizedBox(width: 4),
                  Text(
                    '${l.sort}: ${l.sortOptions[sortIndex]}',
                    style: BgFonts.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultsList extends StatelessWidget {
  final Future<PagedList<Place>>? future;
  final BgPalette p;
  final L l;
  final ValueChanged<String>? onOpenRestaurant;

  const _ResultsList({
    required this.future,
    required this.p,
    required this.l,
    required this.onOpenRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PagedList<Place>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(p.orange),
                ),
              ),
            ),
          );
        }
        if (snap.hasError) {
          final msg = snap.error is ApiError
              ? (snap.error as ApiError).message
              : l.pick('Erreur de recherche', 'Search failed');
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: BgFonts.body(size: 13, color: p.inkMuted),
            ),
          );
        }
        final items = snap.data?.items ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              l.pick("Aucun résultat", 'No results'),
              textAlign: TextAlign.center,
              style: BgFonts.body(size: 14, color: p.inkMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final r in items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => onOpenRestaurant?.call(r.id),
                  child: _ResultRow(r: r, l: l),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Place r;
  final L l;
  const _ResultRow({required this.r, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        children: [
          PhotoPlaceholder(
            seed: r.seed,
            label: r.photoLabel,
            width: 92,
            height: 92,
            borderRadius: BorderRadius.circular(11),
            photoUrl: r.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: BgFonts.display(
                          size: 15,
                          weight: FontWeight.w700,
                          color: p.ink,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.star_rounded, size: 12, color: p.orange),
                    const SizedBox(width: 3),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: BgFonts.display(
                        size: 12,
                        weight: FontWeight.w700,
                        color: p.ink,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.cuisine,
                  style: BgFonts.body(size: 12, color: p.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 11, color: p.inkMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        r.neighborhood,
                        style: BgFonts.body(size: 11, color: p.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusPill(open: r.open, label: r.open ? l.open : l.closed),
                    const SizedBox(width: 6),
                    Text(
                      '· ${r.km} km · ${r.price}',
                      style: BgFonts.body(size: 11, color: p.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool open;
  final String label;
  const _StatusPill({required this.open, required this.label});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final col = open ? p.green : p.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: BgFonts.body(
              size: 10,
              weight: FontWeight.w600,
              color: col,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final _Filters initial;
  final L l;
  final ValueChanged<_Filters> onApply;
  final VoidCallback onCancel;

  const _FilterSheet({
    required this.initial,
    required this.l,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Filters _draft = widget.initial;
  late double _distanceKm = widget.initial.maxDistanceKm ?? 5;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final l = widget.l;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: FractionallySizedBox(
        widthFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Container(
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, -20),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x33785028),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.filterTitle,
                          style: BgFonts.display(
                            size: 22,
                            weight: FontWeight.w700,
                            color: p.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _draft = const _Filters();
                          _distanceKm = 5;
                        }),
                        child: Text(
                          l.reset,
                          style: BgFonts.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: p.orangeDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(text: l.sort),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < l.sortOptions.length; i++)
                        _Tag(
                          label: l.sortOptions[i],
                          on: _draft.sortIndex == i,
                          showCheck: false,
                          onTap: () => setState(() {
                            _draft = _draft.copyWith(sortIndex: i);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(text: l.fCuisine),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(l.cuisines.length, (i) {
                      final key = searchCuisineKeys[i];
                      final on = _draft.cuisines.contains(key);
                      return _Tag(
                        label: l.cuisines[i],
                        on: on,
                        showCheck: false,
                        onTap: () => setState(() {
                          final next = Set<String>.from(_draft.cuisines);
                          if (on) {
                            next.remove(key);
                          } else {
                            next.add(key);
                          }
                          _draft = _draft.copyWith(cuisines: next);
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(text: l.fPrice),
                  Row(
                    children: List.generate(4, (i) {
                      final tier = i + 1;
                      final on = _draft.priceTiers.contains(tier);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            final next = Set<int>.from(_draft.priceTiers);
                            if (on) {
                              next.remove(tier);
                            } else {
                              next.add(tier);
                            }
                            _draft = _draft.copyWith(priceTiers: next);
                          }),
                          child: Container(
                            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: on ? p.orangeSoft : p.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: on
                                    ? p.orange.withValues(alpha: 0.3)
                                    : p.cardBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              priceSymbols[i],
                              style: BgFonts.display(
                                size: 15,
                                weight: FontWeight.w700,
                                color: on ? p.orangeDeep : p.ink,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel(
                            text: l.fDistance, padding: EdgeInsets.zero),
                      ),
                      Text(
                        l.isFr
                            ? 'à ${_distanceKm.toStringAsFixed(1)} km'
                            : '${_distanceKm.toStringAsFixed(1)} km away',
                        style: BgFonts.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _distanceKm,
                    min: 0.5,
                    max: 20,
                    divisions: 39,
                    activeColor: p.orange,
                    onChanged: (v) => setState(() => _distanceKm = v),
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel(text: l.fAmenities),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(l.amenities.length, (i) {
                      final key = amenityKeys[i];
                      final on = _draft.amenities.contains(key);
                      return _Tag(
                        label: l.amenities[i],
                        on: on,
                        showCheck: on,
                        onTap: () => setState(() {
                          final next = Set<String>.from(_draft.amenities);
                          if (on) {
                            next.remove(key);
                          } else {
                            next.add(key);
                          }
                          _draft = _draft.copyWith(amenities: next);
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _draft.openNow,
                        activeColor: p.orange,
                        onChanged: (v) => setState(() {
                          _draft = _draft.copyWith(openNow: v == true);
                        }),
                      ),
                      Text(
                        l.openNow,
                        style: BgFonts.body(
                            size: 13, color: p.ink, weight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Checkbox(
                        value: _draft.minRating == 4,
                        activeColor: p.orange,
                        onChanged: (v) => setState(() {
                          _draft = _draft.copyWith(
                            minRating: v == true ? 4 : null,
                            clearMinRating: v != true,
                          );
                        }),
                      ),
                      Text(
                        '4★+',
                        style: BgFonts.body(
                            size: 13, color: p.ink, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => widget.onApply(
                      _draft.copyWith(maxDistanceKm: _distanceKm),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: p.orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l.apply,
                        style: BgFonts.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const _SectionLabel(
      {required this.text, this.padding = const EdgeInsets.only(bottom: 8)});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: BgFonts.body(
          size: 12,
          weight: FontWeight.w700,
          color: p.inkMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool on;
  final bool showCheck;
  final VoidCallback? onTap;
  const _Tag({
    required this.label,
    required this.on,
    required this.showCheck,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? p.orange : p.card,
          borderRadius: BorderRadius.circular(999),
          border: on ? null : Border.all(color: p.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheck) ...[
              const Icon(Icons.check, size: 11, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: BgFonts.body(
                size: 12,
                weight: FontWeight.w600,
                color: on ? Colors.white : p.ink,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
