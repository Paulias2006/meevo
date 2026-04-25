import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'browser_location_fallback.dart'
    if (dart.library.js_interop) 'browser_location_fallback_web.dart';
import 'meevo_api.dart';
import 'meevo_state.dart';
import 'models.dart';
import 'tsv_exporter.dart';

const _meevoPurple = Color(0xFF2F186C);
const _meevoPurpleLight = Color(0xFF442590);
const _meevoYellow = Color(0xFFF7CC17);
const _meevoSky = Color(0xFF87D7F9);
const _meevoText = Color(0xFF221944);
const _meevoMuted = Color(0xFF8E89A6);
const _meevoBackground = Colors.white;
const _meevoHeaderBlue = Colors.white;
const _meevoDeepBlue = Color(0xFF17238F);

const _heroCities = [
  'Lome',
  'Kara',
  'Sokode',
  'Kpalime',
  'Atakpame',
  'Dapaong',
  'Tsevie',
  'Aneho',
];

const _homeEventTypes = [
  'Mariage',
  'Conference',
  'Anniversaire',
  'Cocktail',
  'Garden Party',
  'Seminaire',
  'Gala',
  'Concert',
];

const _venueEventTypeOptions = [
  'Mariage',
  'Conference',
  'Anniversaire',
  'Cocktail',
  'Garden Party',
  'Seminaire',
  'Gala',
  'Concert',
  'Reception privee',
  'Bapteme',
  'Fiancailles',
  'Dot',
  'Baby shower',
  'Brunch',
  'Reunion',
  'Formation',
  'Lancement produit',
  'Conference de presse',
  'Diner de gala',
  'Exposition',
  'Salon',
  'Afterwork',
  'Team building',
  'Tournage',
  'Spectacle',
  'Ceremonie officielle',
];

const _venueAmenityOptions = [
  'Climatisation',
  'Parking',
  'Wifi',
  'Cuisine',
  'Cuisine equipee',
  'Traiteur integre',
  'Chaises',
  'Tables',
  'Sono',
  'Micro',
  'Eclairage',
  'Scene',
  'Videoprojecteur',
  'Ecran LED',
  'Decoration',
  'Groupe electrogene',
  'Securite',
  'Camera de surveillance',
  'Toilettes',
  'Toilettes VIP',
  'Acces PMR',
  'Loges',
  'Vestiaire',
  'Piscine',
  'Jardin',
  'Terrasse',
  'Hebergement',
  'Restauration',
  'Bar',
  'Service nettoyage',
  'Air libre',
  'Podium',
  'Piste de danse',
  'Mobilier VIP',
  'Espace enfants',
];

String _normalizedLabelKey(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String _resolveSelectableValue(
  String? candidate,
  List<String> allowedValues, {
  String? fallback,
}) {
  final safeFallback = fallback ?? allowedValues.first;

  if (candidate == null || candidate.trim().isEmpty) {
    return safeFallback;
  }

  final normalizedCandidate = _normalizedLabelKey(candidate);
  for (final value in allowedValues) {
    if (_normalizedLabelKey(value) == normalizedCandidate) {
      return value;
    }
  }

  return safeFallback;
}

String _canonicalHeroCity(String? city, {bool allowAllTogo = false}) {
  final values = allowAllTogo
      ? const ['Tout le Togo', ..._heroCities]
      : _heroCities;
  return _resolveSelectableValue(city, values, fallback: values.first);
}

class MeevoApp extends StatelessWidget {
  const MeevoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _meevoPurple,
        primary: _meevoPurple,
        secondary: _meevoYellow,
      ),
      scaffoldBackgroundColor: _meevoBackground,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: _meevoText,
        displayColor: _meevoText,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meevo',
      theme: theme.copyWith(
        chipTheme: theme.chipTheme.copyWith(
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      home: const MeevoRootScreen(),
    );
  }
}

class MeevoRootScreen extends StatelessWidget {
  const MeevoRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeevoState>(
      builder: (context, state, _) {
        if (state.isBootstrapping) {
          final useAndroidSplash =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
          if (useAndroidSplash) {
            return const _AndroidBootSplash();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _meevoPurple)),
          );
        }

        final width = MediaQuery.sizeOf(context).width;
        final isDesktop = width >= 980;

        return isDesktop ? const _DesktopShell() : const _MobileShell();
      },
    );
  }
}

class _AndroidBootSplash extends StatefulWidget {
  const _AndroidBootSplash();

  @override
  State<_AndroidBootSplash> createState() => _AndroidBootSplashState();
}

class _AndroidBootSplashState extends State<_AndroidBootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoGlow;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _logoGlow = Tween<double>(
      begin: 0.18,
      end: 0.34,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _textFade = Tween<double>(
      begin: 0.58,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF160A45),
                  Color(0xFF2F186C),
                  Color(0xFF442590),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -60,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _meevoYellow.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -90,
                  left: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 124,
                            height: 124,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: [
                                BoxShadow(
                                  color: _meevoYellow.withValues(
                                    alpha: _logoGlow.value,
                                  ),
                                  blurRadius: 34,
                                  spreadRadius: 6,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/logo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        FadeTransition(
                          opacity: _textFade,
                          child: Column(
                            children: [
                              Text(
                                'Meevo',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'La plateforme evenementielle du Togo',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 34),
                        Container(
                          width: 146,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Align(
                            alignment: Alignment(
                              -1 + (_controller.value * 2),
                              0,
                            ),
                            child: Container(
                              width: 58,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _meevoYellow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _DesktopShell extends StatelessWidget {
  const _DesktopShell();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    return _StateToastListener(
      child: Scaffold(
        body: Column(
          children: [
            _DesktopTopBar(state: state, isHome: state.pageIndex == 0),
            Expanded(
              child: IndexedStack(
                index: state.pageIndex,
                children: const [
                  _HomePage(isDesktop: true),
                  _SearchPage(isDesktop: true),
                  _BookingsPage(isDesktop: true),
                  _ProfilePage(isDesktop: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();

    return _StateToastListener(
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: state.pageIndex,
            children: const [
              _HomePage(isDesktop: false),
              _SearchPage(isDesktop: false),
              _BookingsPage(isDesktop: false),
              _ProfilePage(isDesktop: false),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _FloatingBottomNav(
            selectedIndex: state.pageIndex,
            isPartnerMode: state.hasPartnerAccess,
            onSelected: state.setPageIndex,
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.state,
    this.isHome = false,
  });

  final MeevoState state;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    void navigateTo(int index) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      state.setPageIndex(index);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isHome ? Colors.white : _meevoHeaderBlue,
        border: const Border(bottom: BorderSide(color: Color(0xFFEAE7F7))),
      ),
      child: Row(
        children: [
          const _MeevoLogo(compact: true),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => navigateTo(0),
                  child: const Text('Accueil'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => navigateTo(1),
                  child: const Text('Salles'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => navigateTo(2),
                  child: const Text('Reservations'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _openProviders(context, isDesktop: true),
                  child: const Text('Prestataires'),
                ),
                if (state.needsPartnerSubscription) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _openPartnerSubscriptionPage(context),
                    child: const Text('Abonnement'),
                  ),
                ],
                if (state.hasPartnerAccess) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _openDashboard(context),
                    child: const Text('Dashboard'),
                  ),
                ],
                if (state.isAdmin) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _openAdminDashboard(context),
                    child: const Text('Admin'),
                  ),
                ],
              ],
            ),
          ),
          if (state.isAuthenticated)
            _HeaderAvatarMenu(state: state)
          else ...[
            OutlinedButton(
              onPressed: () {
                state.setAuthMode('login');
                state.setPageIndex(3);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _meevoPurple,
                side: const BorderSide(color: _meevoPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
              ),
              child: const Text('Se connecter'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                state.setAuthMode('register');
                state.setPageIndex(3);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _meevoYellow,
                foregroundColor: _meevoText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
              ),
              child: const Text("S'inscrire"),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderAvatarMenu extends StatelessWidget {
  const _HeaderAvatarMenu({required this.state});

  final MeevoState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu utilisateur',
      onSelected: (value) {
        if (value == 'account') {
          state.setPageIndex(3);
          return;
        }
        if (value == 'subscription') {
          _openPartnerSubscriptionPage(context);
          return;
        }
        if (value == 'dashboard') {
          _openDashboard(context);
          return;
        }
        if (value == 'admin') {
          _openAdminDashboard(context);
          return;
        }

        if (value == 'logout') {
          state.logout();
        }
      },
      itemBuilder: (context) => [
        if (state.needsPartnerSubscription)
          const PopupMenuItem<String>(
            value: 'subscription',
            child: Text('Abonnement partenaire'),
          ),
        if (state.hasPartnerAccess)
          const PopupMenuItem<String>(
            value: 'dashboard',
            child: Text('Dashboard'),
          ),
        if (state.isAdmin)
          const PopupMenuItem<String>(value: 'admin', child: Text('Admin')),
        const PopupMenuItem<String>(
          value: 'account',
          child: Text('Mon compte'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Se deconnecter'),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [_meevoPurple, _meevoPurpleLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            _userInitials(state.currentUser?.fullName ?? ''),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final sectionWidth = isDesktop ? 1280.0 : double.infinity;

    return RefreshIndicator(
      color: _meevoPurple,
      onRefresh: () async {
        await state.loadHome();
        await state.searchVenues();
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (!isDesktop)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _MobileTopBar(useBlueBackground: false),
            ),
          _HeroSection(isDesktop: isDesktop, state: state),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sectionWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 20 : 18,
                  isDesktop ? 54 : 32,
                  isDesktop ? 20 : 18,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EventTypeSection(isDesktop: isDesktop),
                    const SizedBox(height: 34),
                    _CityExplorerSection(isDesktop: isDesktop),
                    const SizedBox(height: 42),
                    _SectionHeader(
                      title: 'Salles populaires',
                      subtitle:
                          'Les lieux les plus demandes et verifies sur Meevo.',
                      trailingLabel: 'Voir toutes',
                      onTap: () => state.setPageIndex(1),
                    ),
                    const SizedBox(height: 18),
                    if (state.isHomeLoading &&
                        state.homeData.featuredVenues.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (state.homeData.featuredVenues.isEmpty)
                      const _EmptyStateCard(
                        title: 'Aucune salle disponible pour le moment',
                        subtitle:
                            'Quand un partenaire valide sa salle, elle apparaitra ici automatiquement sans contenu simule.',
                      )
                    else
                      _VenueGrid(
                        venues: state.homeData.featuredVenues,
                        isDesktop: isDesktop,
                        mobileColumns: 3,
                      ),
                    const SizedBox(height: 36),
                    _ProvidersSection(isDesktop: isDesktop),
                    const SizedBox(height: 42),
                    _WhyChooseSection(isDesktop: isDesktop),
                    const SizedBox(height: 54),
                  ],
                ),
              ),
            ),
          ),
          _PartnerCalloutSection(isDesktop: isDesktop),
          const _FooterSection(),
        ],
      ),
    );
  }
}

class _SearchPage extends StatelessWidget {
  const _SearchPage({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();

    return RefreshIndicator(
      color: _meevoPurple,
      onRefresh: () => state.searchVenues(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          isDesktop ? 20 : 16,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          if (!isDesktop)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _MobileTopBar(showTitleOnly: true),
            ),
          if (!isDesktop) ...[
            const SizedBox(height: 4),
            const Text(
              'Salles',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Trouvez rapidement le bon lieu',
              style: TextStyle(color: _meevoMuted),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchControls(
                    initialFilters: state.filters,
                    isDesktop: isDesktop,
                    onSubmitted: (filters) async {
                      await state.searchVenues(newFilters: filters);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${state.filters.query.trim().isNotEmpty ? state.searchResults.length : (state.searchPagination.total == 0 ? state.searchResults.length : state.searchPagination.total)} salles trouvees',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _meevoText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.isSearchLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: _meevoPurple),
                      ),
                    )
                  else if (state.searchResults.isEmpty)
                    const _EmptyStateCard(
                      title: 'Aucune salle trouvee pour ce filtre',
                      subtitle:
                          'La recherche affiche uniquement les lieux reels publies dans MongoDB. Ajustez la ville, la date ou la capacite.',
                    )
                  else
                    Column(
                      children: [
                        _VenueGrid(
                          venues: state.searchResults,
                          isDesktop: isDesktop,
                        ),
                        if (state.searchPagination.totalPages > 1) ...[
                          const SizedBox(height: 18),
                          _PaginationBar(
                            page: state.searchPagination.page,
                            totalPages: state.searchPagination.totalPages,
                            onPageChanged: (page) {
                              state.searchVenues(
                                newFilters: state.filters.copyWith(page: page),
                              );
                            },
                          ),
                        ],
                      ],
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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final pages = _buildPages();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: _meevoPurple,
        ),
        const SizedBox(width: 6),
        ...pages.map((value) {
          if (value == null) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('...'),
            );
          }

          final isSelected = value == page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPageChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _meevoPurple
                      : _meevoPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: isSelected ? Colors.white : _meevoPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        IconButton(
          onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
          color: _meevoPurple,
        ),
      ],
    );
  }

  List<int?> _buildPages() {
    if (totalPages <= 7) {
      return List<int?>.generate(totalPages, (index) => index + 1);
    }

    final pages = <int?>[1];
    final start = max(2, page - 1);
    final end = min(totalPages - 1, page + 1);

    if (start > 2) {
      pages.add(null);
    }
    for (var value = start; value <= end; value++) {
      pages.add(value);
    }
    if (end < totalPages - 1) {
      pages.add(null);
    }
    pages.add(totalPages);
    return pages;
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    Future<void> confirmDelete(BookingItem booking) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Supprimer la reservation ?'),
          content: const Text(
            'Cette reservation sera supprimee de votre historique.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await state.deleteBooking(booking);
      }
    }

    return RefreshIndicator(
      color: _meevoPurple,
      onRefresh: state.isAuthenticated
          ? () => state.loadBookings()
          : () async {},
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          isDesktop ? 24 : 18,
          isDesktop ? 24 : 18,
          30,
        ),
        children: [
          if (!isDesktop)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _MobileTopBar(showTitleOnly: true),
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes reservations',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.realtimeConnected
                        ? 'Suivi temps reel actif.'
                        : 'Les mises a jour temps reel seront visibles apres connexion au backend.',
                    style: const TextStyle(color: _meevoMuted),
                  ),
                  const SizedBox(height: 18),
                  if (!state.isAuthenticated)
                    _AuthRequiredCard(
                      onPressed: () {
                        state.setAuthMode('login');
                        state.setPageIndex(3);
                      },
                    )
                  else if (state.isBookingsLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: _meevoPurple),
                      ),
                    )
                  else if (state.bookings.isEmpty)
                    const _EmptyStateCard(
                      title: 'Aucune reservation enregistree',
                      subtitle:
                          'Quand vous reservez une salle reelle, elle apparaitra ici avec son statut.',
                    )
                  else
                    ...state.bookings.map(
                      (booking) => _BookingCard(
                        booking,
                        onDelete: () => confirmDelete(booking),
                      ),
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

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 18,
        isDesktop ? 26 : 18,
        isDesktop ? 24 : 18,
        30,
      ),
      children: [
        if (!isDesktop)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _MobileTopBar(showTitleOnly: true),
          ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  state.hasVenuePartnerAccess || state.hasProviderPartnerAccess
                  ? 1180
                  : 520,
            ),
            child: state.isAuthenticated
                ? Column(
                    children: [
                      _AccountCard(
                        user: state.currentUser!,
                        realtimeConnected: state.realtimeConnected,
                        onLogout: state.logout,
                      ),
                      const SizedBox(height: 18),
                      _ProfileBookingsSection(
                        state: state,
                        isDesktop: isDesktop,
                      ),
                      const SizedBox(height: 18),
                      if (state.hasVenuePartnerAccess ||
                          state.hasProviderPartnerAccess)
                        _DashboardShortcutCard(
                          onOpen: () => _openDashboard(context),
                        )
                      else if (state.needsPartnerSubscription)
                        const _PartnerSubscriptionPromptCard()
                      else
                        const _PartnerUpgradeCard(),
                    ],
                  )
                : _AuthCard(
                    initialMode: state.authMode,
                    isLoading: state.isAuthLoading,
                    onModeChanged: state.setAuthMode,
                    onLogin: state.login,
                    onRegister: state.register,
                  ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBookingsSection extends StatelessWidget {
  const _ProfileBookingsSection({required this.state, required this.isDesktop});

  final MeevoState state;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final bookings = state.bookings;
    final preview = bookings.length > 3 ? bookings.take(3).toList() : bookings;

    Future<void> confirmDelete(BookingItem booking) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Supprimer la reservation ?'),
          content: const Text(
            'Cette reservation sera supprimee de votre historique.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await state.deleteBooking(booking);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mes reservations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => state.setPageIndex(2),
                child: const Text('Voir toutes'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.isBookingsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: _meevoPurple),
              ),
            )
          else if (bookings.isEmpty)
            const _EmptyStateCard(
              title: 'Aucune reservation',
              subtitle:
                  'Quand vous reservez une salle reelle, elle apparaitra ici.',
            )
          else
            ...preview.map(
              (booking) => _BookingCard(
                booking,
                onDelete: isDesktop ? null : () => confirmDelete(booking),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.isDesktop, required this.state});

  final bool isDesktop;
  final MeevoState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.homeData.stats;

    return SizedBox(
      width: double.infinity,
      child: Container(
        constraints: BoxConstraints(minHeight: isDesktop ? 560 : 620),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/background_acceuil.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _meevoPurple.withValues(alpha: isDesktop ? 0.94 : 0.78),
                _meevoPurpleLight.withValues(alpha: isDesktop ? 0.88 : 0.74),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 34 : 22,
              isDesktop ? 20 : 24,
              isDesktop ? 34 : 22,
              isDesktop ? 36 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: isDesktop ? 0 : 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _meevoYellow.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'La 1ere plateforme evenementielle au Togo',
                    style: TextStyle(
                      color: _meevoYellow.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: isDesktop ? 13 : 12,
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 34 : 28),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 980 : 360),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        height: isDesktop ? 0.96 : 1.02,
                        fontWeight: FontWeight.w800,
                        fontSize: isDesktop ? 72 : 38,
                        color: Colors.white,
                      ),
                      children: const [
                        TextSpan(text: 'Organisez votre\n'),
                        TextSpan(text: 'evenement '),
                        TextSpan(
                          text: 'partout au Togo',
                          style: TextStyle(color: _meevoYellow),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 360),
                  child: Text(
                    'Trouvez la salle parfaite a Lome, Kara, Sokode, Kpalime et dans tout le pays. Reservez en quelques clics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: isDesktop ? 17 : 15,
                      height: 1.55,
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 34 : 28),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1040 : double.infinity,
                  ),
                  child: _HeroSearchCard(
                    isDesktop: isDesktop,
                    filters: state.filters,
                    onSearch: (filters) async {
                      await state.searchVenues(newFilters: filters);
                      state.setPageIndex(1);
                    },
                  ),
                ),
                SizedBox(height: isDesktop ? 38 : 30),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: isDesktop ? 54 : 28,
                  runSpacing: 14,
                  children: [
                    _StatItem(value: '${stats.venuesCount}+', label: 'Salles'),
                    _StatItem(value: '${stats.citiesCount}', label: 'Villes'),
                    _StatItem(
                      value: '${stats.bookingsCount}+',
                      label: 'Reservations',
                    ),
                    _StatItem(value: '24/7', label: 'Temps reel'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSearchCard extends StatefulWidget {
  const _HeroSearchCard({
    required this.isDesktop,
    required this.filters,
    required this.onSearch,
  });

  final bool isDesktop;
  final VenueSearchFilters filters;
  final Future<void> Function(VenueSearchFilters filters) onSearch;

  @override
  State<_HeroSearchCard> createState() => _HeroSearchCardState();
}

class _HeroSearchCardState extends State<_HeroSearchCard> {
  late String _city;
  late DateTime? _date;
  late int _guests;

  @override
  void initState() {
    super.initState();
    _city = _canonicalHeroCity(widget.filters.city, allowAllTogo: true);
    _date = widget.filters.date;
    _guests = widget.filters.guests;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.isDesktop;
    final isCompact = !isDesktop;
    final cityLabel = isCompact && _city == 'Tout le Togo' ? 'Togo' : _city;
    final guestLabel = _guests <= 0
        ? 'Combien ?'
        : '${_guests.toString()} pers.';
    final searchLabel = isCompact ? 'Go' : 'Rechercher';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 12,
        vertical: isDesktop ? 12 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  child: _SearchFieldTile(
                    label: 'Ville',
                    value: _city,
                    icon: Icons.apartment_rounded,
                    onTap: _pickCity,
                    showChevron: true,
                  ),
                ),
                const _DividerLine(),
                Expanded(
                  child: _SearchFieldTile(
                    label: 'Date',
                    value: _date == null ? 'Choisir' : _formatShortDate(_date!),
                    icon: Icons.calendar_month_outlined,
                    onTap: _pickDate,
                    showChevron: true,
                  ),
                ),
                const _DividerLine(),
                Expanded(
                  child: _SearchFieldTile(
                    label: 'Invites',
                    value: _guests <= 0 ? 'Combien ?' : '$_guests personnes',
                    icon: Icons.groups_2_outlined,
                    onTap: _changeGuests,
                    showChevron: true,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _meevoYellow,
                    foregroundColor: _meevoText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher'),
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    SizedBox(
                      width: 126,
                      child: _SearchFieldTile(
                        label: 'Ville',
                        value: cityLabel,
                        icon: Icons.apartment_rounded,
                        onTap: _pickCity,
                        showChevron: true,
                        compact: isCompact,
                      ),
                    ),
                    const _DividerLine(),
                    SizedBox(
                      width: 118,
                      child: _SearchFieldTile(
                        label: 'Invites',
                        value: guestLabel,
                        icon: Icons.groups_2_outlined,
                        onTap: _changeGuests,
                        showChevron: true,
                        compact: isCompact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 104,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _meevoYellow,
                          foregroundColor: _meevoText,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.search),
                        label: Text(searchLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _submit() async {
    final includeDate = widget.isDesktop;
    await widget.onSearch(
      widget.filters.copyWith(
        city: _city,
        date: includeDate ? _date : null,
        clearDate: !includeDate || _date == null,
        guests: _guests,
        page: 1,
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _date ?? DateTime.now().add(const Duration(days: 7)),
    );

    if (pickedDate != null) {
      setState(() {
        _date = pickedDate;
      });
    }
  }

  Future<void> _pickCity() async {
    final result = await _showSelectionSheet<String>(
      context,
      title: 'Choisir la ville',
      values: const ['Tout le Togo', ..._heroCities],
      labelBuilder: (value) => value,
    );

    if (result != null) {
      setState(() {
        _city = result;
      });
    }
  }

  Future<void> _changeGuests() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              const Text(
                'Combien d invites ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...[100, 200, 300, 500, 800].map(
                (value) => ListTile(
                  title: Text('$value personnes'),
                  onTap: () => Navigator.pop(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _guests = result;
      });
    }
  }
}

class _SearchControls extends StatefulWidget {
  const _SearchControls({
    required this.initialFilters,
    required this.isDesktop,
    required this.onSubmitted,
  });

  final VenueSearchFilters initialFilters;
  final bool isDesktop;
  final Future<void> Function(VenueSearchFilters filters) onSubmitted;

  @override
  State<_SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends State<_SearchControls> {
  static const _cities = ['Tout le Togo', ..._heroCities];

  static const _types = [
    'Mariage',
    'Conference',
    'Anniversaire',
    'Cocktail',
    'Garden Party',
    'Seminaire',
    'Gala',
  ];

  late final TextEditingController _controller;
  late String _city;
  late String _type;
  late DateTime? _date;
  late String? _startTime;
  late String? _endTime;
  late int _guests;
  late int? _maxPrice;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFilters.query);
    _controller.addListener(_onQueryChanged);
    _city = _canonicalHeroCity(widget.initialFilters.city, allowAllTogo: true);
    _type = widget.initialFilters.eventType;
    _date = widget.initialFilters.date;
    _startTime = widget.initialFilters.startTime;
    _endTime = widget.initialFilters.endTime;
    _guests = widget.initialFilters.guests;
    _maxPrice = widget.initialFilters.maxPrice;
  }

  @override
  void didUpdateWidget(covariant _SearchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.initialFilters;
    final current = widget.initialFilters;

    final hasExternalFilterChange =
        previous.query != current.query ||
        previous.city != current.city ||
        previous.eventType != current.eventType ||
        previous.date != current.date ||
        previous.startTime != current.startTime ||
        previous.endTime != current.endTime ||
        previous.guests != current.guests ||
        previous.maxPrice != current.maxPrice;

    if (!hasExternalFilterChange) {
      return;
    }

    if (_controller.text != current.query) {
      _controller.text = current.query;
    }

    _city = _canonicalHeroCity(current.city, allowAllTogo: true);
    _type = current.eventType;
    _date = current.date;
    _startTime = current.startTime;
    _endTime = current.endTime;
    _guests = current.guests;
    _maxPrice = current.maxPrice;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: widget.isDesktop
            ? _buildDesktopFilters()
            : _buildMobileFilters(),
      ),
    );
  }

  Widget _buildDesktopFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Rechercher une salle...',
                  filled: true,
                  fillColor: _meevoBackground,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _meevoYellow,
                foregroundColor: _meevoText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              child: const Text('Rechercher'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reinitialiser'),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _cities
                .map(
                  (city) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _city == city,
                      onSelected: (_) {
                        setState(() => _city = city);
                        _scheduleAutoSubmit();
                      },
                      label: Text(city),
                      selectedColor: _meevoYellow.withValues(alpha: 0.3),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _meevoPurple,
                  side: const BorderSide(color: Color(0xFFD6D0F0)),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _date == null
                      ? 'Date'
                      : DateFormat('dd/MM/yyyy').format(_date!),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickTime(isStart: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _meevoPurple,
                  side: const BorderSide(color: Color(0xFFD6D0F0)),
                ),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_startTime == null ? 'Debut' : _startTime!),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickTime(isStart: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _meevoPurple,
                  side: const BorderSide(color: Color(0xFFD6D0F0)),
                ),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_endTime == null ? 'Fin' : _endTime!),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickGuests,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _meevoPurple,
                  side: const BorderSide(color: Color(0xFFD6D0F0)),
                ),
                icon: const Icon(Icons.groups_2_outlined),
                label: Text(_guests <= 0 ? 'Capacite' : '$_guests+ places'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickMaxPrice,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _meevoPurple,
                  side: const BorderSide(color: Color(0xFFD6D0F0)),
                ),
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  _maxPrice == null
                      ? 'Budget max'
                      : '<= ${NumberFormat.compact().format(_maxPrice)} FCFA',
                ),
              ),
              const SizedBox(width: 8),
              ..._types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _type == type,
                    onSelected: (_) {
                      setState(() => _type = _type == type ? '' : type);
                      _scheduleAutoSubmit();
                    },
                    label: Text(type),
                    selectedColor: _meevoYellow.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reinitialiser les filtres'),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilters() {
    final cityLabel = _city == 'Tout le Togo' ? 'Togo' : _city;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Rechercher une salle...',
                  filled: true,
                  fillColor: _meevoBackground,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _meevoYellow,
                foregroundColor: _meevoText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
              ),
              child: const Text('Rechercher'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MobileFilterButton(
              icon: Icons.place_outlined,
              label: cityLabel,
              isSelected: _city != 'Tout le Togo',
              onTap: _pickCityFilter,
            ),
            _MobileFilterButton(
              icon: Icons.event_available_outlined,
              label: _type.isEmpty ? 'Evenement' : _type,
              isSelected: _type.isNotEmpty,
              onTap: _pickTypeFilter,
            ),
            _MobileFilterButton(
              icon: Icons.calendar_month_outlined,
              label: _date == null
                  ? 'Date'
                  : DateFormat('dd/MM').format(_date!),
              isSelected: _date != null,
              onTap: _pickDate,
            ),
            _MobileFilterButton(
              icon: Icons.schedule_outlined,
              label: _startTime == null ? 'Debut' : _startTime!,
              isSelected: _startTime != null,
              onTap: () => _pickTime(isStart: true),
            ),
            _MobileFilterButton(
              icon: Icons.schedule_outlined,
              label: _endTime == null ? 'Fin' : _endTime!,
              isSelected: _endTime != null,
              onTap: () => _pickTime(isStart: false),
            ),
            _MobileFilterButton(
              icon: Icons.groups_2_outlined,
              label: _guests <= 0 ? 'Capacite' : '$_guests+',
              isSelected: _guests > 0,
              onTap: _pickGuests,
            ),
            _MobileFilterButton(
              icon: Icons.payments_outlined,
              label: _maxPrice == null
                  ? 'Budget'
                  : '<= ${NumberFormat.compact().format(_maxPrice)}',
              isSelected: _maxPrice != null,
              onTap: _pickMaxPrice,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _date ?? DateTime.now().add(const Duration(days: 7)),
    );

    if (pickedDate != null) {
      setState(() => _date = pickedDate);
      _scheduleAutoSubmit();
    }
  }

  Future<void> _pickCityFilter() async {
    final result = await _showSelectionSheet<String>(
      context,
      title: 'Choisir la region / ville',
      values: _cities,
      labelBuilder: (value) => value,
    );

    if (result == null) return;

    setState(() => _city = result);
    _scheduleAutoSubmit();
  }

  Future<void> _pickTypeFilter() async {
    final result = await _showSelectionSheet<String>(
      context,
      title: 'Choisir le type d evenement',
      values: const ['Tous les evenements', ..._types],
      labelBuilder: (value) => value,
    );

    if (result == null) return;

    setState(() => _type = result == 'Tous les evenements' ? '' : result);
    _scheduleAutoSubmit();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = _parseTime(
      isStart ? _startTime : _endTime,
      fallbackHour: isStart ? 8 : 23,
      fallbackMinute: 0,
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

    final formatted = _formatTimeOfDay(pickedTime);

    setState(() {
      if (isStart) {
        _startTime = formatted;
        if (_endTime != null && _compareTimes(_endTime!, _startTime!) <= 0) {
          _endTime = _addOneHour(_startTime!);
        }
      } else {
        _endTime = formatted;
        if (_startTime != null && _compareTimes(_endTime!, _startTime!) <= 0) {
          _startTime = _subtractOneHour(_endTime!);
        }
      }
    });

    _scheduleAutoSubmit();
  }

  Future<void> _submit() async {
    await widget.onSubmitted(
      widget.initialFilters.copyWith(
        query: _controller.text.trim(),
        city: _city,
        eventType: _type,
        date: _date,
        clearDate: _date == null,
        startTime: _startTime,
        endTime: _endTime,
        clearTime: _startTime == null || _endTime == null,
        guests: _guests,
        maxPrice: _maxPrice,
        clearMaxPrice: _maxPrice == null,
        page: 1,
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _controller.text = '';
      _city = _cities.first;
      _type = '';
      _date = null;
      _startTime = null;
      _endTime = null;
      _guests = 0;
      _maxPrice = null;
    });
    _submit();
  }

  void _onQueryChanged() {
    _scheduleAutoSubmit();
  }

  void _scheduleAutoSubmit() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _submit();
    });
  }

  Future<void> _pickGuests() async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              const Text(
                'Capacite minimale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Toutes les capacites'),
                onTap: () => Navigator.pop<int?>(context, 0),
              ),
              ...[50, 100, 200, 300, 500, 800].map(
                (value) => ListTile(
                  title: Text('$value places et plus'),
                  onTap: () => Navigator.pop<int?>(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _guests = result);
      _scheduleAutoSubmit();
    }
  }

  Future<void> _pickMaxPrice() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              const Text(
                'Budget maximum',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Tous les budgets'),
                onTap: () => Navigator.pop<String?>(context, 'all'),
              ),
              ...[150000, 250000, 400000, 600000, 1000000].map(
                (value) => ListTile(
                  title: Text(
                    'Jusqu a ${_formatMoney(value.toDouble(), 'FCFA')}',
                  ),
                  onTap: () =>
                      Navigator.pop<String?>(context, value.toString()),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _maxPrice = result == 'all' ? null : int.tryParse(result);
    });
    _scheduleAutoSubmit();
  }
}

class _VenueGrid extends StatelessWidget {
  const _VenueGrid({
    required this.venues,
    required this.isDesktop,
    this.mobileColumns,
  });

  final List<Venue> venues;
  final bool isDesktop;
  final int? mobileColumns;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: venues.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 334,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
        ),
        itemBuilder: (context, index) =>
            _VenueCard(venue: venues[index], isDesktop: true),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = mobileColumns ?? (screenWidth >= 520 ? 4 : 3);
    final cardHeight = columns >= 4
        ? (screenWidth < 620 ? 168.0 : 178.0)
        : (screenWidth < 390 ? 184.0 : 194.0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: venues.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: cardHeight,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _CompactVenueCard(venue: venues[index]),
    );
  }
}

class _ProvidersSection extends StatelessWidget {
  const _ProvidersSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final providers = context.watch<MeevoState>().providers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Prestataires populaires',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _meevoDeepBlue,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Traiteurs, sonorisateurs, hotesses et location verifies.',
                    style: TextStyle(color: _meevoMuted, height: 1.55),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openProviders(context, isDesktop: isDesktop),
              child: const Text('Voir tous'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (providers.isEmpty)
          const _EmptyStateCard(
            title: 'Aucun prestataire disponible',
            subtitle:
                'Les prestataires partenaires apparaitront ici des qu ils sont publies.',
          )
        else if (isDesktop)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: providers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 334,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
            ),
            itemBuilder: (context, index) =>
                _ProviderCard(provider: providers[index]),
          )
        else
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final columns = screenWidth >= 520 ? 4 : 3;
              final cardHeight = columns >= 4
                  ? (screenWidth < 620 ? 168.0 : 178.0)
                  : (screenWidth < 390 ? 184.0 : 194.0);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: providers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: cardHeight,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) =>
                    _CompactProviderCard(provider: providers[index]),
              );
            },
          ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});

  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.photoUrl ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openProviderDetails(context, provider),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: 198,
                    width: double.infinity,
                    child: imageUrl.isEmpty
                        ? _placeholderMedia('Photo indisponible')
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Photo indisponible'),
                          ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    constraints: const BoxConstraints(maxWidth: 160),
                    decoration: BoxDecoration(
                      color: _meevoYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      provider.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xCC372678)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatMoney(provider.startingPrice, provider.currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _meevoSky,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _meevoMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: _meevoYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider.rating.toStringAsFixed(1),
                        style: const TextStyle(color: _meevoMuted),
                      ),
                      if (provider.reviewCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${provider.reviewCount})',
                          style: const TextStyle(color: _meevoMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactProviderCard extends StatelessWidget {
  const _CompactProviderCard({required this.provider});

  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.photoUrl ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openProviderDetails(context, provider),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 94,
                    width: double.infinity,
                    child: imageUrl.isEmpty
                        ? _placeholderMedia('Photo')
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Photo indisponible'),
                          ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    constraints: const BoxConstraints(maxWidth: 110),
                    decoration: BoxDecoration(
                      color: _meevoYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      provider.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xCC372678)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatCompactMoney(provider.startingPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _meevoSky,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          provider.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _meevoMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: _meevoYellow,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        provider.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _meevoMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (provider.reviewCount > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          '(${provider.reviewCount})',
                          style: const TextStyle(
                            color: _meevoMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.isDesktop});

  final Venue venue;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _VenueDetailsPage(venue: venue),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: isDesktop ? 198 : 224,
                    width: double.infinity,
                    child: venue.primaryImage.isEmpty
                        ? _placeholderMedia('Aucune photo')
                        : Image.network(
                            venue.primaryImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Media indisponible'),
                          ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _meevoYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Instant',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xCC372678)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      _formatMoney(venue.startingPrice, venue.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        size: 16,
                        color: _meevoSky,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _meevoMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.people_outline,
                        size: 16,
                        color: _meevoMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${venue.capacity}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: _meevoYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${venue.rating.toStringAsFixed(1)} (${venue.reviewCount})',
                        style: const TextStyle(color: _meevoMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactVenueCard extends StatelessWidget {
  const _CompactVenueCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _VenueDetailsPage(venue: venue),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 94,
                    width: double.infinity,
                    child: venue.primaryImage.isEmpty
                        ? _placeholderMedia('Aucune photo')
                        : Image.network(
                            venue.primaryImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Media indisponible'),
                          ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _meevoYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Live',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xCC372678)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      _formatCompactMoney(venue.startingPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _meevoSky,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          venue.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _meevoMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (venue.rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: _meevoYellow,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          venue.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _meevoMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (venue.reviewCount > 0) ...[
                          const SizedBox(width: 2),
                          Text(
                            '(${venue.reviewCount})',
                            style: const TextStyle(
                              color: _meevoMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                      ],
                      const Icon(
                        Icons.people_outline,
                        size: 12,
                        color: _meevoMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${venue.capacity}',
                        style: const TextStyle(
                          color: _meevoMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueDetailsPage extends StatefulWidget {
  const _VenueDetailsPage({required this.venue});

  final Venue venue;

  @override
  State<_VenueDetailsPage> createState() => _VenueDetailsPageState();
}

class _VenueDetailsPageState extends State<_VenueDetailsPage> {
  late DateTime _selectedDate;
  late DateTime _selectedMonth;
  VenueAvailability _availability = const VenueAvailability.empty();
  bool _isAvailabilityLoading = true;
  bool _hasAvailabilityError = false;
  bool _showMonthlyCalendar = false;
  String _selectedGalleryPhoto = '';
  Timer? _stateRefreshDebounce;
  MeevoState? _meevoState;
  int _lastRealtimeVersion = -1;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    unawaited(_loadAvailability());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<MeevoState>();
    if (identical(_meevoState, state)) {
      return;
    }
    _meevoState?.removeListener(_handleRealtimeSignal);
    _meevoState = state;
    _lastRealtimeVersion = state.realtimeUpdateVersion;
    _meevoState?.addListener(_handleRealtimeSignal);
  }

  @override
  void dispose() {
    _stateRefreshDebounce?.cancel();
    _meevoState?.removeListener(_handleRealtimeSignal);
    super.dispose();
  }

  Future<void> _loadAvailability({bool forceRefresh = false}) async {
    if (!_hasAvailabilityError) {
      setState(() => _isAvailabilityLoading = true);
    }

    try {
      final availability = await context.read<MeevoState>().fetchAvailability(
        venueId: widget.venue.id,
        date: _selectedDate,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;
      setState(() {
        _availability = availability;
        _hasAvailabilityError = false;
        _isAvailabilityLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasAvailabilityError = true;
        _isAvailabilityLoading = false;
      });
    }
  }

  void _handleRealtimeSignal() {
    final state = _meevoState;
    if (state == null || state.realtimeUpdateVersion == _lastRealtimeVersion) {
      return;
    }

    _lastRealtimeVersion = state.realtimeUpdateVersion;
    _stateRefreshDebounce?.cancel();
    _stateRefreshDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(_loadAvailability(forceRefresh: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<MeevoState>();
    final galleryPhotos = _buildGalleryPhotos(venue);
    final summary = _VenueLiveSummary.fromAvailability(
      _availability,
      _selectedDate,
    );

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: Text(venue.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _VenueHeroMedia(
            venue: venue,
            height: isDesktop ? 340 : 230,
            heroImageOverride: _selectedGalleryPhoto.isNotEmpty
                ? _selectedGalleryPhoto
                : null,
            onOpenMaps: _buildVenueMapsUri(venue) == null
                ? null
                : () => _launchUrl(_buildVenueMapsUri(venue)!),
            onReserve: () {
              if (!state.isAuthenticated) {
                state.setAuthMode('login');
                state.setPageIndex(3);
                return;
              }
              showDialog<void>(
                context: context,
                builder: (_) => _BookingDialog(venue: venue),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            venue.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            venue.shortDescription?.isNotEmpty == true
                ? venue.shortDescription!
                : 'Fiche reelle creee par un partenaire Meevo.',
            style: const TextStyle(color: _meevoMuted, height: 1.55),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(
                icon: Icons.apartment_outlined,
                label: venue.venueType,
              ),
              _DetailChip(
                icon: Icons.location_on_outlined,
                label: venue.locationLabel,
              ),
              _DetailChip(
                icon: Icons.people_outline,
                label: '${venue.capacity} places',
              ),
              _DetailChip(
                icon: Icons.payments_outlined,
                label: _formatMoney(venue.startingPrice, venue.currency),
              ),
              if (venue.rating > 0)
                _DetailChip(
                  icon: Icons.star_rounded,
                  label: venue.rating.toStringAsFixed(1),
                ),
              _DetailChip(
                icon: state.realtimeConnected
                    ? Icons.wifi_tethering
                    : Icons.wifi_tethering_off,
                label: state.realtimeConnected
                    ? 'Temps reel actif'
                    : 'Actualisation auto',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (galleryPhotos.isNotEmpty) ...[
            _SectionPanel(
              title: 'Galerie',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Touchez une photo pour l afficher en grand.',
                    style: const TextStyle(color: _meevoMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: isDesktop ? 140 : 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: galleryPhotos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final photo = galleryPhotos[index];
                        final isSelected = _selectedGalleryPhoto.isEmpty
                            ? photo == venue.primaryImage
                            : photo == _selectedGalleryPhoto;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGalleryPhoto =
                                  _selectedGalleryPhoto == photo ? '' : photo;
                            });
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? _meevoYellow
                                    : const Color(0xFFE6E1F5),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 1.35,
                                child: Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _placeholderMedia('Image indisponible'),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          _SectionPanel(
            title: 'Planning temps reel',
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: _meevoBackground,
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: _meevoPurple,
                  ),
                  title: Text(
                    'Disponibilite du ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Touchez pour consulter un autre jour.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickAvailabilityDate,
                ),
                const SizedBox(height: 14),
                if (_isAvailabilityLoading && _availability.date.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(color: _meevoPurple),
                  )
                else if (_hasAvailabilityError && _availability.date.isEmpty)
                  const _ScheduleEmptyState(
                    title: 'Planning indisponible',
                    subtitle:
                        'Le planning n a pas pu etre charge pour cette date.',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LiveStatusBanner(summary: summary),
                      if (_isAvailabilityLoading) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(
                          minHeight: 3,
                          color: _meevoYellow,
                          backgroundColor: Color(0xFFF2F0FA),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _BusinessHoursBanner(
                        businessHours: _availability.businessHours,
                        isBlockedDate: _availability.blockedDates.contains(
                          _formatApiDate(_selectedDate),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AvailabilityTimeline(
                        availability: _availability,
                        emptyLabel:
                            'Aucun conflit sur cette date. Le lieu est libre sur toute la plage horaire.',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Calendrier mensuel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(
                      () => _showMonthlyCalendar = !_showMonthlyCalendar,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _meevoPurple,
                    side: const BorderSide(color: Color(0xFFD6D0F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    _showMonthlyCalendar
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _showMonthlyCalendar
                        ? 'Masquer le calendrier'
                        : 'Afficher le calendrier',
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 240),
                  crossFadeState: _showMonthlyCalendar
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _shiftMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _shiftMonth(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<MonthlyAvailability>(
                        future: state.fetchMonthlyAvailability(
                          venueId: venue.id,
                          month: _selectedMonth,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: _meevoPurple,
                              ),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return const _ScheduleEmptyState(
                              title: 'Calendrier indisponible',
                              subtitle:
                                  'Impossible de charger le calendrier du mois.',
                            );
                          }

                          return _MiniMonthlyAvailabilityGrid(
                            month: _selectedMonth,
                            availability: snapshot.data!,
                            onDayTap: (date) =>
                                _showMonthlyDayDetails(date, snapshot.data!),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Description',
            child: Text(
              venue.description?.isNotEmpty == true
                  ? venue.description!
                  : 'Cette salle a ete ajoutee sans description detaillee. Le partenaire pourra la completer depuis le back-office Meevo.',
              style: const TextStyle(color: _meevoMuted, height: 1.65),
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Types d evenements',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: venue.eventTypes.isEmpty
                  ? const [
                      Text(
                        'Aucun type precise.',
                        style: TextStyle(color: _meevoMuted),
                      ),
                    ]
                  : venue.eventTypes
                        .map((item) => Chip(label: Text(item)))
                        .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Equipements',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: venue.amenities.isEmpty
                  ? const [
                      Text(
                        'Aucun equipement renseigne.',
                        style: TextStyle(color: _meevoMuted),
                      ),
                    ]
                  : venue.amenities
                        .map((item) => Chip(label: Text(item)))
                        .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvailabilityDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _selectedDate,
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      _selectedDate = pickedDate;
    });
    unawaited(_loadAvailability(forceRefresh: true));
  }

  void _shiftMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  void _showMonthlyDayDetails(DateTime date, MonthlyAvailability availability) {
    final dateKey = _formatApiDate(date);
    final isBlocked = availability.blockedDates.contains(dateKey);
    final isManual = availability.manualDates.contains(dateKey);
    final isBooked = availability.bookedDates.contains(dateKey);
    final isBusy = availability.busyDates.contains(dateKey);
    final statusLabel = isBlocked
        ? 'Bloque'
        : isBooked
        ? 'Reserve'
        : isManual
        ? 'Hors plateforme'
        : 'Libre';
    final statusColor = isBusy ? const Color(0xFFD65050) : _meevoDeepBlue;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jour du ${DateFormat('dd/MM/yyyy').format(date)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isManual)
                    const Text(
                      'Ajout manuel',
                      style: TextStyle(color: _meevoMuted),
                    )
                  else if (isBooked)
                    const Text(
                      'Reservation Meevo',
                      style: TextStyle(color: _meevoMuted),
                    )
                  else if (isBlocked)
                    const Text(
                      'Jour bloque',
                      style: TextStyle(color: _meevoMuted),
                    )
                  else
                    const Text(
                      'Aucune reservation',
                      style: TextStyle(color: _meevoMuted),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isBusy
                    ? 'Ce jour est marque comme occupe.'
                    : 'Ce jour est libre a la reservation.',
                style: const TextStyle(color: _meevoMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildGalleryPhotos(Venue venue) {
    final items = <String>[];
    if ((venue.coverPhoto ?? '').isNotEmpty) {
      items.add(venue.coverPhoto!);
    }
    items.addAll(venue.photos.where((photo) => !items.contains(photo)));
    return items;
  }
}

class _VenueHeroMedia extends StatefulWidget {
  const _VenueHeroMedia({
    required this.venue,
    required this.height,
    required this.onReserve,
    this.heroImageOverride,
    this.onOpenMaps,
  });

  final Venue venue;
  final double height;
  final VoidCallback onReserve;
  final String? heroImageOverride;
  final VoidCallback? onOpenMaps;

  @override
  State<_VenueHeroMedia> createState() => _VenueHeroMediaState();
}

class _VenueHeroMediaState extends State<_VenueHeroMedia> {
  VideoPlayerController? _videoController;
  bool _isInitializing = false;
  bool _showVideo = false;
  bool _hasVideoError = false;
  bool _isMuted = true;

  bool get _hasVideo => (widget.venue.videoUrl ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasVideo) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _VenueHeroMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadOverride = (oldWidget.heroImageOverride ?? '').isNotEmpty;
    final hasOverride = (widget.heroImageOverride ?? '').isNotEmpty;
    if (!hadOverride && hasOverride) {
      _videoController?.pause();
    }
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.venue.videoUrl;
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasVideoError = false;
    });

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController?.dispose();
        _videoController = controller;
        _showVideo = true;
        _isMuted = true;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasVideoError = true;
        _showVideo = false;
        _isInitializing = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null) {
      if (_hasVideo) {
        await _initializeVideo();
      }
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;
    if (controller == null) return;

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);

    if (!mounted) return;
    setState(() => _isMuted = nextMuted);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<MeevoState>().isAuthenticated;
    final controller = _videoController;
    final overrideImage = widget.heroImageOverride ?? '';
    final forceImage = overrideImage.isNotEmpty;
    final canShowVideo =
        !forceImage &&
        _showVideo &&
        controller != null &&
        controller.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (forceImage)
              Image.network(
                overrideImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _placeholderMedia('Image indisponible'),
              )
            else if (canShowVideo)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else if (widget.venue.primaryImage.isEmpty)
              _placeholderMedia('Aucune image disponible')
            else
              Image.network(
                widget.venue.primaryImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _placeholderMedia('Image indisponible'),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x12000000), Color(0x55000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (_hasVideo && !forceImage)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Video disponible',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (canShowVideo)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filled(
                  onPressed: _toggleMute,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                  ),
                  icon: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                ),
              ),
            if (_hasVideo && !forceImage)
              Center(
                child: InkWell(
                  onTap: _togglePlayback,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Center(
                      child: _isInitializing
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              canShowVideo && controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                    ),
                  ),
                ),
              ),
            if (_hasVideoError)
              Positioned(
                left: 16,
                right: 16,
                bottom: 82,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'La video n a pas pu se charger. La photo reste visible.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.onOpenMaps != null)
                    _HeroActionButton(
                      icon: Icons.map_outlined,
                      label: 'Localisation',
                      isPrimary: false,
                      onTap: widget.onOpenMaps!,
                    ),
                  _HeroActionButton(
                    icon: Icons.calendar_month_outlined,
                    label: isAuthenticated ? 'Reserver' : 'Connectez-vous',
                    isPrimary: true,
                    onTap: widget.onReserve,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isPrimary
                ? _meevoYellow
                : Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? _meevoText : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? _meevoText : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({required this.summary});

  final _VenueLiveSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: summary.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(summary.icon, color: summary.foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: TextStyle(
                    color: summary.foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.subtitle,
                  style: TextStyle(
                    color: summary.foregroundColor.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueLiveSummary {
  const _VenueLiveSummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  factory _VenueLiveSummary.fromAvailability(
    VenueAvailability availability,
    DateTime selectedDate,
  ) {
    final selectedDateKey = _formatApiDate(selectedDate);
    final now = DateTime.now();
    final isToday =
        now.year == selectedDate.year &&
        now.month == selectedDate.month &&
        now.day == selectedDate.day;

    if (availability.blockedDates.contains(selectedDateKey)) {
      return const _VenueLiveSummary(
        title: 'Salle occupee toute la journee',
        subtitle:
            'Cette date est bloquee dans le planning. Aucune reservation ne doit etre prise.',
        icon: Icons.event_busy_outlined,
        backgroundColor: Color(0xFFFFF1F1),
        foregroundColor: Color(0xFFCC3D3D),
      );
    }

    final slots = [...availability.slots]
      ..sort((left, right) => _compareTimes(left.startTime, right.startTime));

    if (slots.isEmpty) {
      return _VenueLiveSummary(
        title: isToday
            ? 'Salle libre maintenant'
            : 'Salle libre sur cette date',
        subtitle: isToday
            ? 'Aucun conflit detecte pour le moment. Le lieu est disponible.'
            : 'Aucune occupation enregistree pour ce jour.',
        icon: Icons.check_circle_outline,
        backgroundColor: const Color(0xFFF2FAF6),
        foregroundColor: const Color(0xFF199F64),
      );
    }

    if (!isToday) {
      final firstSlot = slots.first;
      return _VenueLiveSummary(
        title: 'Salle partiellement occupee',
        subtitle:
            '${slots.length} creneau(x) deja enregistre(s). Premier conflit: ${firstSlot.startTime} - ${firstSlot.endTime}.',
        icon: Icons.schedule_outlined,
        backgroundColor: const Color(0xFFFFF7E5),
        foregroundColor: const Color(0xFF9B6A00),
      );
    }

    final nowTime = _timeFromDateTime(now);
    for (final slot in slots) {
      final isInsideSlot =
          _compareTimes(nowTime, slot.startTime) >= 0 &&
          _compareTimes(nowTime, slot.endTime) < 0;

      if (isInsideSlot) {
        return _VenueLiveSummary(
          title: 'Salle occupee maintenant',
          subtitle:
              'Occupation en cours jusqu a ${slot.endTime}${slot.eventType?.isNotEmpty == true ? ' pour ${slot.eventType}' : ''}.',
          icon: Icons.event_busy_outlined,
          backgroundColor: const Color(0xFFFFF1F1),
          foregroundColor: const Color(0xFFCC3D3D),
        );
      }

      if (_compareTimes(nowTime, slot.startTime) < 0) {
        return _VenueLiveSummary(
          title: 'Salle libre maintenant',
          subtitle:
              'Libre pour le moment. Prochaine occupation a ${slot.startTime}.',
          icon: Icons.check_circle_outline,
          backgroundColor: const Color(0xFFF2FAF6),
          foregroundColor: const Color(0xFF199F64),
        );
      }
    }

    return const _VenueLiveSummary(
      title: 'Salle libre maintenant',
      subtitle: 'Le reste de la journee est libre selon le planning actuel.',
      icon: Icons.check_circle_outline,
      backgroundColor: Color(0xFFF2FAF6),
      foregroundColor: Color(0xFF199F64),
    );
  }
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({required this.venue});

  final Venue venue;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  static const _undefinedEventTypes = ['Non defini'];

  final _paymentPhoneController = TextEditingController();
  late final List<String> _eventTypes;
  late String _eventType;
  late final bool _venueHasEventTypes;
  String _paymentNetwork = 'MOOV';
  DateTime? _eventDate;
  late int _guests;
  late String _startTime;
  late String _endTime;
  late final int _venueCapacity;
  Future<VenueAvailability>? _availabilityFuture;
  bool _submitting = false;
  BookingCheckoutResult? _checkoutResult;

  @override
  void initState() {
    super.initState();
    final state = context.read<MeevoState>();
    final normalizedTypes = <String>[];
    final seen = <String>{};
    for (final item in widget.venue.eventTypes) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      normalizedTypes.add(trimmed);
    }
    _venueHasEventTypes = normalizedTypes.isNotEmpty;
    _eventTypes = _venueHasEventTypes ? normalizedTypes : _undefinedEventTypes;
    _eventType = _eventTypes.first;

    _venueCapacity = widget.venue.capacity;
    final capacity = _venueCapacity > 0 ? _venueCapacity : 0;
    _guests = capacity <= 0 ? 1 : (capacity >= 200 ? 200 : capacity);
    _startTime = widget.venue.businessHours.opensAt;
    _endTime = widget.venue.businessHours.closesAt;
    _paymentPhoneController.text =
        state.currentUser?.phone?.trim().isNotEmpty == true
        ? state.currentUser!.phone!.trim()
        : state.currentUser?.partnerProfile?.whatsapp ?? '';
  }

  @override
  void dispose() {
    _paymentPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Nouvelle reservation'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _eventType,
                items: _eventTypes
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: _venueHasEventTypes
                    ? (value) =>
                          setState(() => _eventType = value ?? _eventType)
                    : null,
                decoration: InputDecoration(
                  labelText: 'Type d evenement',
                  helperText: _venueHasEventTypes
                      ? null
                      : 'Types non definis pour ce lieu.',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: _meevoBackground,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(
                  _eventDate == null
                      ? 'Choisir une date'
                      : DateFormat('dd/MM/yyyy').format(_eventDate!),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: _meevoBackground,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Debut'),
                      subtitle: Text(_startTime),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: _meevoBackground,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Fin'),
                      subtitle: Text(_endTime),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: _meevoBackground,
                leading: const Icon(Icons.groups_2_outlined),
                title: Text(
                  _venueCapacity > 0
                      ? '$_guests invites (max $_venueCapacity)'
                      : 'Capacite non definie',
                ),
                onTap: _venueCapacity > 0 ? _pickGuests : null,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paiement de reservation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Le client regle ${_formatMoney(widget.venue.startingPrice, 'FCFA')} via CinetPay. La reservation n apparait qu apres paiement reussi.',
                      style: const TextStyle(color: _meevoMuted, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentNetwork,
                      decoration: const InputDecoration(
                        labelText: 'Reseau de paiement',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MOOV',
                          child: Text('Moov Money / Flooz'),
                        ),
                        DropdownMenuItem(
                          value: 'TOGOCEL',
                          child: Text('Yas / TMoney'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _paymentNetwork = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paymentPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Numero du payeur',
                        hintText: '90 00 00 00',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planning du lieu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _eventDate == null
                          ? 'Choisissez d abord la date pour voir les horaires occupes.'
                          : 'Le planning se met a jour en temps reel selon les reservations et les ajouts manuels du partenaire.',
                      style: const TextStyle(color: _meevoMuted, height: 1.5),
                    ),
                    if (_eventDate != null) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<VenueAvailability>(
                        future: _availabilityFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: _meevoPurple,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const _ScheduleEmptyState(
                              title: 'Planning indisponible',
                              subtitle:
                                  'Impossible de verifier ce creneau pour le moment.',
                            );
                          }

                          final availability =
                              snapshot.data ?? const VenueAvailability.empty();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BusinessHoursBanner(
                                businessHours: availability.businessHours,
                                isBlockedDate: availability.blockedDates
                                    .contains(_formatApiDate(_eventDate!)),
                              ),
                              const SizedBox(height: 12),
                              _AvailabilityTimeline(
                                availability: availability,
                                highlightedStartTime: _startTime,
                                highlightedEndTime: _endTime,
                                emptyLabel:
                                    'Aucun conflit detecte pour cette date. Verifiez quand meme vos horaires avant validation.',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (_checkoutResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101735),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suivi du paiement',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DetailChip(
                            icon: Icons.payments_outlined,
                            label: _formatMoney(
                              _checkoutResult!.payment.grossAmount,
                              'FCFA',
                            ),
                          ),
                          _DetailChip(
                            icon: Icons.receipt_long_outlined,
                            label: _checkoutResult!.payment.status,
                          ),
                          _DetailChip(
                            icon: Icons.confirmation_number_outlined,
                            label: _checkoutResult!.payment.identifier,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Ouvrez CinetPay.\n2. Validez le paiement sur votre telephone.\n3. Revenez ici et verifiez le statut.\n4. La reservation entre dans Meevo uniquement apres succes.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _launchUrl(
                              Uri.parse(_checkoutResult!.paymentUrl),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _meevoYellow,
                              foregroundColor: _meevoText,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Ouvrir CinetPay'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _verifyPayment,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.26),
                              ),
                            ),
                            icon: const Icon(Icons.sync),
                            label: const Text('Verifier le paiement'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _meevoYellow,
            foregroundColor: _meevoText,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _checkoutResult == null ? 'Payer la reservation' : 'Relancer',
                ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 7)),
    );

    if (pickedDate != null) {
      setState(() {
        _eventDate = pickedDate;
        _availabilityFuture = _fetchAvailabilityForSelectedDate();
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = _parseTime(
      isStart ? _startTime : _endTime,
      fallbackHour: isStart ? 8 : 23,
      fallbackMinute: 0,
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

    final formatted = _formatTimeOfDay(pickedTime);

    setState(() {
      if (isStart) {
        _startTime = formatted;
        if (_compareTimes(_endTime, _startTime) <= 0) {
          _endTime = _addOneHour(_startTime);
        }
      } else {
        _endTime = formatted;
        if (_compareTimes(_endTime, _startTime) <= 0) {
          _startTime = _subtractOneHour(_endTime);
        }
      }

      if (_eventDate != null) {
        _availabilityFuture = _fetchAvailabilityForSelectedDate();
      }
    });
  }

  Future<void> _pickGuests() async {
    if (_venueCapacity <= 0) return;
    final capacity = _venueCapacity;
    final options = <int>{
      capacity,
      50,
      100,
      150,
      200,
      250,
      300,
      500,
    }.where((value) => value >= 1 && value <= capacity).toList()..sort();

    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              const Text(
                'Capacite attendue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final value in options)
                ListTile(
                  title: Text('$value invites'),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _guests = result.clamp(1, capacity));
    }
  }

  Future<void> _submit() async {
    if (!_venueHasEventTypes) {
      _showMeevoToast(
        context,
        'Ce lieu n a pas defini ses types d evenements. Reservation impossible.',
        isError: true,
      );
      return;
    }

    if (_venueCapacity <= 0) {
      _showMeevoToast(
        context,
        'Ce lieu n a pas de capacite configuree. Reservation impossible.',
        isError: true,
      );
      return;
    }

    if (_eventDate == null) {
      _showMeevoToast(
        context,
        'Choisissez une date pour la reservation.',
        isError: true,
      );
      return;
    }

    if (_compareTimes(_endTime, _startTime) <= 0) {
      _showMeevoToast(
        context,
        'L heure de fin doit etre apres l heure de debut.',
        isError: true,
      );
      return;
    }

    if (_guests > _venueCapacity) {
      _showMeevoToast(
        context,
        'Le nombre d invites ne peut pas depasser la capacite du lieu ($_venueCapacity).',
        isError: true,
      );
      return;
    }

    final phoneNumber = _paymentPhoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showMeevoToast(
        context,
        'Entrez le numero qui va payer la reservation.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    final state = context.read<MeevoState>();
    final checkout = await state.startBookingCheckout(
      venueId: widget.venue.id,
      eventType: _eventType,
      eventDate: _eventDate!,
      network: _paymentNetwork,
      phoneNumber: phoneNumber,
      startTime: _startTime,
      endTime: _endTime,
      guestCount: _guests,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (checkout != null) {
      setState(() => _checkoutResult = checkout);
      await _launchUrl(Uri.parse(checkout.paymentUrl));
      if (!mounted) return;
      _showMeevoToast(
        context,
        'Paiement initialise. Finalisez sur CinetPay puis verifiez ici.',
      );
    }
  }

  Future<void> _verifyPayment() async {
    if (_checkoutResult == null) return;

    setState(() => _submitting = true);
    final result = await context.read<MeevoState>().verifyBookingPayment(
      identifier: _checkoutResult!.payment.identifier,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) return;
    setState(() {
      _checkoutResult = BookingCheckoutResult(
        payment: result.payment,
        paymentUrl: result.payment.paymentUrl ?? _checkoutResult!.paymentUrl,
      );
    });

    if (result.booking != null) {
      Navigator.pop(context);
      _showMeevoToast(
        context,
        'Paiement confirme. Reservation ajoutee dans Meevo.',
      );
    }
  }

  Future<VenueAvailability> _fetchAvailabilityForSelectedDate() {
    return context.read<MeevoState>().fetchAvailability(
      venueId: widget.venue.id,
      date: _eventDate!,
      forceRefresh: true,
    );
  }
}

class _AuthCard extends StatefulWidget {
  const _AuthCard({
    required this.initialMode,
    required this.isLoading,
    required this.onModeChanged,
    required this.onLogin,
    required this.onRegister,
  });

  final String initialMode;
  final bool isLoading;
  final ValueChanged<String> onModeChanged;
  final Future<void> Function({required String email, required String password})
  onLogin;
  final Future<void> Function({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String city,
  })
  onRegister;

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerCityController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialMode == 'register' ? 1 : 0,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      widget.onModeChanged(_tabController.index == 0 ? 'login' : 'register');
    });
  }

  @override
  void didUpdateWidget(covariant _AuthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialMode == 'register' ? 1 : 0;
    if (_tabController.index != nextIndex) {
      _tabController.animateTo(nextIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerCityController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MeevoLogo(centered: true),
            const SizedBox(height: 14),
            const Text(
              'Connexion',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connectez-vous ou creez votre compte pour reserver des lieux reels.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _meevoMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            TabBar(
              controller: _tabController,
              indicatorColor: _meevoYellow,
              labelColor: _meevoPurple,
              tabs: const [
                Tab(text: 'Connexion'),
                Tab(text: 'Inscription'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AuthFormLayout(
                    children: [
                      TextField(
                        controller: _loginEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.isLoading
                              ? null
                              : () => widget.onLogin(
                                  email: _loginEmailController.text.trim(),
                                  password: _loginPasswordController.text
                                      .trim(),
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _meevoYellow,
                            foregroundColor: _meevoText,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: widget.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
                      ),
                    ],
                  ),
                  _AuthFormLayout(
                    children: [
                      TextField(
                        controller: _registerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _registerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _registerPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telephone',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _registerCityController,
                        decoration: const InputDecoration(labelText: 'Ville'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F7FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_outline, color: _meevoPurple),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tous les comptes sont crees comme clients. Vous pourrez activer l espace partenaire plus tard.',
                                style: TextStyle(
                                  color: _meevoMuted,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _registerPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.isLoading
                              ? null
                              : () => widget.onRegister(
                                  fullName: _registerNameController.text.trim(),
                                  email: _registerEmailController.text.trim(),
                                  password: _registerPasswordController.text
                                      .trim(),
                                  phone: _registerPhoneController.text.trim(),
                                  city: _registerCityController.text.trim(),
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _meevoYellow,
                            foregroundColor: _meevoText,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: widget.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("S'inscrire"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFormLayout extends StatelessWidget {
  const _AuthFormLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.realtimeConnected,
    required this.onLogout,
  });

  final AppUser user;
  final bool realtimeConnected;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MeevoLogo(),
            const SizedBox(height: 22),
            Text(
              user.fullName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(user.email, style: const TextStyle(color: _meevoMuted)),
            if ((user.phone ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  user.phone!,
                  style: const TextStyle(color: _meevoMuted),
                ),
              ),
            if ((user.city ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  user.city!,
                  style: const TextStyle(color: _meevoMuted),
                ),
              ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailChip(icon: Icons.badge_outlined, label: user.role),
                _DetailChip(
                  icon: realtimeConnected
                      ? Icons.wifi_tethering
                      : Icons.wifi_tethering_off,
                  label: realtimeConnected
                      ? 'Temps reel actif'
                      : 'Temps reel hors ligne',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onLogout,
                child: const Text('Se deconnecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerUpgradeCard extends StatelessWidget {
  const _PartnerUpgradeCard();

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Dashboard partenaire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activez votre dashboard partenaire sans vous deconnecter pour ajouter vos lieux, suivre vos reservations et gerer votre planning en temps reel.',
            style: TextStyle(color: _meevoMuted, height: 1.6),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openPartnerOnboarding(context),
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Devenir partenaire'),
          ),
        ],
      ),
    );
  }
}

class _PartnerSubscriptionPromptCard extends StatelessWidget {
  const _PartnerSubscriptionPromptCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final subscription = state.currentUser?.subscription;
    final statusLabel = subscription == null
        ? 'Abonnement non active'
        : subscription.status == 'pending'
        ? 'Paiement en attente'
        : subscription.status == 'expired'
        ? 'Abonnement expire'
        : 'Activation requise';

    return _SectionPanel(
      title: 'Abonnement partenaire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre dossier partenaire est pret. Il reste le paiement de l abonnement pour debloquer le dashboard, les formulaires d ajout et les outils de gestion.',
            style: const TextStyle(color: _meevoMuted, height: 1.6),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(
                icon: Icons.workspace_premium_outlined,
                label: statusLabel,
              ),
              _DetailChip(
                icon: Icons.payments_outlined,
                label: '${_formatMoney(50000, 'FCFA')} / mois',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openPartnerSubscriptionPage(context),
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
            ),
            icon: const Icon(Icons.credit_card_outlined),
            label: const Text('Choisir mon abonnement'),
          ),
        ],
      ),
    );
  }
}

class _PartnerOnboardingPage extends StatefulWidget {
  const _PartnerOnboardingPage();

  @override
  State<_PartnerOnboardingPage> createState() => _PartnerOnboardingPageState();
}

class _PartnerOnboardingPageState extends State<_PartnerOnboardingPage> {
  static const _partnerTypes = [
    'Salle',
    'Hotel',
    'Lieu hybride',
    'Prestataire',
    'Salle + Prestataire',
  ];

  final _businessNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _partnerType = _partnerTypes.first;
  String _city = _heroCities.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<MeevoState>().currentUser;
      if (user == null) return;

      _city = _canonicalHeroCity(user.city, allowAllTogo: false);
      _whatsappController.text = user.phone ?? '';
      final existing = user.partnerProfile;
      if (existing != null) {
        _businessNameController.text = existing.businessName;
        _districtController.text = existing.district ?? '';
        _whatsappController.text = existing.whatsapp.isNotEmpty
            ? existing.whatsapp
            : _whatsappController.text;
        _descriptionController.text = existing.description ?? '';
        if (_partnerTypes.contains(existing.partnerType)) {
          _partnerType = existing.partnerType;
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _districtController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final isProviderOnly = _partnerType == 'Prestataire';
    final isVenuePartner = !isProviderOnly;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FF),
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Devenir partenaire'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 28 : 18,
          isDesktop ? 24 : 18,
          isDesktop ? 28 : 18,
          28,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 34 : 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_meevoDeepBlue, _meevoPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: isDesktop
                        ? Row(
                            children: [
                              Expanded(child: _partnerHeroCopy(context)),
                              const SizedBox(width: 22),
                              Expanded(child: _partnerHeroStats()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _partnerHeroCopy(context),
                              const SizedBox(height: 18),
                              _partnerHeroStats(),
                            ],
                          ),
                  ),
                  const SizedBox(height: 22),
                  if (!state.isAuthenticated)
                    _SectionPanel(
                      title: 'Connexion requise',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connectez-vous d abord comme client, puis revenez ici pour remplir votre dossier partenaire.',
                            style: TextStyle(color: _meevoMuted, height: 1.6),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: () {
                                  context.read<MeevoState>().setAuthMode(
                                    'login',
                                  );
                                  context.read<MeevoState>().setPageIndex(3);
                                  Navigator.pop(context);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _meevoYellow,
                                  foregroundColor: _meevoText,
                                ),
                                child: const Text('Se connecter'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  context.read<MeevoState>().setAuthMode(
                                    'register',
                                  );
                                  context.read<MeevoState>().setPageIndex(3);
                                  Navigator.pop(context);
                                },
                                child: const Text('Creer mon compte client'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (state.hasPartnerAccess)
                    _SectionPanel(
                      title: 'Dashboard actif',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Votre compte est deja partenaire. Vous pouvez acceder directement a votre dashboard.',
                            style: TextStyle(color: _meevoMuted, height: 1.6),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openDashboard(context);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _meevoYellow,
                              foregroundColor: _meevoText,
                            ),
                            icon: const Icon(Icons.work_outline),
                            label: const Text('Ouvrir le dashboard'),
                          ),
                        ],
                      ),
                    )
                  else if (state.needsPartnerSubscription)
                    _SectionPanel(
                      title: 'Abonnement a activer',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Votre dossier partenaire est bien enregistre. Choisissez maintenant un abonnement Meevo pour debloquer le dashboard, les formulaires d ajout et le planning temps reel.',
                            style: TextStyle(color: _meevoMuted, height: 1.6),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DetailChip(
                                icon: Icons.apartment_outlined,
                                label:
                                    state
                                        .currentUser
                                        ?.partnerProfile
                                        ?.businessName ??
                                    'Profil partenaire',
                              ),
                              _DetailChip(
                                icon: Icons.payments_outlined,
                                label: '${_formatMoney(50000, 'FCFA')} / mois',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () =>
                                _openPartnerSubscriptionPage(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: _meevoYellow,
                              foregroundColor: _meevoText,
                            ),
                            icon: const Icon(Icons.credit_card_outlined),
                            label: const Text('Ouvrir la page abonnement'),
                          ),
                        ],
                      ),
                    )
                  else
                    _SectionPanel(
                      title: 'Votre dossier partenaire',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DetailChip(
                                icon: Icons.person_outline,
                                label: state.currentUser?.fullName ?? '',
                              ),
                              if ((state.currentUser?.email ?? '').isNotEmpty)
                                _DetailChip(
                                  icon: Icons.mail_outline,
                                  label: state.currentUser!.email,
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _ResponsiveFormRow(
                            isDesktop: isDesktop,
                            children: [
                              TextField(
                                controller: _businessNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nom commercial',
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: _partnerType,
                                decoration: const InputDecoration(
                                  labelText: 'Type de partenaire',
                                ),
                                items: _partnerTypes
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _partnerType = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ResponsiveFormRow(
                            isDesktop: isDesktop,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey('partner-city-$_city'),
                                initialValue: _canonicalHeroCity(_city),
                                decoration: const InputDecoration(
                                  labelText: 'Ville',
                                ),
                                items: _heroCities
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _city = value);
                                },
                              ),
                              if (isVenuePartner)
                                TextField(
                                  controller: _districtController,
                                  decoration: const InputDecoration(
                                    labelText: 'Quartier',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _whatsappController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Numero WhatsApp (contact des clients)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            minLines: isProviderOnly ? 3 : 4,
                            maxLines: isProviderOnly ? 4 : 6,
                            decoration: InputDecoration(
                              labelText: isProviderOnly
                                  ? 'Presentez votre prestation'
                                  : 'Presentez votre salle, hotel ou espace',
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F7FC),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text(
                              'Apres validation du formulaire, votre profil partenaire est cree. L etape suivante sera le paiement de l abonnement Meevo avant l ouverture du dashboard.',
                              style: TextStyle(color: _meevoMuted, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: state.isAuthLoading
                                  ? null
                                  : _submitPartnerForm,
                              style: FilledButton.styleFrom(
                                backgroundColor: _meevoYellow,
                                foregroundColor: _meevoText,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              icon: state.isAuthLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.workspace_premium),
                              label: const Text('Continuer vers l abonnement'),
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
      ),
    );
  }

  Widget _partnerHeroCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Text(
            'Dashboard partenaire Meevo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Rejoignez Meevo\ncomme partenaire',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ajoutez votre salle, hotel, lieu hybride ou prestation, puis gerez votre dashboard en temps reel.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 17,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _partnerHeroStats() {
    final cards = [
      ('1', 'Compte client'),
      ('2', 'Formulaire partenaire'),
      ('3', 'Abonnement actif'),
      ('4', 'Dashboard ouvert'),
    ];

    return Row(
      children: cards
          .map(
            (card) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      card.$1,
                      style: const TextStyle(
                        color: _meevoYellow,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _submitPartnerForm() async {
    final state = context.read<MeevoState>();
    final businessName = _businessNameController.text.trim();
    final whatsapp = _whatsappController.text.trim();
    final description = _descriptionController.text.trim();

    if (businessName.isEmpty || whatsapp.isEmpty || description.length < 12) {
      _showMeevoToast(
        context,
        'Remplissez le nom commercial, le numero WhatsApp et une description plus detaillee.',
        isError: true,
      );
      return;
    }

    final success = await state.becomePartner(
      PartnerOnboardingDraft(
        businessName: businessName,
        partnerType: _partnerType,
        city: _city,
        district: _districtController.text.trim(),
        whatsapp: whatsapp,
        description: description,
      ),
    );

    if (!mounted || !success) return;

    state.setPageIndex(3);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const _PartnerSubscriptionPage()),
    );
  }
}

class _PartnerSubscriptionPage extends StatefulWidget {
  const _PartnerSubscriptionPage();

  @override
  State<_PartnerSubscriptionPage> createState() =>
      _PartnerSubscriptionPageState();
}

class _PartnerSubscriptionPageState extends State<_PartnerSubscriptionPage> {
  final _phoneController = TextEditingController();
  int _months = 1;
  String _network = 'MOOV';
  SubscriptionCheckoutResult? _lastCheckout;
  String _section = 'overview';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = context.read<MeevoState>();
      final user = state.currentUser;
      final partnerWhatsapp = user?.partnerProfile?.whatsapp ?? '';
      _phoneController.text = partnerWhatsapp.isNotEmpty
          ? partnerWhatsapp
          : (user?.phone ?? '');
      await state.loadSubscriptionOverview(silent: true);
      if (!mounted) return;
      if (state.subscriptionOverview.presets.isNotEmpty) {
        _months = state.subscriptionOverview.presets.first.months;
      }
      if (state.subscriptionOverview.networks.isNotEmpty) {
        _network = state.subscriptionOverview.networks.first.code;
      }
      if (state.subscriptionOverview.subscription?.status == 'pending') {
        _section = 'payment';
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Map<String, double> _quoteFor(int months, double monthlyPrice) {
    final gross = months * monthlyPrice;
    var discountRate = 0.0;
    if (months >= 12) {
      discountRate = 0.10;
    } else if (months >= 6) {
      discountRate = 0.05;
    } else if (months >= 3) {
      discountRate = 0.02;
    }
    final discountAmount = gross * discountRate;
    return {
      'gross': gross,
      'discount': discountAmount,
      'total': gross - discountAmount,
    };
  }

  Future<void> _launchPayment(String paymentUrl) async {
    if (paymentUrl.isEmpty) return;
    final uri = Uri.tryParse(paymentUrl);
    if (uri == null) {
      _showMeevoToast(context, 'Lien de paiement invalide.', isError: true);
      return;
    }
    final ok = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!mounted || ok) return;
    _showMeevoToast(
      context,
      'Impossible d ouvrir CinetPay pour le moment.',
      isError: true,
    );
  }

  Future<void> _startCheckout() async {
    final state = context.read<MeevoState>();
    final phone = _phoneController.text.trim();
    if (phone.length < 6) {
      _showMeevoToast(
        context,
        'Entrez un numero valide pour le paiement mobile money.',
        isError: true,
      );
      return;
    }

    final result = await state.startSubscriptionCheckout(
      months: _months,
      network: _network,
      phoneNumber: phone,
    );
    if (!mounted || result == null) return;

    setState(() => _lastCheckout = result);
    await _launchPayment(result.paymentUrl);
  }

  Future<void> _verifyPayment() async {
    final state = context.read<MeevoState>();
    final wasAlreadyActive = state.partnerSubscription?.isActive == true;
    final identifier =
        _lastCheckout?.payment.identifier ??
        (state.subscriptionOverview.payments.isNotEmpty
            ? state.subscriptionOverview.payments.first.identifier
            : null) ??
        state.currentUser?.subscription?.currentPaymentIdentifier;
    final result = await state.verifySubscriptionPayment(
      identifier: identifier,
    );
    if (!mounted || result == null) return;

    if (result.user.subscription?.isActive == true) {
      _showMeevoToast(
        context,
        wasAlreadyActive
            ? 'Abonnement renouvele avec succes.'
            : 'Abonnement actif. Dashboard debloque.',
      );
      state.clearMessages();
      return;
    }

    final internalStatus =
        result.paymentStatus['internalStatus']?.toString() ?? '';
    final message = switch (internalStatus) {
      'processing' =>
        'Paiement en cours sur CinetPay. Validez sur votre telephone puis reessayez.',
      'failed' => 'Paiement refuse. Vous pouvez recommencer.',
      'cancelled' => 'Paiement annule. Vous pouvez recommencer.',
      'expired' => 'Paiement expire. Relancez une nouvelle tentative.',
      _ => 'Statut du paiement actualise.',
    };
    _showMeevoToast(
      context,
      message,
      isError:
          internalStatus == 'failed' ||
          internalStatus == 'cancelled' ||
          internalStatus == 'expired',
    );
    state.clearMessages();
  }

  String _dateLabel(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) return '--';
    return DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(parsed.toLocal());
  }

  String _subscriptionStatusLabel(PartnerSubscriptionData? subscription) {
    if (subscription == null) {
      return 'A activer';
    }
    if (subscription.isActive) {
      return 'Actif';
    }
    return switch (subscription.status) {
      'pending' => 'En attente',
      'expired' => 'Expire',
      'cancelled' => 'Annule',
      _ => 'Inactif',
    };
  }

  List<_WorkspaceNavItem> _buildWorkspaceNavItems(
    BuildContext context,
    MeevoState state,
  ) {
    return [
      _WorkspaceNavItem(
        label: 'Vue',
        icon: Icons.tune_outlined,
        selected: _section == 'overview',
        onTap: () => setState(() => _section = 'overview'),
      ),
      _WorkspaceNavItem(
        label: 'Paiement',
        icon: Icons.payments_outlined,
        selected: _section == 'plans',
        onTap: () => setState(() => _section = 'plans'),
      ),
      _WorkspaceNavItem(
        label: 'Suivi',
        icon: Icons.sync_outlined,
        selected: _section == 'payment',
        onTap: () => setState(() => _section = 'payment'),
      ),
      _WorkspaceNavItem(
        label: 'Historique',
        icon: Icons.history_outlined,
        selected: _section == 'history',
        onTap: () => setState(() => _section = 'history'),
      ),
      _WorkspaceNavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_customize_outlined,
        onTap: () => _openDashboard(context),
      ),
      if (state.hasVenuePartnerAccess)
        _WorkspaceNavItem(
          label: 'Revenu',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => _openPartnerRevenuePage(context),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final overview = state.subscriptionOverview;
    final subscription =
        overview.subscription ?? state.currentUser?.subscription;
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final monthlyPrice = overview.monthlyPrice > 0
        ? overview.monthlyPrice
        : 50000.0;
    final quote = _quoteFor(_months, monthlyPrice);
    final presets = overview.presets;
    final networks = overview.networks.isNotEmpty
        ? overview.networks
        : const [
            SubscriptionNetworkData(
              code: 'MOOV',
              label: 'Moov Money',
              paymentMethodLabel: 'Flooz',
            ),
            SubscriptionNetworkData(
              code: 'TOGOCEL',
              label: 'Yas TMoney',
              paymentMethodLabel: 'TMoney',
            ),
          ];
    final recentPayment =
        _lastCheckout?.payment ??
        (overview.payments.isNotEmpty ? overview.payments.first : null);

    return _StateToastListener(
      child: _WorkspaceScaffold(
        title: 'Espace partenaire',
        subtitle: 'Navigation laterale sur grand ecran, menu sur mobile.',
        navItems: _buildWorkspaceNavItems(context, state),
        mobileBottomNavIndex: 3,
        bottomNavPartnerMode: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 28 : 18,
            isDesktop ? 22 : 18,
            isDesktop ? 28 : 18,
            30,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PartnerSubscriptionHero(
                      businessName:
                          state.currentUser?.partnerProfile?.businessName ??
                          'Meevo',
                      partnerType:
                          state.currentUser?.partnerProfile?.partnerType ??
                          'Partenaire',
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InlineStatPill(
                          label: 'Statut',
                          value: _subscriptionStatusLabel(subscription),
                          emphasis: true,
                        ),
                        _InlineStatPill(
                          label: 'Expiration',
                          value: subscription?.endsAt == null
                              ? '--'
                              : _formatDisplayDate(subscription!.endsAt!),
                        ),
                        _InlineStatPill(
                          label: 'Tarif',
                          value: '${_formatMoney(monthlyPrice, 'FCFA')} / mois',
                          emphasis: true,
                        ),
                        _InlineStatPill(
                          label: 'Dernier paiement',
                          value: recentPayment?.status ?? 'Aucun',
                        ),
                      ],
                    ),
                    if (subscription?.status == 'pending') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFF59E0B),
                              width: 3,
                            ),
                          ),
                          color: Color(0xFFFFFBEB),
                        ),
                        child: const Text(
                          'Un paiement est encore en attente. Validez-le sur CinetPay puis revenez verifier le statut.',
                          style: TextStyle(color: _meevoMuted, height: 1.55),
                        ),
                      ),
                    ],
                    if (!overview.paymentConfigured) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Le paiement CinetPay n est pas encore configure sur le serveur. L abonnement restera en lecture seule tant que cette configuration n est pas terminee.',
                        style: TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SubscriptionSectionSelector(
                      isDesktop: isDesktop,
                      currentSection: _section,
                      isActive: subscription?.isActive == true,
                      hasRecentPayment: recentPayment != null,
                      onSelect: (section) => setState(() => _section = section),
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey(_section),
                        child: switch (_section) {
                          'plans' => _buildSubscriptionPlansSectionV2(
                            context: context,
                            isDesktop: isDesktop,
                            state: state,
                            overview: overview,
                            quote: quote,
                            presets: presets,
                            networks: networks,
                          ),
                          'payment' => _buildSubscriptionTrackingSectionV2(
                            context: context,
                            state: state,
                            recentPayment: recentPayment,
                          ),
                          'history' => _buildSubscriptionHistorySectionV2(
                            overview: overview,
                          ),
                          _ => _buildSubscriptionOverviewSectionV2(
                            context: context,
                            isDesktop: isDesktop,
                            state: state,
                            subscription: subscription,
                            recentPayment: recentPayment,
                            monthlyPrice: monthlyPrice,
                          ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSubscriptionOverviewSection({
    required BuildContext context,
    required bool isDesktop,
    required MeevoState state,
    required PartnerSubscriptionData? subscription,
    required SubscriptionPaymentData? recentPayment,
    required double monthlyPrice,
  }) {
    final statusLabel = subscription == null
        ? 'A activer'
        : subscription.isActive
        ? 'Actif'
        : switch (subscription.status) {
            'pending' => 'En attente',
            'expired' => 'Expire',
            'cancelled' => 'Annule',
            _ => 'Inactif',
          };

    final summaryCards = [
      (
        Icons.workspace_premium_outlined,
        'Statut',
        statusLabel,
        const Color(0xFF4F46E5),
      ),
      (
        Icons.schedule_outlined,
        'Expiration',
        subscription?.endsAt == null
            ? '--'
            : _formatDisplayDate(subscription!.endsAt!),
        const Color(0xFF2563EB),
      ),
      (
        Icons.payments_outlined,
        'Tarif',
        '${_formatMoney(monthlyPrice, 'FCFA')} / mois',
        const Color(0xFFF59E0B),
      ),
      (
        Icons.receipt_long_outlined,
        'Dernier statut',
        recentPayment?.status ?? 'Aucun paiement',
        const Color(0xFF16A34A),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subscription?.status == 'pending')
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF4D76C)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.pending_actions_outlined,
                  color: Color(0xFF9A6700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paiement en attente',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _meevoDeepBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Votre acces partenaire reste bloque tant que le paiement n est pas confirme. Ouvrez CinetPay puis verifiez le statut.',
                        style: TextStyle(color: _meevoMuted, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                setState(() => _section = 'payment'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _meevoYellow,
                              foregroundColor: _meevoText,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Continuer'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _section = 'plans'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Changer formule'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _SectionPanel(
          title: subscription?.isActive == true
              ? 'Abonnement actif'
              : 'Vue generale',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subscription?.isActive == true
                    ? 'Votre acces partenaire est actif jusqu au ${_dateLabel(subscription?.endsAt)}.'
                    : 'Activez ou renouvelez votre abonnement pour garder vos outils partenaire visibles et operationnels.',
                style: const TextStyle(color: _meevoMuted, height: 1.6),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isDesktop ? 1.45 : 1.18,
                children: [
                  for (final card in summaryCards)
                    _SubscriptionOverviewStatCard(
                      icon: card.$1,
                      label: card.$2,
                      value: card.$3,
                      accent: card.$4,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (subscription?.isActive == true)
                    FilledButton.icon(
                      onPressed: () => _openDashboard(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _meevoYellow,
                        foregroundColor: _meevoText,
                      ),
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Ouvrir le dashboard'),
                    ),
                  FilledButton.icon(
                    onPressed: () => setState(() => _section = 'plans'),
                    style: FilledButton.styleFrom(
                      backgroundColor: subscription?.isActive == true
                          ? _meevoDeepBlue
                          : _meevoYellow,
                      foregroundColor: subscription?.isActive == true
                          ? Colors.white
                          : _meevoText,
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(
                      subscription?.isActive == true
                          ? 'Renouveler'
                          : 'Choisir une formule',
                    ),
                  ),
                  if (recentPayment != null)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _section = 'payment'),
                      icon: const Icon(Icons.sync_outlined),
                      label: const Text('Suivre le paiement'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _section = 'history'),
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('Historique'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildSubscriptionPlansSection({
    required BuildContext context,
    required bool isDesktop,
    required MeevoState state,
    required SubscriptionOverview overview,
    required Map<String, double> quote,
    required List<SubscriptionPresetData> presets,
    required List<SubscriptionNetworkData> networks,
  }) {
    return _SectionPanel(
      title: 'Formules et paiement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisissez une formule, ajustez la duree si besoin, puis lancez le paiement mobile money.',
            style: const TextStyle(color: _meevoMuted, height: 1.6),
          ),
          const SizedBox(height: 18),
          if (isDesktop)
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final preset in presets)
                  _SubscriptionPlanCard(
                    title: preset.title,
                    subtitle: preset.subtitle,
                    badge: preset.badge,
                    amountLabel: _formatMoney(preset.totalAmount, 'FCFA'),
                    metaLabel:
                        '${preset.months} mois • remise ${_formatMoney(preset.discountAmount, 'FCFA')}',
                    isSelected: _months == preset.months,
                    width: 250,
                    compact: false,
                    onTap: () => setState(() => _months = preset.months),
                  ),
                _SubscriptionPlanCard(
                  title: 'Sur mesure',
                  subtitle: 'Choisissez exactement votre duree',
                  badge: '2 a ${overview.maxMonths} mois',
                  amountLabel: _formatMoney(quote['total'] ?? 0, 'FCFA'),
                  metaLabel:
                      '$_months mois • remise ${_formatMoney(quote['discount'] ?? 0, 'FCFA')}',
                  isSelected: !presets.any((item) => item.months == _months),
                  width: 250,
                  compact: false,
                  onTap: () {},
                ),
              ],
            )
          else
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                for (final preset in presets)
                  _SubscriptionPlanCard(
                    title: preset.title,
                    subtitle: preset.subtitle,
                    badge: preset.badge,
                    amountLabel: _formatMoney(preset.totalAmount, 'FCFA'),
                    metaLabel:
                        '${preset.months} mois • remise ${_formatMoney(preset.discountAmount, 'FCFA')}',
                    isSelected: _months == preset.months,
                    compact: true,
                    onTap: () => setState(() => _months = preset.months),
                  ),
                _SubscriptionPlanCard(
                  title: 'Sur mesure',
                  subtitle: 'Choisissez la duree',
                  badge: '2 a ${overview.maxMonths} mois',
                  amountLabel: _formatMoney(quote['total'] ?? 0, 'FCFA'),
                  metaLabel:
                      '$_months mois • remise ${_formatMoney(quote['discount'] ?? 0, 'FCFA')}',
                  isSelected: !presets.any((item) => item.months == _months),
                  compact: true,
                  onTap: () {},
                ),
              ],
            ),
          const SizedBox(height: 20),
          Text(
            'Nombre de mois: $_months',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _meevoDeepBlue,
            ),
          ),
          Slider(
            value: _months.toDouble(),
            min: 1,
            max: overview.maxMonths.toDouble(),
            divisions: overview.maxMonths - 1,
            activeColor: _meevoYellow,
            inactiveColor: const Color(0xFFE7E0FB),
            label: '$_months mois',
            onChanged: (value) {
              setState(() => _months = value.round());
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1736),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recapitulatif',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                _SubscriptionAmountRow(
                  label: 'Base',
                  value: _formatMoney(quote['gross'] ?? 0, 'FCFA'),
                ),
                const SizedBox(height: 8),
                _SubscriptionAmountRow(
                  label: 'Remise',
                  value: '- ${_formatMoney(quote['discount'] ?? 0, 'FCFA')}',
                  valueColor: const Color(0xFF95F08A),
                ),
                const SizedBox(height: 8),
                _SubscriptionAmountRow(
                  label: 'Total a payer',
                  value: _formatMoney(quote['total'] ?? 0, 'FCFA'),
                  emphasis: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            overview.paymentConfigured
                ? 'Choisissez ensuite votre reseau de paiement.'
                : 'CinetPay n est pas encore configure sur le serveur.',
            style: TextStyle(
              color: overview.paymentConfigured
                  ? _meevoMuted
                  : const Color(0xFFB42318),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          if (isDesktop)
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final network in networks)
                  _SubscriptionNetworkCard(
                    label: network.label,
                    subtitle: network.paymentMethodLabel,
                    isSelected: _network == network.code,
                    width: 220,
                    onTap: () => setState(() => _network = network.code),
                  ),
              ],
            )
          else
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                for (final network in networks)
                  _SubscriptionNetworkCard(
                    label: network.label,
                    subtitle: network.paymentMethodLabel,
                    isSelected: _network == network.code,
                    compact: true,
                    onTap: () => setState(() => _network = network.code),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numero mobile money',
              hintText: '90 00 00 00',
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed:
                    !overview.paymentConfigured || state.isSubscriptionStarting
                    ? null
                    : _startCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: _meevoYellow,
                  foregroundColor: _meevoText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                icon: state.isSubscriptionStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_outlined),
                label: const Text('Payer maintenant'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _section = 'payment'),
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Suivi paiement'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSubscriptionTrackingSection({
    required BuildContext context,
    required MeevoState state,
    required SubscriptionPaymentData? recentPayment,
  }) {
    if (recentPayment == null) {
      return const _SectionPanel(
        title: 'Suivi du paiement',
        child: _EmptyStateCard(
          title: 'Aucun paiement en cours',
          subtitle:
              'Lancez une formule pour generer un paiement, puis revenez ici suivre son statut.',
        ),
      );
    }

    return _SectionPanel(
      title: 'Suivi du paiement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width >= 980 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: MediaQuery.sizeOf(context).width >= 980
                ? 2.4
                : 1.8,
            children: [
              _SubscriptionOverviewStatCard(
                icon: Icons.tag_outlined,
                label: 'Reference',
                value: recentPayment.identifier,
                accent: const Color(0xFF4F46E5),
              ),
              _SubscriptionOverviewStatCard(
                icon: Icons.timelapse_outlined,
                label: 'Statut',
                value: recentPayment.status,
                accent: _subscriptionPaymentStatusColor(recentPayment.status),
              ),
              _SubscriptionOverviewStatCard(
                icon: Icons.payments_outlined,
                label: 'Montant',
                value: _formatMoney(recentPayment.totalAmount, 'FCFA'),
                accent: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEAE7F7)),
            ),
            child: const Text(
              '1. Ouvrez CinetPay.\n2. Validez le paiement sur votre telephone.\n3. Revenez ici pour verifier le statut.\n4. Une fois reussi, votre acces partenaire se met a jour.',
              style: TextStyle(color: _meevoMuted, height: 1.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _launchPayment(
                  recentPayment.paymentUrl ?? _lastCheckout?.paymentUrl ?? '',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _meevoYellow,
                  foregroundColor: _meevoText,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir CinetPay'),
              ),
              OutlinedButton.icon(
                onPressed: state.isSubscriptionVerifying
                    ? null
                    : _verifyPayment,
                icon: state.isSubscriptionVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Verifier le paiement'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _section = 'history'),
                icon: const Icon(Icons.history_outlined),
                label: const Text('Voir historique'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSubscriptionHistorySection({
    required SubscriptionOverview overview,
  }) {
    final historyPayments = overview.payments
        .where((payment) => _isFinalSubscriptionPaymentStatus(payment.status))
        .toList();
    return _SectionPanel(
      title: 'Historique abonnement',
      child: historyPayments.isEmpty
          ? const _EmptyStateCard(
              title: 'Aucun paiement finalise pour le moment',
              subtitle:
                  'Les paiements en attente restent dans le suivi. Les paiements finalises apparaitront ici.',
            )
          : Column(
              children: historyPayments.take(12).map((payment) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEAE7F7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _meevoYellow.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.credit_score_outlined,
                          color: _meevoPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${payment.months} mois - ${_formatMoney(payment.totalAmount, 'FCFA')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _meevoDeepBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${payment.network} • ${payment.status}',
                              style: const TextStyle(color: _meevoMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateLabel(payment.paidAt ?? payment.createdAt),
                              style: const TextStyle(color: _meevoMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSubscriptionOverviewSectionV2({
    required BuildContext context,
    required bool isDesktop,
    required MeevoState state,
    required PartnerSubscriptionData? subscription,
    required SubscriptionPaymentData? recentPayment,
    required double monthlyPrice,
  }) {
    final summaryRows = [
      (
        Icons.workspace_premium_outlined,
        'Statut',
        _subscriptionStatusLabel(subscription),
        const Color(0xFF4F46E5),
      ),
      (
        Icons.schedule_outlined,
        'Expiration',
        subscription?.endsAt == null
            ? '--'
            : _formatDisplayDate(subscription!.endsAt!),
        const Color(0xFF2563EB),
      ),
      (
        Icons.payments_outlined,
        'Tarif',
        '${_formatMoney(monthlyPrice, 'FCFA')} / mois',
        const Color(0xFFF59E0B),
      ),
      (
        Icons.receipt_long_outlined,
        'Dernier paiement',
        recentPayment?.status ?? 'Aucun',
        const Color(0xFF16A34A),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subscription?.isActive == true
              ? 'Votre acces partenaire est actif jusqu au ${_dateLabel(subscription?.endsAt)}.'
              : 'Choisissez une formule puis reglez le paiement pour debloquer votre dashboard partenaire.',
          style: const TextStyle(color: _meevoMuted, height: 1.6),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < summaryRows.length; index++) ...[
          _SubscriptionOverviewStatCard(
            icon: summaryRows[index].$1,
            label: summaryRows[index].$2,
            value: summaryRows[index].$3,
            accent: summaryRows[index].$4,
          ),
          if (index < summaryRows.length - 1)
            const Divider(height: 22, color: Color(0xFFEAE7F7)),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => setState(() => _section = 'plans'),
              style: FilledButton.styleFrom(
                backgroundColor: subscription?.isActive == true
                    ? _meevoDeepBlue
                    : _meevoYellow,
                foregroundColor: subscription?.isActive == true
                    ? Colors.white
                    : _meevoText,
              ),
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                subscription?.isActive == true
                    ? 'Renouveler l abonnement'
                    : 'Choisir une formule',
              ),
            ),
            if (recentPayment != null)
              OutlinedButton.icon(
                onPressed: () => setState(() => _section = 'payment'),
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Suivre le paiement'),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _section = 'history'),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Voir l historique'),
            ),
            if (subscription?.isActive == true)
              OutlinedButton.icon(
                onPressed: () => _openDashboard(context),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('Ouvrir le dashboard'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionPlansSectionV2({
    required BuildContext context,
    required bool isDesktop,
    required MeevoState state,
    required SubscriptionOverview overview,
    required Map<String, double> quote,
    required List<SubscriptionPresetData> presets,
    required List<SubscriptionNetworkData> networks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisissez votre formule, ajustez la duree si besoin puis lancez le paiement mobile money.',
          style: TextStyle(color: _meevoMuted, height: 1.6),
        ),
        const SizedBox(height: 18),
        Text(
          'Nombre de mois: $_months',
          style: const TextStyle(
            color: _meevoDeepBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        Slider(
          value: _months.toDouble(),
          min: 1,
          max: overview.maxMonths.toDouble(),
          divisions: overview.maxMonths - 1,
          activeColor: _meevoYellow,
          inactiveColor: const Color(0xFFE7E0FB),
          label: '$_months mois',
          onChanged: (value) => setState(() => _months = value.round()),
        ),
        const SizedBox(height: 10),
        for (final preset in presets) ...[
          _SubscriptionPlanCard(
            title: preset.title,
            subtitle: preset.subtitle,
            badge: preset.badge,
            amountLabel: _formatMoney(preset.totalAmount, 'FCFA'),
            metaLabel:
                '${preset.months} mois • remise ${_formatMoney(preset.discountAmount, 'FCFA')}',
            isSelected: _months == preset.months,
            compact: !isDesktop,
            onTap: () => setState(() => _months = preset.months),
          ),
          const SizedBox(height: 10),
        ],
        _SubscriptionPlanCard(
          title: 'Sur mesure',
          subtitle: 'Choisissez la duree exacte dont vous avez besoin',
          badge: '1 a ${overview.maxMonths} mois',
          amountLabel: _formatMoney(quote['total'] ?? 0, 'FCFA'),
          metaLabel:
              '$_months mois • remise ${_formatMoney(quote['discount'] ?? 0, 'FCFA')}',
          isSelected: !presets.any((item) => item.months == _months),
          compact: !isDesktop,
          onTap: () {},
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFFEAE7F7)),
        const SizedBox(height: 18),
        const Text(
          'Reseau de paiement',
          style: TextStyle(
            color: _meevoDeepBlue,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final network in networks) ...[
          _SubscriptionNetworkCard(
            label: network.label,
            subtitle: network.paymentMethodLabel,
            isSelected: _network == network.code,
            compact: !isDesktop,
            onTap: () => setState(() => _network = network.code),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numero mobile money',
            hintText: '90 00 00 00',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Recapitulatif',
          style: TextStyle(
            color: _meevoDeepBlue,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SubscriptionAmountRow(
          label: 'Base',
          value: _formatMoney(quote['gross'] ?? 0, 'FCFA'),
          valueColor: _meevoDeepBlue,
        ),
        const SizedBox(height: 8),
        _SubscriptionAmountRow(
          label: 'Remise',
          value: '- ${_formatMoney(quote['discount'] ?? 0, 'FCFA')}',
          valueColor: const Color(0xFF16A34A),
        ),
        const SizedBox(height: 8),
        _SubscriptionAmountRow(
          label: 'Total a payer',
          value: _formatMoney(quote['total'] ?? 0, 'FCFA'),
          valueColor: _meevoDeepBlue,
          emphasis: true,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed:
                  !overview.paymentConfigured || state.isSubscriptionStarting
                  ? null
                  : _startCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: _meevoYellow,
                foregroundColor: _meevoText,
              ),
              icon: state.isSubscriptionStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: const Text('Payer maintenant'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _section = 'payment'),
              icon: const Icon(Icons.sync_outlined),
              label: const Text('Verifier le paiement'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionTrackingSectionV2({
    required BuildContext context,
    required MeevoState state,
    required SubscriptionPaymentData? recentPayment,
  }) {
    if (recentPayment == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aucun paiement actif pour le moment. Lancez une formule pour generer une tentative CinetPay.',
            style: TextStyle(color: _meevoMuted, height: 1.6),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _section = 'plans'),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Aller au paiement'),
          ),
        ],
      );
    }

    final trackingRows = [
      (
        Icons.tag_outlined,
        'Reference',
        recentPayment.identifier,
        const Color(0xFF4F46E5),
      ),
      (
        Icons.timelapse_outlined,
        'Statut',
        recentPayment.status,
        _subscriptionPaymentStatusColor(recentPayment.status),
      ),
      (
        Icons.payments_outlined,
        'Montant',
        _formatMoney(recentPayment.totalAmount, 'FCFA'),
        const Color(0xFFF59E0B),
      ),
      (
        Icons.phone_android_outlined,
        'Reseau',
        recentPayment.network == 'TOGOCEL' ? 'Yas / TMoney' : 'Moov / Flooz',
        const Color(0xFF2563EB),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suivez ici votre tentative CinetPay et relancez la verification une fois le paiement valide sur votre telephone.',
          style: TextStyle(color: _meevoMuted, height: 1.6),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < trackingRows.length; index++) ...[
          _SubscriptionOverviewStatCard(
            icon: trackingRows[index].$1,
            label: trackingRows[index].$2,
            value: trackingRows[index].$3,
            accent: trackingRows[index].$4,
          ),
          if (index < trackingRows.length - 1)
            const Divider(height: 22, color: Color(0xFFEAE7F7)),
        ],
        const SizedBox(height: 18),
        for (final step in const [
          'Ouvrez le lien CinetPay.',
          'Validez le paiement mobile money sur votre telephone.',
          'Revenez ensuite ici pour actualiser le statut.',
          'Quand le statut passe a success, le dashboard partenaire se debloque.',
        ]) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _meevoYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: _meevoPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step,
                  style: const TextStyle(color: _meevoMuted, height: 1.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _launchPayment(
                recentPayment.paymentUrl ?? _lastCheckout?.paymentUrl ?? '',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _meevoYellow,
                foregroundColor: _meevoText,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ouvrir CinetPay'),
            ),
            OutlinedButton.icon(
              onPressed: state.isSubscriptionVerifying ? null : _verifyPayment,
              icon: state.isSubscriptionVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Verifier maintenant'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _section = 'history'),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Voir l historique'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionHistorySectionV2({
    required SubscriptionOverview overview,
  }) {
    final historyPayments = overview.payments
        .where((payment) => _isFinalSubscriptionPaymentStatus(payment.status))
        .toList();
    if (historyPayments.isEmpty) {
      return const Text(
        'Aucun paiement finalise pour le moment. Les paiements en attente restent dans le suivi.',
        style: TextStyle(color: _meevoMuted, height: 1.6),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 760),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              const Color(0xFFF7F6FB),
            ),
            columns: const [
              DataColumn(label: Text('Date / Heure')),
              DataColumn(label: Text('Formule')),
              DataColumn(label: Text('Reseau')),
              DataColumn(label: Text('Statut')),
              DataColumn(label: Text('Reference')),
            ],
            rows: [
              for (final payment in historyPayments.take(24))
                DataRow(
                  cells: [
                    DataCell(Text(_dateLabel(payment.paidAt ?? payment.createdAt))),
                    DataCell(
                      Text(
                        '${payment.months} mois • ${_formatMoney(payment.totalAmount, 'FCFA')}',
                      ),
                    ),
                    DataCell(
                      Text(
                        payment.network == 'TOGOCEL'
                            ? 'Yas / TMoney'
                            : 'Moov / Flooz',
                      ),
                    ),
                    DataCell(
                      _AdminStatusBadge(
                        label: payment.status,
                        color: _subscriptionPaymentStatusColor(payment.status),
                      ),
                    ),
                    DataCell(SelectableText(payment.identifier)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSectionSelector extends StatelessWidget {
  const _SubscriptionSectionSelector({
    required this.isDesktop,
    required this.currentSection,
    required this.isActive,
    required this.hasRecentPayment,
    required this.onSelect,
  });

  final bool isDesktop;
  final String currentSection;
  final bool isActive;
  final bool hasRecentPayment;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'overview',
        Icons.dashboard_customize_outlined,
        'Vue',
        isActive ? 'Etat et acces' : 'Etat du compte',
      ),
      (
        'plans',
        Icons.workspace_premium_outlined,
        'Formules',
        isActive ? 'Renouveler' : 'Choisir et payer',
      ),
      (
        'payment',
        Icons.payments_outlined,
        'Paiement',
        hasRecentPayment ? 'Suivre CinetPay' : 'Verifier statut',
      ),
      ('history', Icons.history_outlined, 'Historique', 'Tous les paiements'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in actions)
          ChoiceChip(
            avatar: Icon(
              action.$2,
              size: 18,
              color: currentSection == action.$1 ? Colors.white : _meevoPurple,
            ),
            label: Text(action.$3),
            selected: currentSection == action.$1,
            onSelected: (_) => onSelect(action.$1),
            selectedColor: _meevoDeepBlue,
            labelStyle: TextStyle(
              color: currentSection == action.$1 ? Colors.white : _meevoDeepBlue,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: currentSection == action.$1
                  ? _meevoDeepBlue
                  : const Color(0xFFE7E0F4),
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

// ignore: unused_element
class _SubscriptionActionCard extends StatelessWidget {
  const _SubscriptionActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141E4A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? _meevoYellow : const Color(0xFFEAE7F7),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _meevoPurple.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? _meevoYellow.withValues(alpha: 0.18)
                    : const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? _meevoYellow : _meevoPurple,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : _meevoDeepBlue,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.76)
                    : _meevoMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionOverviewStatCard extends StatelessWidget {
  const _SubscriptionOverviewStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _meevoMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _meevoDeepBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartnerSubscriptionHero extends StatelessWidget {
  const _PartnerSubscriptionHero({
    required this.businessName,
    required this.partnerType,
  });

  final String businessName;
  final String partnerType;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ignore: unused_element
class _PartnerSubscriptionHeroText extends StatelessWidget {
  const _PartnerSubscriptionHeroText();

  @override
  Widget build(BuildContext context) {
    final state = context.read<MeevoState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: const Text(
            'Abonnement premium Meevo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Debloquez votre\nespace partenaire',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.02,
            fontSize: MediaQuery.sizeOf(context).width >= 980 ? null : 22,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${state.currentUser?.partnerProfile?.businessName ?? 'Meevo'} est pret. Activez maintenant le paiement partenaire et ouvrez votre dashboard.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.7,
            fontSize: MediaQuery.sizeOf(context).width >= 980 ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _PartnerSubscriptionHeroStats extends StatelessWidget {
  const _PartnerSubscriptionHeroStats();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final items = const [
      ('50 000', 'FCFA par mois'),
      ('Moov', 'Flooz via CinetPay'),
      ('Yas', 'TMoney via CinetPay'),
      ('Live', 'Acces active apres verification'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : width;
        final cardWidth = isDesktop
            ? ((usableWidth - 12) / 2).clamp(150.0, 220.0).toDouble()
            : ((usableWidth - 12) / 2).clamp(120.0, 180.0).toDouble();
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 18 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: TextStyle(
                            color: _meevoYellow,
                            fontSize: isDesktop ? 24 : 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            fontSize: isDesktop ? 14 : 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.amountLabel,
    required this.metaLabel,
    required this.isSelected,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String amountLabel;
  final String metaLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 13 : 15,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(
              color: isSelected ? _meevoYellow : const Color(0xFFE7E0F4),
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? _meevoYellow.withValues(alpha: 0.22)
                    : const Color(0xFFF7F6FB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                size: 14,
                color: isSelected ? _meevoPurple : _meevoMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 15 : 17,
                      color: _meevoDeepBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _meevoMuted,
                      height: 1.45,
                      fontSize: compact ? 12.5 : 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metaLabel,
                    style: TextStyle(
                      color: _meevoMuted,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 16 : 18,
                    color: _meevoPurple,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge,
                  style: TextStyle(
                    color: isSelected ? _meevoDeepBlue : _meevoMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionNetworkCard extends StatelessWidget {
  const _SubscriptionNetworkCard({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 13 : 15,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isSelected ? _meevoYellow : const Color(0xFFEAE7F7),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 34 : 38,
              height: compact ? 34 : 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? _meevoYellow.withValues(alpha: 0.22)
                    : const Color(0xFFF7F6FB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.phone_android_outlined,
                color: isSelected ? _meevoPurple : _meevoMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _meevoDeepBlue,
                      fontSize: compact ? 14 : 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _meevoMuted,
                      fontSize: compact ? 12.5 : 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: _meevoPurple),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionAmountRow extends StatelessWidget {
  const _SubscriptionAmountRow({
    required this.label,
    required this.value,
    this.valueColor = _meevoDeepBlue,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _meevoMuted,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w800,
            fontSize: emphasis ? 19 : 15,
          ),
        ),
      ],
    );
  }
}

enum _PartnerDashboardSection { overview, bookings, assets, notifications }

class _PartnerDashboard extends StatefulWidget {
  const _PartnerDashboard({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_PartnerDashboard> createState() => _PartnerDashboardState();
}

class _PartnerDashboardState extends State<_PartnerDashboard> {
  _PartnerDashboardSection _mobileSection = _PartnerDashboardSection.overview;

  void _selectMobileSection(_PartnerDashboardSection section) {
    if (_mobileSection == section) return;
    setState(() => _mobileSection = section);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final venueIds = state.myVenues.map((venue) => venue.id).toSet();
    final partnerBookings = state.bookings
        .where((booking) => venueIds.contains(booking.venue?.id))
        .toList();
    final manualBookings = partnerBookings
        .where((booking) => booking.source == 'manual')
        .toList();
    final canVenue = state.hasVenuePartnerAccess;
    final canProvider = state.hasProviderPartnerAccess;
    final hasAssets = canVenue || canProvider;
    final subscription = state.partnerSubscription;
    final isMobile = !widget.isDesktop;

    if (state.isPartnerLoading &&
        state.myVenues.isEmpty &&
        state.myProviders.isEmpty &&
        partnerBookings.isEmpty) {
      return const Card(
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: _meevoPurple)),
        ),
      );
    }

    final heroDescription = canVenue && canProvider
        ? (widget.isDesktop
              ? 'Gerez vos lieux et vos prestations, publiez vos medias Cloudinary et suivez les disponibilites en temps reel.'
              : 'Gerez vos lieux, prestations et alertes depuis un seul espace.')
        : canProvider
        ? (widget.isDesktop
              ? 'Publiez vos prestations, ajoutez vos medias et laissez les clients vous contacter.'
              : 'Publiez vos prestations et suivez vos alertes en direct.')
        : (widget.isDesktop
              ? 'Ajoutez vos lieux, publiez vos medias Cloudinary, bloquez des horaires hors plateforme et suivez les disponibilites en temps reel dans Meevo.'
              : 'Ajoutez vos lieux et pilotez vos reservations depuis Meevo.');

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final monthPrefix = DateFormat('yyyy-MM').format(DateTime.now());
    final todayCount = partnerBookings
        .where((booking) => booking.eventDate == todayKey)
        .length;
    final monthCount = partnerBookings
        .where((booking) => booking.eventDate.startsWith(monthPrefix))
        .length;
    final notifications = _buildPartnerNotificationItems(
      subscription: subscription,
      realtimeConnected: state.realtimeConnected,
    );

    final mobileSections = <_PartnerDashboardSection>[
      _PartnerDashboardSection.overview,
      if (canVenue) _PartnerDashboardSection.bookings,
      if (hasAssets) _PartnerDashboardSection.assets,
      _PartnerDashboardSection.notifications,
    ];
    final activeSection = mobileSections.contains(_mobileSection)
        ? _mobileSection
        : _PartnerDashboardSection.overview;
    if (activeSection != _mobileSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mobileSection = activeSection);
      });
    }

    final assetActionTitle = canVenue ? 'Mes lieux' : 'Mes prestations';
    final assetActionSubtitle = canVenue && canProvider
        ? 'Voir vos lieux, prestations et planning.'
        : canVenue
        ? 'Voir vos lieux ajoutes et leur planning.'
        : 'Voir vos prestations publiees.';

    Widget buildHeroCard() {
      return Container(
        padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_meevoDeepBlue, _meevoPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(widget.isDesktop ? 28 : 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard partenaire',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: widget.isDesktop ? null : 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              heroDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.55,
                fontSize: widget.isDesktop ? 14 : 13,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (canVenue)
                  _PartnerMetricChip(
                    icon: Icons.meeting_room_outlined,
                    label: '${state.myVenues.length} lieux',
                  ),
                if (canProvider)
                  _PartnerMetricChip(
                    icon: Icons.storefront_outlined,
                    label: '${state.myProviders.length} prestations',
                  ),
                if (canVenue)
                  _PartnerMetricChip(
                    icon: Icons.receipt_long_outlined,
                    label: '${partnerBookings.length} reservations',
                  ),
                _PartnerMetricChip(
                  icon: state.realtimeConnected
                      ? Icons.wifi_tethering
                      : Icons.wifi_tethering_off,
                  label: state.realtimeConnected
                      ? 'Temps reel actif'
                      : 'Temps reel hors ligne',
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildActionsPanel() {
      final actions = <Widget>[
        if (canVenue)
          _DashboardActionCard(
            icon: Icons.add_business_outlined,
            title: 'Ajouter un lieu',
            subtitle: 'Publiez une salle, hotel ou espace.',
            onTap: () => _openAddVenuePage(context),
          ),
        _DashboardActionCard(
          icon: Icons.storefront_outlined,
          title: 'Ajouter une prestation',
          subtitle: 'Traiteur, sonorisateur, location ou hotesse.',
          onTap: () => _openAddProviderPage(context),
        ),
        if (canVenue)
          _DashboardActionCard(
            icon: Icons.receipt_long_outlined,
            title: 'Reservations recues',
            subtitle: 'Suivre les reservations confirmees de vos lieux.',
            onTap: () => isMobile
                ? _selectMobileSection(_PartnerDashboardSection.bookings)
                : _openPartnerBookings(context),
          ),
        if (hasAssets)
          _DashboardActionCard(
            icon: canVenue
                ? Icons.home_work_outlined
                : Icons.inventory_2_outlined,
            title: assetActionTitle,
            subtitle: assetActionSubtitle,
            onTap: () => isMobile
                ? _selectMobileSection(_PartnerDashboardSection.assets)
                : _openPartnerAssetsPage(context),
          ),
        _DashboardActionCard(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Voir vos alertes abonnement et temps reel.',
          onTap: () => isMobile
              ? _selectMobileSection(_PartnerDashboardSection.notifications)
              : _openPartnerNotificationsPage(context),
        ),
        _DashboardActionCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Mon abonnement',
          subtitle: subscription?.isActive == true
              ? 'Suivre, renouveler et verifier votre abonnement.'
              : 'Activer ou reprendre votre abonnement partenaire.',
          onTap: () => _openPartnerSubscriptionPage(context),
        ),
        if (canVenue)
          _DashboardActionCard(
            icon: Icons.payments_outlined,
            title: 'Paiements recus',
            subtitle:
                'Transactions confirmees, commission Meevo et net partenaire.',
            onTap: () => _openPartnerRevenuePage(context),
          ),
        if (canVenue)
          _DashboardActionCard(
            icon: Icons.event_busy_outlined,
            title: 'Reservation hors plateforme',
            subtitle: 'Bloquez un horaire et archivez.',
            onTap: () => _openManualBookingPage(context),
          ),
      ];

      return _SectionPanel(
        title: 'Actions rapides',
        child: widget.isDesktop
            ? Wrap(spacing: 12, runSpacing: 12, children: actions)
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.46,
                children: actions,
              ),
      );
    }

    List<Widget> buildOverviewContent() {
      return [
        buildHeroCard(),
        const SizedBox(height: 16),
        buildActionsPanel(),
        const SizedBox(height: 16),
        _PartnerSubscriptionStatusPanel(subscription: subscription),
        const SizedBox(height: 16),
        _PartnerStatsPanel(
          totalBookings: partnerBookings.length,
          manualBookings: manualBookings.length,
          todayBookings: todayCount,
          monthBookings: monthCount,
          bookings: partnerBookings,
        ),
      ];
    }

    List<Widget> buildBookingsContent() {
      if (!canVenue) return const [];
      return [
        _PartnerBookingsSummary(
          count: partnerBookings.length,
          onOpen: () => _openPartnerBookings(context),
        ),
        const SizedBox(height: 16),
        _PartnerBookingsPanel(bookings: partnerBookings, withPanel: true),
      ];
    }

    List<Widget> buildAssetsContent() {
      if (!hasAssets) {
        return const [
          _EmptyStateCard(
            title: 'Aucun contenu partenaire',
            subtitle:
                'Ajoutez vos lieux ou vos prestations pour commencer a utiliser cet espace.',
          ),
        ];
      }

      return [
        if (canVenue)
          _SectionPanel(
            title: 'Mes lieux',
            child: _VenuePreviewList(
              venues: state.myVenues,
              onViewAll: () => _openMyVenuesPage(context),
            ),
          ),
        if (canVenue && canProvider) const SizedBox(height: 16),
        if (canProvider)
          _SectionPanel(
            title: 'Mes prestations',
            child: _ProviderPreviewList(
              providers: state.myProviders,
              onViewAll: () => _openMyProvidersPage(context),
            ),
          ),
        if (canVenue) ...[
          const SizedBox(height: 16),
          _DashboardSectionAccordion(
            icon: Icons.calendar_month_outlined,
            title: 'Planning temps reel',
            subtitle: 'Selectionnez un lieu et suivez le calendrier.',
            child: _PartnerVenuePlanner(
              isDesktop: widget.isDesktop,
              withPanel: false,
            ),
          ),
        ],
      ];
    }

    List<Widget> buildNotificationsContent() {
      return [
        _PartnerNotificationsPanel(
          subscription: subscription,
          realtimeConnected: state.realtimeConnected,
        ),
        if (notifications.isNotEmpty) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${notifications.length} notification(s) active(s)',
              style: const TextStyle(
                color: _meevoMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ];
    }

    if (widget.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...buildOverviewContent(),
          const SizedBox(height: 16),
          _PartnerNotificationsPanel(
            subscription: subscription,
            realtimeConnected: state.realtimeConnected,
          ),
          if (canVenue) ...[
            const SizedBox(height: 16),
            _PartnerBookingsSummary(
              count: partnerBookings.length,
              onOpen: () => _openPartnerBookings(context),
            ),
          ],
          if (canVenue) ...[
            const SizedBox(height: 16),
            _SectionPanel(
              title: 'Mes lieux',
              child: _VenuePreviewList(
                venues: state.myVenues,
                onViewAll: () => _openMyVenuesPage(context),
              ),
            ),
          ],
          if (canProvider) ...[
            const SizedBox(height: 16),
            _SectionPanel(
              title: 'Mes prestations',
              child: _ProviderPreviewList(
                providers: state.myProviders,
                onViewAll: () => _openMyProvidersPage(context),
              ),
            ),
          ],
          if (canVenue) ...[
            const SizedBox(height: 16),
            _DashboardSectionAccordion(
              icon: Icons.calendar_month_outlined,
              title: 'Planning temps reel',
              subtitle: 'Selectionnez un lieu et suivez le calendrier.',
              child: _PartnerVenuePlanner(
                isDesktop: widget.isDesktop,
                withPanel: false,
              ),
            ),
          ],
        ],
      );
    }

    final mobileContent = switch (activeSection) {
      _PartnerDashboardSection.overview => buildOverviewContent(),
      _PartnerDashboardSection.bookings => buildBookingsContent(),
      _PartnerDashboardSection.assets => buildAssetsContent(),
      _PartnerDashboardSection.notifications => buildNotificationsContent(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PartnerDashboardSectionTabs(
          sections: mobileSections,
          selectedSection: activeSection,
          canVenue: canVenue,
          canProvider: canProvider,
          onSelected: _selectMobileSection,
        ),
        const SizedBox(height: 16),
        ...mobileContent,
      ],
    );
  }
}

class _PartnerDashboardSectionTabs extends StatelessWidget {
  const _PartnerDashboardSectionTabs({
    required this.sections,
    required this.selectedSection,
    required this.canVenue,
    required this.canProvider,
    required this.onSelected,
  });

  final List<_PartnerDashboardSection> sections;
  final _PartnerDashboardSection selectedSection;
  final bool canVenue;
  final bool canProvider;
  final ValueChanged<_PartnerDashboardSection> onSelected;

  String _labelFor(_PartnerDashboardSection section) {
    switch (section) {
      case _PartnerDashboardSection.overview:
        return 'Vue';
      case _PartnerDashboardSection.bookings:
        return 'Reservations';
      case _PartnerDashboardSection.assets:
        if (canVenue) return 'Lieux';
        if (canProvider) return 'Prestations';
        return 'Activites';
      case _PartnerDashboardSection.notifications:
        return 'Notifications';
    }
  }

  IconData _iconFor(_PartnerDashboardSection section) {
    switch (section) {
      case _PartnerDashboardSection.overview:
        return Icons.dashboard_outlined;
      case _PartnerDashboardSection.bookings:
        return Icons.receipt_long_outlined;
      case _PartnerDashboardSection.assets:
        return canVenue
            ? Icons.meeting_room_outlined
            : Icons.storefront_outlined;
      case _PartnerDashboardSection.notifications:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sections.map((section) {
            final isSelected = section == selectedSection;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? _meevoPurple : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(section),
                      size: 16,
                      color: isSelected ? _meevoPurple : _meevoMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _labelFor(section),
                      style: TextStyle(
                        color: isSelected ? _meevoPurple : _meevoMuted,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PartnerBookingsSummary extends StatelessWidget {
  const _PartnerBookingsSummary({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _meevoYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: _meevoPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reservations recues',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _meevoDeepBlue,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count reservation(s) enregistre(es)',
                  style: const TextStyle(color: _meevoMuted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }
}

class _PartnerBookingsPanel extends StatelessWidget {
  const _PartnerBookingsPanel({required this.bookings, this.withPanel = true});

  final List<BookingItem> bookings;
  final bool withPanel;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    Future<void> confirmDelete(BookingItem booking) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Supprimer la reservation ?'),
          content: const Text('Cette reservation sera retiree du dashboard.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await state.deleteBooking(booking);
      }
    }

    final body = bookings.isEmpty
        ? const Text(
            'Toutes les reservations de vos lieux apparaitront ici automatiquement, y compris celles ajoutees manuellement pour bloquer le planning.',
            style: TextStyle(color: _meevoMuted, height: 1.55),
          )
        : Column(
            children: bookings.map((booking) {
              final canDelete =
                  state.currentUser?.role == 'admin' ||
                  booking.source == 'manual';
              final venue = booking.venue;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEAE7F7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _meevoYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_seat_outlined,
                        color: _meevoPurple,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venue?.name ?? 'Lieu',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${booking.eventType} • ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(booking.eventDate) ?? DateTime.now())} • ${booking.startTime} - ${booking.endTime}',
                            style: const TextStyle(
                              color: _meevoMuted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${booking.customerName ?? 'Client'} • ${booking.guestCount} invites • ${booking.source == 'manual' ? 'Hors plateforme' : 'Meevo'}',
                            style: const TextStyle(
                              color: _meevoMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (canDelete)
                      IconButton(
                        onPressed: () => confirmDelete(booking),
                        icon: const Icon(Icons.delete_outline),
                        color: const Color(0xFFB93E3E),
                        tooltip: 'Supprimer',
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _bookingStatusColor(
                          booking.status,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        booking.status,
                        style: TextStyle(
                          color: _bookingStatusColor(booking.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );

    if (!withPanel) {
      return body;
    }

    return _SectionPanel(title: 'Reservations recues', child: body);
  }
}

class _PartnerMetricChip extends StatelessWidget {
  const _PartnerMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerSubscriptionStatusPanel extends StatelessWidget {
  const _PartnerSubscriptionStatusPanel({required this.subscription});

  final PartnerSubscriptionData? subscription;

  String _statusLabel() {
    if (subscription == null) return 'Abonnement non configure';
    switch (subscription!.status) {
      case 'active':
        return 'Actif';
      case 'pending':
        return 'En attente';
      case 'expired':
        return 'Expire';
      case 'cancelled':
        return 'Annule';
      default:
        return 'Inactif';
    }
  }

  int? _daysRemaining() {
    final rawEndsAt = subscription?.endsAt;
    if (rawEndsAt == null || rawEndsAt.isEmpty) return null;
    final parsed = DateTime.tryParse(rawEndsAt);
    if (parsed == null) return null;
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    return target.difference(current).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = _daysRemaining();
    final isActive = subscription?.isActive == true;
    final accent = isActive
        ? (daysRemaining != null && daysRemaining <= 7
              ? const Color(0xFFF59E0B)
              : const Color(0xFF16A34A))
        : const Color(0xFFB42318);
    final subtitle = switch ((subscription?.status ?? 'inactive')) {
      'active' when daysRemaining == null => 'Votre abonnement est actif.',
      'active' when daysRemaining == 0 =>
        'Expiration aujourd hui. Renouvelez maintenant.',
      'active' when daysRemaining == 1 =>
        'Expiration demain. Renouvelez pour eviter une coupure.',
      'active' when daysRemaining != null =>
        'Encore $daysRemaining jours avant expiration.',
      'pending' => 'Paiement en attente de validation CinetPay.',
      'expired' =>
        'Votre acces partenaire est suspendu tant que vous ne renouvelez pas.',
      'cancelled' => 'Votre abonnement a ete annule.',
      _ =>
        'Activez votre abonnement pour utiliser toutes les fonctions partenaire.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.workspace_premium_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Abonnement partenaire',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _meevoDeepBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _meevoMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(icon: Icons.verified_outlined, label: _statusLabel()),
              _DetailChip(
                icon: Icons.calendar_month_outlined,
                label: subscription?.endsAt == null
                    ? 'Fin non definie'
                    : 'Expire le ${_formatDisplayDate(subscription!.endsAt!)}',
              ),
              _DetailChip(
                icon: Icons.payments_outlined,
                label:
                    '${_formatMoney(subscription?.monthlyPrice ?? 50000, 'FCFA')} / mois',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openPartnerSubscriptionPage(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _meevoYellow,
                  foregroundColor: _meevoText,
                ),
                icon: const Icon(Icons.sync_outlined),
                label: Text(
                  isActive ? 'Suivre / renouveler' : 'Activer / renouveler',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openPartnerSubscriptionPage(context),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Voir les paiements'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<_PartnerNotificationItemData> _buildPartnerNotificationItems({
  required PartnerSubscriptionData? subscription,
  required bool realtimeConnected,
}) {
  final alerts = <_PartnerNotificationItemData>[];
  final rawEndsAt = subscription?.endsAt;
  int? daysRemaining;
  if (rawEndsAt != null && rawEndsAt.isNotEmpty) {
    final parsed = DateTime.tryParse(rawEndsAt);
    if (parsed != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      daysRemaining = target.difference(today).inDays;
    }
  }

  if (subscription?.status == 'pending') {
    alerts.add(
      const _PartnerNotificationItemData(
        icon: Icons.pending_actions_outlined,
        accent: Color(0xFF2563EB),
        title: 'Paiement en attente',
        message:
            'Finalisez le paiement CinetPay ou relancez la verification pour debloquer votre abonnement.',
      ),
    );
  } else if (subscription?.status == 'expired' ||
      (subscription?.isActive != true &&
          daysRemaining != null &&
          daysRemaining < 0)) {
    alerts.add(
      const _PartnerNotificationItemData(
        icon: Icons.warning_amber_rounded,
        accent: Color(0xFFB42318),
        title: 'Abonnement expire',
        message:
            'Vos outils partenaire doivent etre renouveles pour continuer a recevoir et gerer vos activites.',
      ),
    );
  } else if (subscription?.isActive == true && daysRemaining != null) {
    if (daysRemaining == 0) {
      alerts.add(
        const _PartnerNotificationItemData(
          icon: Icons.error_outline,
          accent: Color(0xFFF59E0B),
          title: 'Expiration aujourd hui',
          message:
              'Votre abonnement se termine aujourd hui. Renouvelez immediatement pour eviter une coupure.',
        ),
      );
    } else if (daysRemaining == 1) {
      alerts.add(
        const _PartnerNotificationItemData(
          icon: Icons.notifications_active_outlined,
          accent: Color(0xFFF59E0B),
          title: 'Expiration demain',
          message:
              'Votre abonnement se termine demain. Pensez a le renouveler aujourd hui.',
        ),
      );
    } else if (daysRemaining <= 7) {
      alerts.add(
        _PartnerNotificationItemData(
          icon: Icons.schedule_outlined,
          accent: const Color(0xFFF59E0B),
          title: 'Expiration proche',
          message:
              'Votre abonnement expire dans $daysRemaining jours. Renouvelez maintenant pour garder vos lieux et prestations actifs.',
        ),
      );
    } else {
      alerts.add(
        _PartnerNotificationItemData(
          icon: Icons.verified_outlined,
          accent: const Color(0xFF16A34A),
          title: 'Abonnement actif',
          message:
              'Tout est en ordre. Votre abonnement reste actif jusqu au ${_formatDisplayDate(subscription!.endsAt!)}.',
        ),
      );
    }
  } else {
    alerts.add(
      const _PartnerNotificationItemData(
        icon: Icons.workspace_premium_outlined,
        accent: Color(0xFFB42318),
        title: 'Abonnement a activer',
        message:
            'Activez votre abonnement partenaire pour utiliser le dashboard, publier et gerer vos activites.',
      ),
    );
  }

  if (!realtimeConnected) {
    alerts.add(
      const _PartnerNotificationItemData(
        icon: Icons.wifi_tethering_off,
        accent: Color(0xFF7C3AED),
        title: 'Temps reel hors ligne',
        message:
            'La connexion instantanee est momentanement indisponible. Meevo se reconnectera automatiquement.',
      ),
    );
  }

  return alerts;
}

class _PartnerNotificationsPanel extends StatelessWidget {
  const _PartnerNotificationsPanel({
    required this.subscription,
    required this.realtimeConnected,
  });

  final PartnerSubscriptionData? subscription;
  final bool realtimeConnected;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildPartnerNotificationItems(
      subscription: subscription,
      realtimeConnected: realtimeConnected,
    );

    return _SectionPanel(
      title: 'Notifications',
      child: Column(
        children: [
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PartnerNotificationItem(
                data: alert,
                onTap: () => _openPartnerSubscriptionPage(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartnerNotificationItemData {
  const _PartnerNotificationItemData({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
}

class _PartnerNotificationItem extends StatelessWidget {
  const _PartnerNotificationItem({required this.data, required this.onTap});

  final _PartnerNotificationItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _meevoDeepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.message,
                  style: const TextStyle(color: _meevoMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onTap, child: const Text('Voir')),
        ],
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 230;
        final cardWidth = constraints.maxWidth < 420 ? double.infinity : 260.0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: cardWidth,
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAE7F7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 36 : 42,
                  height: compact ? 36 : 42,
                  decoration: BoxDecoration(
                    color: _meevoYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  ),
                  child: Icon(
                    icon,
                    color: _meevoPurple,
                    size: compact ? 18 : 22,
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _meevoDeepBlue,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  subtitle,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _meevoMuted,
                    height: 1.35,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardEntityRow extends StatelessWidget {
  const _DashboardEntityRow({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.actionLabel = 'Voir plus',
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 58,
              height: 58,
              child: imageUrl.isEmpty
                  ? _placeholderMedia('Photo')
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholderMedia('Photo'),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _meevoText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _meevoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _meevoPurple),
              foregroundColor: _meevoPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _VenuePreviewList extends StatelessWidget {
  const _VenuePreviewList({
    required this.venues,
    this.onViewAll,
    this.maxItems = 4,
  });

  final List<Venue> venues;
  final VoidCallback? onViewAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return const Text(
        'Aucun lieu ajoute pour le moment.',
        style: TextStyle(color: _meevoMuted, height: 1.55),
      );
    }

    final items = venues.take(maxItems).toList();

    return Column(
      children: [
        ...items.map(
          (venue) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DashboardEntityRow(
              title: venue.name,
              subtitle: venue.locationLabel,
              imageUrl: venue.primaryImage,
              onTap: () => _openEditVenuePage(context, venue),
              actionLabel: 'Modifier',
            ),
          ),
        ),
        if (onViewAll != null && venues.length > maxItems)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Voir tous les lieux'),
            ),
          ),
      ],
    );
  }
}

class _ProviderPreviewList extends StatelessWidget {
  const _ProviderPreviewList({
    required this.providers,
    this.onViewAll,
    this.maxItems = 4,
  });

  final List<ProviderProfile> providers;
  final VoidCallback? onViewAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const Text(
        'Aucune prestation publiee pour le moment.',
        style: TextStyle(color: _meevoMuted, height: 1.55),
      );
    }

    final items = providers.take(maxItems).toList();

    return Column(
      children: [
        ...items.map(
          (provider) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DashboardEntityRow(
              title: provider.name,
              subtitle: provider.category,
              imageUrl: provider.photoUrl ?? '',
              onTap: () => _openEditProviderPage(context, provider),
              actionLabel: 'Modifier',
            ),
          ),
        ),
        if (onViewAll != null && providers.length > maxItems)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Voir toutes les prestations'),
            ),
          ),
      ],
    );
  }
}

class _ManualBookingPreviewList extends StatelessWidget {
  const _ManualBookingPreviewList({
    required this.bookings,
    required this.onViewAll,
  });

  final List<BookingItem> bookings;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Text(
        'Aucune reservation hors plateforme enregistree.',
        style: TextStyle(color: _meevoMuted, height: 1.55),
      );
    }

    final items = bookings.take(4).toList();

    return Column(
      children: [
        ...items.map(
          (booking) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ManualBookingRow(booking: booking),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Historique complet'),
          ),
        ),
      ],
    );
  }
}

class _ManualBookingRow extends StatelessWidget {
  const _ManualBookingRow({required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(booking.eventDate);
    final dateLabel = date == null
        ? booking.eventDate
        : DateFormat('dd/MM/yyyy').format(date);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _meevoYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_busy_outlined, color: _meevoPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.venue?.name ?? 'Lieu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel • ${booking.startTime} - ${booking.endTime}',
                  style: const TextStyle(color: _meevoMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.customerName ?? 'Client'} • ${booking.guestCount} invites',
                  style: const TextStyle(color: _meevoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _bookingStatusColor(
                booking.status,
              ).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              booking.status,
              style: TextStyle(
                color: _bookingStatusColor(booking.status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerStatsPanel extends StatelessWidget {
  const _PartnerStatsPanel({
    required this.totalBookings,
    required this.manualBookings,
    required this.todayBookings,
    required this.monthBookings,
    required this.bookings,
  });

  final int totalBookings;
  final int manualBookings;
  final int todayBookings;
  final int monthBookings;
  final List<BookingItem> bookings;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatsChartPoint(
        label: 'Aujourd hui',
        value: todayBookings,
        color: const Color(0xFF7A6AF6),
      ),
      _StatsChartPoint(
        label: 'Ce mois',
        value: monthBookings,
        color: const Color(0xFF3C78FF),
      ),
      _StatsChartPoint(
        label: 'Hors plateforme',
        value: manualBookings,
        color: const Color(0xFFF2A900),
      ),
      _StatsChartPoint(
        label: 'Total',
        value: totalBookings,
        color: const Color(0xFF1E2E9B),
      ),
    ];

    return _SectionPanel(
      title: 'Statistiques rapides',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats
                .map(
                  (item) => Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7FC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEAE7F7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: _meevoMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.value.toString(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _meevoDeepBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openPartnerBookings(context),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Voir reservations'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openManualBookingsHistoryPage(context),
                icon: const Icon(Icons.history),
                label: const Text('Hors plateforme'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsChartPoint {
  const _StatsChartPoint({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _PartnerVenuePlanner extends StatefulWidget {
  const _PartnerVenuePlanner({required this.isDesktop, this.withPanel = true});

  final bool isDesktop;
  final bool withPanel;

  @override
  State<_PartnerVenuePlanner> createState() => _PartnerVenuePlannerState();
}

class _PartnerVenuePlannerState extends State<_PartnerVenuePlanner> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String? _selectedVenueId;
  Future<VenueAvailability>? _availabilityFuture;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final venues = state.myVenues;

    if (venues.isEmpty) {
      return const _EmptyStateCard(
        title: 'Aucun lieu partenaire pour le moment',
        subtitle:
            'Ajoutez votre premiere salle, hotel ou espace pour commencer a recevoir des reservations reelles.',
      );
    }

    _ensureVenueSelection(venues, state);
    final selectedVenue = venues.firstWhere(
      (venue) => venue.id == _selectedVenueId,
      orElse: () => venues.first,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chaque reservation Meevo ou ajout manuel bloque automatiquement le calendrier visible dans l APK.',
          style: TextStyle(color: _meevoMuted, height: 1.55),
        ),
        const SizedBox(height: 18),
        widget.isDesktop
            ? Wrap(
                spacing: 14,
                runSpacing: 14,
                children: venues
                    .map(
                      (venue) => SizedBox(
                        width: 320,
                        child: _OwnedVenueCard(
                          venue: venue,
                          isSelected: venue.id == selectedVenue.id,
                          onTap: () {
                            setState(() {
                              _selectedVenueId = venue.id;
                              _availabilityFuture = _fetchAvailability(
                                state,
                                venue.id,
                              );
                            });
                          },
                        ),
                      ),
                    )
                    .toList(),
              )
            : Column(
                children: venues
                    .map(
                      (venue) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _OwnedVenueCard(
                          venue: venue,
                          isSelected: venue.id == selectedVenue.id,
                          onTap: () {
                            setState(() {
                              _selectedVenueId = venue.id;
                              _availabilityFuture = _fetchAvailability(
                                state,
                                venue.id,
                              );
                            });
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
        const SizedBox(height: 18),
        if (widget.isDesktop)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('planner-desktop-${_selectedVenueId ?? ''}'),
                  initialValue: _selectedVenueId,
                  decoration: const InputDecoration(labelText: 'Lieu'),
                  items: venues
                      .map(
                        (venue) => DropdownMenuItem<String>(
                          value: venue.id,
                          child: Text(venue.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedVenueId = value;
                      _availabilityFuture = _fetchAvailability(state, value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: _meevoBackground,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  subtitle: const Text('Jour observe'),
                  onTap: () => _pickDate(state),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _availabilityFuture = _fetchAvailability(
                      state,
                      selectedVenue.id,
                      forceRefresh: true,
                    );
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _meevoYellow,
                  foregroundColor: _meevoText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraichir'),
              ),
            ],
          )
        else
          Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('planner-mobile-${_selectedVenueId ?? ''}'),
                initialValue: _selectedVenueId,
                decoration: const InputDecoration(labelText: 'Lieu'),
                items: venues
                    .map(
                      (venue) => DropdownMenuItem<String>(
                        value: venue.id,
                        child: Text(venue.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedVenueId = value;
                    _availabilityFuture = _fetchAvailability(state, value);
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: _meevoBackground,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                subtitle: const Text('Jour observe'),
                onTap: () => _pickDate(state),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _availabilityFuture = _fetchAvailability(
                        state,
                        selectedVenue.id,
                        forceRefresh: true,
                      );
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _meevoYellow,
                    foregroundColor: _meevoText,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraichir'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        FutureBuilder<VenueAvailability>(
          future: _availabilityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: CircularProgressIndicator(color: _meevoPurple),
                ),
              );
            }

            if (snapshot.hasError) {
              return const _ScheduleEmptyState(
                title: 'Planning indisponible',
                subtitle:
                    'Impossible de recuperer la disponibilite de ce lieu pour le moment.',
              );
            }

            final availability =
                snapshot.data ?? const VenueAvailability.empty();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BusinessHoursBanner(
                  businessHours: availability.businessHours,
                  isBlockedDate: availability.blockedDates.contains(
                    _formatApiDate(_selectedDate),
                  ),
                ),
                const SizedBox(height: 14),
                _AvailabilityTimeline(
                  availability: availability,
                  emptyLabel:
                      'Aucune occupation detectee sur cette date. La salle est entierement libre.',
                ),
              ],
            );
          },
        ),
      ],
    );

    if (!widget.withPanel) {
      return body;
    }

    return _SectionPanel(
      title: 'Mes lieux et planning temps reel',
      child: body,
    );
  }

  void _ensureVenueSelection(List<Venue> venues, MeevoState state) {
    if (venues.isEmpty) return;

    final hasSelectedVenue = venues.any(
      (venue) => venue.id == _selectedVenueId,
    );
    if (_selectedVenueId == null || !hasSelectedVenue) {
      _selectedVenueId = venues.first.id;
      _availabilityFuture = _fetchAvailability(state, venues.first.id);
    }
  }

  Future<VenueAvailability> _fetchAvailability(
    MeevoState state,
    String venueId, {
    bool forceRefresh = false,
  }) {
    return state.fetchAvailability(
      venueId: venueId,
      date: _selectedDate,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _pickDate(MeevoState state) async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _selectedDate,
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _availabilityFuture = _fetchAvailability(state, _selectedVenueId!);
    });
  }
}

class _OwnedVenueCard extends StatelessWidget {
  const _OwnedVenueCard({
    required this.venue,
    required this.isSelected,
    required this.onTap,
  });

  final Venue venue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F1FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _meevoPurple : const Color(0xFFEAE7F7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: venue.primaryImage.isEmpty
                    ? _placeholderMedia('Aucune photo')
                    : Image.network(
                        venue.primaryImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _placeholderMedia('Image indisponible'),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _meevoYellow.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    venue.venueType,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              venue.locationLabel,
              style: const TextStyle(color: _meevoMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniTag(
                  icon: Icons.people_outline,
                  label: '${venue.capacity} places',
                ),
                _MiniTag(
                  icon: Icons.schedule_outlined,
                  label:
                      '${venue.businessHours.opensAt} - ${venue.businessHours.closesAt}',
                ),
              ],
            ),
            if (_buildVenueMapsUri(venue) != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _launchUrl(_buildVenueMapsUri(venue)!),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Localisation'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddVenueForm extends StatefulWidget {
  const _AddVenueForm({required this.isDesktop, this.wrapInPanel = true});

  final bool isDesktop;
  final bool wrapInPanel;

  @override
  State<_AddVenueForm> createState() => _AddVenueFormState();
}

class _AddVenueFormState extends State<_AddVenueForm> {
  static const _venueTypes = [
    'salle',
    'hotel',
    'espace',
    'villa',
    'restaurant',
  ];

  final _nameController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _districtController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _customEventTypeController = TextEditingController();
  final _customAmenityController = TextEditingController();
  final List<String> _selectedEventTypes = [];
  final List<String> _customEventTypes = [];
  final List<String> _selectedAmenities = [];
  final List<String> _customAmenities = [];
  String _venueType = _venueTypes.first;
  String _opensAt = '08:00';
  String _closesAt = '23:00';
  String _coverPhoto = '';
  String _videoUrl = '';
  final List<String> _galleryPhotos = [];
  bool _isLocating = false;
  ResolvedLocationData? _resolvedLocation;

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    _districtController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _customEventTypeController.dispose();
    _customAmenityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Renseignez les vraies informations du lieu: capacite, prix, horaires et medias Cloudinary. La localisation du lieu est detectee automatiquement et rien n est simule.',
          style: TextStyle(color: _meevoMuted, height: 1.55),
        ),
        const SizedBox(height: 18),
        _ResponsiveFormRow(
          isDesktop: widget.isDesktop,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom du lieu'),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('venue-type-$_venueType'),
              initialValue: _venueType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _venueTypes
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _venueType = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAE7F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Localisation automatique du lieu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _resolvedLocation == null
                    ? 'Le partenaire doit autoriser sa position. Meevo detecte ensuite la ville, le quartier, l adresse, les coordonnees et le lien Maps sans saisie manuelle.'
                    : 'Localisation detectee et enregistree automatiquement pour ce lieu.',
                style: const TextStyle(color: _meevoMuted, height: 1.5),
              ),
              if (_resolvedLocation != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_resolvedLocation!.city.isNotEmpty)
                      _DetailChip(
                        icon: Icons.location_city_outlined,
                        label: _resolvedLocation!.city,
                      ),
                    if (_resolvedLocation!.district.isNotEmpty)
                      _DetailChip(
                        icon: Icons.place_outlined,
                        label: _resolvedLocation!.district,
                      ),
                    _DetailChip(
                      icon: Icons.near_me_outlined,
                      label:
                          '${_resolvedLocation!.latitude.toStringAsFixed(5)}, ${_resolvedLocation!.longitude.toStringAsFixed(5)}',
                    ),
                  ],
                ),
                if (_resolvedLocation!.address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _resolvedLocation!.address,
                    style: const TextStyle(color: _meevoMuted, height: 1.45),
                  ),
                ],
              ],
              if (_resolvedLocation == null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLocating || state.isPartnerSaving
                        ? null
                        : _detectLocation,
                    style: FilledButton.styleFrom(
                      backgroundColor: _meevoPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    icon: _isLocating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('Activer la localisation'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _districtController,
          decoration: const InputDecoration(
            labelText: 'Quartier',
            helperText: 'Detecte automatiquement, modifiable si necessaire',
          ),
        ),
        const SizedBox(height: 12),
        _ResponsiveFormRow(
          isDesktop: widget.isDesktop,
          children: [
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacite'),
            ),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix de depart (FCFA)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ResponsiveFormRow(
          isDesktop: widget.isDesktop,
          children: [
            _TimeFieldTile(
              label: 'Ouverture',
              value: _opensAt,
              onTap: () => _pickBusinessHour(isOpening: true),
            ),
            _TimeFieldTile(
              label: 'Fermeture',
              value: _closesAt,
              onTap: () => _pickBusinessHour(isOpening: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _shortDescriptionController,
          decoration: const InputDecoration(labelText: 'Description courte'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description detaillee'),
        ),
        const SizedBox(height: 12),
        _MultiSelectOptionEditor(
          title: 'Types d evenements',
          subtitle:
              'Choisissez tous les evenements que ce lieu peut recevoir. Vous pouvez aussi ajouter vos propres types.',
          options: _venueEventTypeOptions,
          selectedOptions: _selectedEventTypes,
          customOptions: _customEventTypes,
          customController: _customEventTypeController,
          addButtonLabel: 'Ajouter un autre type',
          customHintText: 'Ex: soiree cinema, meetup, showcase...',
          onToggleOption: _toggleEventType,
          onAddCustomOption: _addCustomEventType,
          onRemoveCustomOption: _removeCustomEventType,
        ),
        const SizedBox(height: 12),
        _MultiSelectOptionEditor(
          title: 'Equipements et services',
          subtitle:
              'Cochez tous les equipements disponibles sur place. Ajoutez aussi les options specifiques de votre salle si besoin.',
          options: _venueAmenityOptions,
          selectedOptions: _selectedAmenities,
          customOptions: _customAmenities,
          customController: _customAmenityController,
          addButtonLabel: 'Ajouter un autre equipement',
          customHintText: 'Ex: loge artiste, drone, borne selfie...',
          onToggleOption: _toggleAmenity,
          onAddCustomOption: _addCustomAmenity,
          onRemoveCustomOption: _removeCustomAmenity,
        ),
        const SizedBox(height: 18),
        const Text(
          'Medias',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: state.isMediaUploading
                  ? null
                  : () => _pickAndUploadMedia(
                      resourceType: 'image',
                      allowMultiple: false,
                      onUploaded: (result) {
                        setState(() => _coverPhoto = result.secureUrl);
                        if (!_galleryPhotos.contains(result.secureUrl)) {
                          _galleryPhotos.insert(0, result.secureUrl);
                        }
                      },
                    ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Photo de couverture'),
            ),
            OutlinedButton.icon(
              onPressed: state.isMediaUploading
                  ? null
                  : () => _pickAndUploadMedia(
                      resourceType: 'image',
                      allowMultiple: true,
                      onUploaded: (result) {
                        setState(() {
                          if (!_galleryPhotos.contains(result.secureUrl)) {
                            _galleryPhotos.add(result.secureUrl);
                          }
                          _coverPhoto = _coverPhoto.isEmpty
                              ? result.secureUrl
                              : _coverPhoto;
                        });
                      },
                    ),
              icon: const Icon(Icons.collections_outlined),
              label: const Text('Galerie'),
            ),
            OutlinedButton.icon(
              onPressed: state.isMediaUploading
                  ? null
                  : () => _pickAndUploadMedia(
                      resourceType: 'video',
                      allowMultiple: false,
                      onUploaded: (result) {
                        setState(() => _videoUrl = result.secureUrl);
                      },
                    ),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Video'),
            ),
          ],
        ),
        if (_coverPhoto.isNotEmpty ||
            _galleryPhotos.isNotEmpty ||
            _videoUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MediaSummaryPanel(
            coverPhoto: _coverPhoto,
            galleryPhotos: _galleryPhotos,
            videoUrl: _videoUrl,
            onRemoveGalleryItem: (value) {
              setState(() => _galleryPhotos.remove(value));
            },
            onClearCover: () {
              setState(() => _coverPhoto = '');
            },
            onClearVideo: () {
              setState(() => _videoUrl = '');
            },
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.isPartnerSaving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: state.isPartnerSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business_outlined),
            label: const Text('Publier ce lieu'),
          ),
        ),
      ],
    );

    if (!widget.wrapInPanel) {
      return content;
    }

    return _SectionPanel(title: 'Ajouter un lieu ou hotel', child: content);
  }

  Future<void> _pickBusinessHour({required bool isOpening}) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _parseTime(
        isOpening ? _opensAt : _closesAt,
        fallbackHour: isOpening ? 8 : 23,
        fallbackMinute: 0,
      ),
    );

    if (pickedTime == null) return;

    setState(() {
      if (isOpening) {
        _opensAt = _formatTimeOfDay(pickedTime);
      } else {
        _closesAt = _formatTimeOfDay(pickedTime);
      }
    });
  }

  Future<void> _pickAndUploadMedia({
    required String resourceType,
    required bool allowMultiple,
    required void Function(MediaUploadResult result) onUploaded,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      withData: true,
      type: resourceType == 'video' ? FileType.video : FileType.image,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final state = context.read<MeevoState>();

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;

      final maxBytes = resourceType == 'video'
          ? 60 * 1024 * 1024
          : 15 * 1024 * 1024;
      if (file.size > maxBytes) {
        if (!mounted) return;
        _showMeevoToast(
          context,
          resourceType == 'video'
              ? 'Cette video est trop lourde. Utilisez une video de 60 MB maximum.'
              : 'Cette image est trop lourde. Utilisez une image de 15 MB maximum.',
          isError: true,
        );
        continue;
      }

      final upload = await state.uploadPartnerMedia(
        fileName: file.name,
        mimeType: _guessMimeType(file.name, resourceType),
        bytes: bytes,
        resourceType: resourceType,
        folder: resourceType == 'video'
            ? 'meevo/venues/videos'
            : 'meevo/venues/images',
      );

      if (upload != null && mounted) {
        onUploaded(upload);
      }
    }
  }

  Future<void> _submit() async {
    final state = context.read<MeevoState>();
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty || capacity == null || price == null) {
      _showMeevoToast(
        context,
        'Nom, capacite et prix sont obligatoires.',
        isError: true,
      );
      return;
    }

    if (_compareTimes(_closesAt, _opensAt) <= 0) {
      _showMeevoToast(
        context,
        'La fermeture doit etre apres l ouverture.',
        isError: true,
      );
      return;
    }

    if (_coverPhoto.isEmpty && _galleryPhotos.isEmpty) {
      _showMeevoToast(
        context,
        'Ajoutez au moins une photo reelle du lieu.',
        isError: true,
      );
      return;
    }

    if (_resolvedLocation == null) {
      _showMeevoToast(
        context,
        'Activez d abord la localisation du lieu pour enregistrer la position reelle.',
        isError: true,
      );
      return;
    }

    if (_resolvedLocation!.city.isEmpty) {
      _showMeevoToast(
        context,
        'La ville n a pas encore ete detectee correctement. Relancez la localisation.',
        isError: true,
      );
      return;
    }

    final district = _districtController.text.trim().isNotEmpty
        ? _districtController.text.trim()
        : _resolvedLocation!.district;

    final eventTypes = _mergeUniqueLabels([
      ..._selectedEventTypes,
      ..._customEventTypes,
    ]);
    final amenities = _mergeUniqueLabels([
      ..._selectedAmenities,
      ..._customAmenities,
    ]);

    if (eventTypes.isEmpty) {
      _showMeevoToast(
        context,
        'Choisissez au moins un type d evenement pour ce lieu.',
        isError: true,
      );
      return;
    }

    final venue = await state.createVenue(
      VenueDraft(
        name: name,
        venueType: _venueType,
        shortDescription: _shortDescriptionController.text.trim(),
        description: _descriptionController.text.trim(),
        city: _resolvedLocation!.city,
        district: district,
        address: _resolvedLocation!.address,
        googleMapsUrl: _resolvedLocation!.googleMapsUrl,
        latitude: _resolvedLocation!.latitude,
        longitude: _resolvedLocation!.longitude,
        capacity: capacity,
        startingPrice: price,
        eventTypes: eventTypes,
        amenities: amenities,
        photos: _galleryPhotos,
        coverPhoto: _coverPhoto.isNotEmpty ? _coverPhoto : _galleryPhotos.first,
        videoUrl: _videoUrl,
        businessHours: BusinessHours(opensAt: _opensAt, closesAt: _closesAt),
      ),
    );

    if (venue == null || !mounted) return;

    _nameController.clear();
    _shortDescriptionController.clear();
    _descriptionController.clear();
    _districtController.clear();
    _capacityController.clear();
    _priceController.clear();
    _customEventTypeController.clear();
    _customAmenityController.clear();

    setState(() {
      _venueType = _venueTypes.first;
      _opensAt = '08:00';
      _closesAt = '23:00';
      _coverPhoto = '';
      _videoUrl = '';
      _galleryPhotos.clear();
      _selectedEventTypes.clear();
      _customEventTypes.clear();
      _selectedAmenities.clear();
      _customAmenities.clear();
      _resolvedLocation = null;
    });
  }

  void _toggleEventType(String value) {
    _toggleSelectableValue(_selectedEventTypes, value);
  }

  void _toggleAmenity(String value) {
    _toggleSelectableValue(_selectedAmenities, value);
  }

  void _removeCustomEventType(String value) {
    setState(() {
      _customEventTypes.removeWhere(
        (item) => _normalizedLabelKey(item) == _normalizedLabelKey(value),
      );
    });
  }

  void _removeCustomAmenity(String value) {
    setState(() {
      _customAmenities.removeWhere(
        (item) => _normalizedLabelKey(item) == _normalizedLabelKey(value),
      );
    });
  }

  void _addCustomEventType() {
    _addCustomSelectableValue(
      controller: _customEventTypeController,
      predefinedOptions: _venueEventTypeOptions,
      selectedOptions: _selectedEventTypes,
      customOptions: _customEventTypes,
    );
  }

  void _addCustomAmenity() {
    _addCustomSelectableValue(
      controller: _customAmenityController,
      predefinedOptions: _venueAmenityOptions,
      selectedOptions: _selectedAmenities,
      customOptions: _customAmenities,
    );
  }

  void _toggleSelectableValue(List<String> target, String value) {
    final normalized = _normalizedLabelKey(value);
    setState(() {
      final existingIndex = target.indexWhere(
        (item) => _normalizedLabelKey(item) == normalized,
      );
      if (existingIndex >= 0) {
        target.removeAt(existingIndex);
      } else {
        target.add(value);
      }
    });
  }

  void _addCustomSelectableValue({
    required TextEditingController controller,
    required List<String> predefinedOptions,
    required List<String> selectedOptions,
    required List<String> customOptions,
  }) {
    final rawValue = controller.text.trim();
    if (rawValue.isEmpty) return;

    final normalized = _normalizedLabelKey(rawValue);
    final predefinedMatch = predefinedOptions.cast<String?>().firstWhere(
      (option) => _normalizedLabelKey(option) == normalized,
      orElse: () => null,
    );

    setState(() {
      if (predefinedMatch != null) {
        if (!selectedOptions.any(
          (item) => _normalizedLabelKey(item) == normalized,
        )) {
          selectedOptions.add(predefinedMatch);
        }
      } else if (!customOptions.any(
        (item) => _normalizedLabelKey(item) == normalized,
      )) {
        customOptions.add(rawValue);
      }
      controller.clear();
    });
  }

  Future<void> _detectLocation() async {
    final api = context.read<MeevoState>().api;
    setState(() => _isLocating = true);

    try {
      double latitude;
      double longitude;

      if (kIsWeb) {
        final browserPosition = await getBrowserCurrentLocation();
        latitude = browserPosition.latitude;
        longitude = browserPosition.longitude;
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Activez le GPS ou la localisation de l appareil.');
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception(
            'Meevo a besoin de votre permission de localisation pour enregistrer le lieu.',
          );
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final location = await api.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;
      setState(() {
        _resolvedLocation = location;
        _districtController.text = location.district;
        _isLocating = false;
      });
      _showMeevoToast(context, 'Localisation detectee avec succes.');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _isLocating = false);
      _showMeevoToast(
        context,
        'Le module de localisation n est pas encore charge. Redemarrez completement l application puis reessayez.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      _showMeevoToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }
}

class _AddProviderForm extends StatefulWidget {
  const _AddProviderForm({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_AddProviderForm> createState() => _AddProviderFormState();
}

class _AddProviderFormState extends State<_AddProviderForm> {
  static const _categories = [
    'Traiteur',
    'Sonorisateur',
    'Location',
    'Hotesse',
  ];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  String _category = _categories.first;
  String _city = _heroCities.first;
  String _photoUrl = '';
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ajoutez un prestataire pour le rendre visible dans Meevo.',
          style: TextStyle(color: _meevoMuted, height: 1.55),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nom du prestataire'),
        ),
        const SizedBox(height: 12),
        _ResponsiveFormRow(
          isDesktop: widget.isDesktop,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: _categories
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
              items: _heroCities
                  .map(
                    (city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(city),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _city = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Prix de depart (FCFA)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _photoUrl.isEmpty ? 'Aucune photo ajoutee.' : 'Photo ajoutee.',
                style: const TextStyle(color: _meevoMuted),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickProviderPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_isUploading ? 'En cours...' : 'Ajouter une photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ResponsiveFormRow(
          isDesktop: widget.isDesktop,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telephone'),
            ),
            TextField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (contact client)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _meevoYellow,
            foregroundColor: _meevoText,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Publier le prestataire'),
        ),
      ],
    );

    return _SectionPanel(title: 'Ajouter un prestataire', child: body);
  }

  Future<void> _pickProviderPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    const maxBytes = 15 * 1024 * 1024;
    if (file.size > maxBytes) {
      _showMeevoToast(
        context,
        'Cette image est trop lourde. Utilisez une image de 15 MB maximum.',
        isError: true,
      );
      return;
    }

    final state = context.read<MeevoState>();
    setState(() => _isUploading = true);

    final upload = await state.uploadPartnerMedia(
      fileName: file.name,
      mimeType: _guessMimeType(file.name, 'image'),
      bytes: bytes,
      resourceType: 'image',
      folder: 'meevo/providers/images',
    );

    if (!mounted) return;

    setState(() {
      _photoUrl = upload?.secureUrl ?? _photoUrl;
      _isUploading = false;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final description = _descriptionController.text.trim();
    final phone = _phoneController.text.trim();
    final whatsapp = _whatsappController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || price == null) {
      _showMeevoToast(
        context,
        'Nom et prix de depart sont obligatoires.',
        isError: true,
      );
      return;
    }

    final state = context.read<MeevoState>();
    final provider = await state.createProvider(
      ProviderDraft(
        name: name,
        category: _category,
        city: _city,
        startingPrice: price,
        description: description,
        photoUrl: _photoUrl,
        phone: phone,
        whatsapp: whatsapp,
        email: email,
      ),
    );

    if (provider == null || !mounted) return;

    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _phoneController.clear();
    _whatsappController.clear();
    _emailController.clear();
    setState(() {
      _category = _categories.first;
      _city = _heroCities.first;
      _photoUrl = '';
    });
  }
}

class _ManualBookingForm extends StatefulWidget {
  const _ManualBookingForm({this.wrapInPanel = true});

  final bool wrapInPanel;

  @override
  State<_ManualBookingForm> createState() => _ManualBookingFormState();
}

class _ManualBookingFormState extends State<_ManualBookingForm> {
  static const _eventTypes = [
    'Mariage',
    'Conference',
    'Anniversaire',
    'Cocktail',
    'Seminaire',
    'Reunion',
  ];

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _guestCountController = TextEditingController(text: '100');
  final _totalController = TextEditingController();
  final _depositController = TextEditingController();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedVenueId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String _eventType = _eventTypes.first;
  String _startTime = '08:00';
  String _endTime = '23:00';
  Future<VenueAvailability>? _availabilityFuture;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _guestCountController.dispose();
    _totalController.dispose();
    _depositController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final venues = state.myVenues;
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    final content = venues.isEmpty
        ? const Text(
            'Ajoutez d abord un lieu pour pouvoir bloquer son calendrier.',
            style: TextStyle(color: _meevoMuted),
          )
        : Builder(
            builder: (context) {
              _ensureVenueSelection(venues, state);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Utilisez ce formulaire si quelqu un reserve directement chez vous par telephone, WhatsApp ou sur place. Le calendrier Meevo se mettra a jour automatiquement.',
                    style: TextStyle(color: _meevoMuted, height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    key: ValueKey('manual-venue-${_selectedVenueId ?? ''}'),
                    initialValue: _selectedVenueId,
                    decoration: const InputDecoration(labelText: 'Lieu'),
                    items: venues
                        .map(
                          (venue) => DropdownMenuItem<String>(
                            value: venue.id,
                            child: Text(venue.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final venue = venues.firstWhere(
                        (item) => item.id == value,
                      );
                      setState(() {
                        _selectedVenueId = value;
                        _startTime = venue.businessHours.opensAt;
                        _endTime = venue.businessHours.closesAt;
                        _availabilityFuture = _fetchAvailability(state);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du client',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telephone du client',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('manual-event-$_eventType'),
                    initialValue: _eventType,
                    decoration: const InputDecoration(
                      labelText: 'Type d evenement',
                    ),
                    items: _eventTypes
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _eventType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: _meevoBackground,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    subtitle: const Text('Date reservee'),
                    onTap: () => _pickDate(state),
                  ),
                  const SizedBox(height: 12),
                  _ResponsiveFormRow(
                    isDesktop: isWide,
                    children: [
                      _TimeFieldTile(
                        label: 'Heure debut',
                        value: _startTime,
                        onTap: () => _pickTime(isStart: true, state: state),
                      ),
                      _TimeFieldTile(
                        label: 'Heure fin',
                        value: _endTime,
                        onTap: () => _pickTime(isStart: false, state: state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guestCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre d invites',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResponsiveFormRow(
                    isDesktop: isWide,
                    children: [
                      TextField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Montant total (optionnel)',
                        ),
                      ),
                      TextField(
                        controller: _depositController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Acompte (optionnel)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget client (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes internes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: FutureBuilder<VenueAvailability>(
                      future: _availabilityFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: _meevoPurple,
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const _ScheduleEmptyState(
                            title: 'Verification indisponible',
                            subtitle:
                                'Impossible de verifier le planning avant enregistrement.',
                          );
                        }

                        final availability =
                            snapshot.data ?? const VenueAvailability.empty();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BusinessHoursBanner(
                              businessHours: availability.businessHours,
                              isBlockedDate: availability.blockedDates.contains(
                                _formatApiDate(_selectedDate),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AvailabilityTimeline(
                              availability: availability,
                              highlightedStartTime: _startTime,
                              highlightedEndTime: _endTime,
                              emptyLabel:
                                  'Aucun conflit detecte a cette date pour le moment.',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isPartnerSaving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _meevoYellow,
                        foregroundColor: _meevoText,
                      ),
                      icon: state.isPartnerSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Bloquer ce creneau'),
                    ),
                  ),
                ],
              );
            },
          );

    if (!widget.wrapInPanel) {
      return content;
    }

    return _SectionPanel(title: 'Reservation hors plateforme', child: content);
  }

  void _ensureVenueSelection(List<Venue> venues, MeevoState state) {
    if (venues.isEmpty) return;

    final hasSelectedVenue = venues.any(
      (venue) => venue.id == _selectedVenueId,
    );
    if (_selectedVenueId == null || !hasSelectedVenue) {
      final venue = venues.first;
      _selectedVenueId = venue.id;
      _startTime = venue.businessHours.opensAt;
      _endTime = venue.businessHours.closesAt;
      _availabilityFuture = _fetchAvailability(state);
    }
  }

  Future<VenueAvailability> _fetchAvailability(MeevoState state) {
    return state.fetchAvailability(
      venueId: _selectedVenueId!,
      date: _selectedDate,
      forceRefresh: true,
    );
  }

  Future<void> _pickDate(MeevoState state) async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: _selectedDate,
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _availabilityFuture = _fetchAvailability(state);
    });
  }

  Future<void> _pickTime({
    required bool isStart,
    required MeevoState state,
  }) async {
    final initialTime = _parseTime(
      isStart ? _startTime : _endTime,
      fallbackHour: isStart ? 8 : 23,
      fallbackMinute: 0,
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

    setState(() {
      if (isStart) {
        _startTime = _formatTimeOfDay(pickedTime);
      } else {
        _endTime = _formatTimeOfDay(pickedTime);
      }
      _availabilityFuture = _fetchAvailability(state);
    });
  }

  Future<void> _submit() async {
    final state = context.read<MeevoState>();
    final guestCount = int.tryParse(_guestCountController.text.trim());

    if (_selectedVenueId == null ||
        _customerNameController.text.trim().isEmpty ||
        guestCount == null) {
      _showMeevoToast(
        context,
        'Lieu, nom du client et nombre d invites sont obligatoires.',
        isError: true,
      );
      return;
    }

    if (_compareTimes(_endTime, _startTime) <= 0) {
      _showMeevoToast(
        context,
        'L heure de fin doit etre apres l heure de debut.',
        isError: true,
      );
      return;
    }

    final booking = await state.createManualBooking(
      ManualBookingDraft(
        venueId: _selectedVenueId!,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        eventType: _eventType,
        eventDate: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        guestCount: guestCount,
        notes: _notesController.text.trim(),
        budget: double.tryParse(_budgetController.text.trim()),
        totalAmount: double.tryParse(_totalController.text.trim()),
        depositAmount: double.tryParse(_depositController.text.trim()),
      ),
    );

    if (booking == null || !mounted) return;

    _customerNameController.clear();
    _customerPhoneController.clear();
    _guestCountController.text = '100';
    _totalController.clear();
    _depositController.clear();
    _budgetController.clear();
    _notesController.clear();

    setState(() {
      _availabilityFuture = _fetchAvailability(state);
    });
  }
}

class _ResponsiveFormRow extends StatelessWidget {
  const _ResponsiveFormRow({required this.isDesktop, required this.children});

  final bool isDesktop;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _TimeFieldTile extends StatelessWidget {
  const _TimeFieldTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: _meevoBackground,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(label),
      subtitle: Text(value),
      onTap: onTap,
    );
  }
}

class _MultiSelectOptionEditor extends StatelessWidget {
  const _MultiSelectOptionEditor({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedOptions,
    required this.customOptions,
    required this.customController,
    required this.addButtonLabel,
    required this.customHintText,
    required this.onToggleOption,
    required this.onAddCustomOption,
    required this.onRemoveCustomOption,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final List<String> selectedOptions;
  final List<String> customOptions;
  final TextEditingController customController;
  final String addButtonLabel;
  final String customHintText;
  final ValueChanged<String> onToggleOption;
  final VoidCallback onAddCustomOption;
  final ValueChanged<String> onRemoveCustomOption;

  @override
  Widget build(BuildContext context) {
    final mergedSelection = _mergeUniqueLabels([
      ...selectedOptions,
      ...customOptions,
    ]);
    final summary = mergedSelection.isEmpty
        ? 'Appuyez pour choisir'
        : mergedSelection.take(3).join(', ');
    final extraCount = mergedSelection.length - 3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEditorSheet(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAE7F7)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mergedSelection.isEmpty
                          ? subtitle
                          : extraCount > 0
                          ? '$summary +$extraCount'
                          : summary,
                      style: TextStyle(
                        color: mergedSelection.isEmpty
                            ? _meevoMuted
                            : _meevoText,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _meevoPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditorSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final selectedKeys = selectedOptions
              .map(_normalizedLabelKey)
              .where((value) => value.isNotEmpty)
              .toSet();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _meevoMuted, height: 1.55),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: options.map((option) {
                        final isSelected = selectedKeys.contains(
                          _normalizedLabelKey(option),
                        );
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (_) {
                            onToggleOption(option);
                            sheetSetState(() {});
                          },
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: _meevoYellow.withValues(alpha: 0.25),
                          side: BorderSide(
                            color: isSelected
                                ? _meevoYellow
                                : const Color(0xFFE0DCEF),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? _meevoPurple : _meevoText,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumn = constraints.maxWidth < 560;
                        final input = TextField(
                          controller: customController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            onAddCustomOption();
                            sheetSetState(() {});
                          },
                          decoration: InputDecoration(
                            labelText: 'Autre',
                            hintText: customHintText,
                          ),
                        );

                        final button = FilledButton.icon(
                          onPressed: () {
                            onAddCustomOption();
                            sheetSetState(() {});
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _meevoPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(addButtonLabel),
                        );

                        if (useColumn) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              input,
                              const SizedBox(height: 10),
                              button,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: input),
                            const SizedBox(width: 10),
                            button,
                          ],
                        );
                      },
                    ),
                    if (customOptions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Autres valeurs ajoutees',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: customOptions
                            .map(
                              (value) => InputChip(
                                label: Text(value),
                                avatar: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: _meevoPurple,
                                ),
                                onDeleted: () {
                                  onRemoveCustomOption(value);
                                  sheetSetState(() {});
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: _meevoYellow,
                          foregroundColor: _meevoText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Terminer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaSummaryPanel extends StatelessWidget {
  const _MediaSummaryPanel({
    required this.coverPhoto,
    required this.galleryPhotos,
    required this.videoUrl,
    required this.onRemoveGalleryItem,
    required this.onClearCover,
    required this.onClearVideo,
  });

  final String coverPhoto;
  final List<String> galleryPhotos;
  final String videoUrl;
  final ValueChanged<String> onRemoveGalleryItem;
  final VoidCallback onClearCover;
  final VoidCallback onClearVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverPhoto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InputChip(
                label: const Text('Couverture chargee'),
                avatar: const Icon(Icons.photo, color: _meevoPurple),
                onDeleted: onClearCover,
              ),
            ),
          if (videoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InputChip(
                label: const Text('Video chargee'),
                avatar: const Icon(Icons.videocam, color: _meevoPurple),
                onDeleted: onClearVideo,
              ),
            ),
          if (galleryPhotos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: galleryPhotos
                  .map(
                    (photo) => InputChip(
                      label: Text('Photo ${galleryPhotos.indexOf(photo) + 1}'),
                      onDeleted: () => onRemoveGalleryItem(photo),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _meevoPurple),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _meevoText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthRequiredCard extends StatelessWidget {
  const _AuthRequiredCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Connexion requise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connectez-vous pour voir vos reservations, recevoir les mises a jour en temps reel et confirmer vos demandes.',
            style: TextStyle(color: _meevoMuted, height: 1.55),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
            ),
            child: const Text('Aller a la connexion'),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.booking, {this.onDelete});

  final BookingItem booking;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = booking.venue?.primaryImage ?? '';
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        height: 88,
        child: imageUrl.isEmpty
            ? _placeholderMedia('Photo')
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _placeholderMedia('Media indisponible'),
              ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              media,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.venue?.name ?? 'Lieu non charge',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (onDelete != null)
                          IconButton(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                            color: const Color(0xFFB93E3E),
                            tooltip: 'Supprimer',
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _bookingStatusColor(
                              booking.status,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            booking.status,
                            style: TextStyle(
                              color: _bookingStatusColor(booking.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        _DetailChip(
                          icon: Icons.event_outlined,
                          label: booking.eventType,
                        ),
                        _DetailChip(
                          icon: Icons.calendar_month_outlined,
                          label: booking.eventDate,
                        ),
                        _DetailChip(
                          icon: Icons.schedule_outlined,
                          label: '${booking.startTime} - ${booking.endTime}',
                        ),
                        _DetailChip(
                          icon: Icons.groups_2_outlined,
                          label: '${booking.guestCount} invites',
                        ),
                        _DetailChip(
                          icon: Icons.payments_outlined,
                          label: _formatMoney(booking.totalAmount, 'FCFA'),
                        ),
                        _DetailChip(
                          icon: booking.source == 'manual'
                              ? Icons.edit_calendar_outlined
                              : Icons.phone_android_outlined,
                          label: booking.source == 'manual'
                              ? 'Ajout manuel'
                              : 'Via Meevo',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((booking.customerName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Client: ${booking.customerName}${(booking.customerPhone ?? '').isNotEmpty ? ' • ${booking.customerPhone}' : ''}',
                style: const TextStyle(
                  color: _meevoText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if ((booking.notes ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                booking.notes!,
                style: const TextStyle(color: _meevoMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: _meevoMuted, height: 1.55),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onTap, child: Text(trailingLabel)),
      ],
    );
  }
}

class _WhyChooseSection extends StatelessWidget {
  const _WhyChooseSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        Icons.schedule_outlined,
        'Reservez en 3 clics',
        'Parcours simplifie, resultats immediats.',
      ),
      (
        Icons.shield_outlined,
        'Prix transparents',
        'Pas de frais caches. Ce que vous voyez = ce que vous payez.',
      ),
      (
        Icons.credit_card_outlined,
        'Paiement securise',
        'Transactions protegees, confirmation instantanee.',
      ),
    ];

    return Column(
      children: [
        Text(
          'Pourquoi choisir Meevo ?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _meevoDeepBlue,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Une plateforme concue pour simplifier l organisation de vos evenements.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _meevoMuted, fontSize: 18, height: 1.55),
        ),
        const SizedBox(height: 34),
        isDesktop
            ? Row(
                children: cards
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _LandingFeatureCard(
                            icon: card.$1,
                            title: card.$2,
                            subtitle: card.$3,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cards
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _LandingFeatureCard(
                            icon: card.$1,
                            title: card.$2,
                            subtitle: card.$3,
                            compact: true,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }
}

class _EventTypeSection extends StatelessWidget {
  const _EventTypeSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.read<MeevoState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quel type d evenement ?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: _meevoDeepBlue,
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _homeEventTypes
                .map(
                  (eventType) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _EventTypePill(
                      label: eventType,
                      compact: !isDesktop,
                      onTap: () async {
                        await state.searchVenues(
                          newFilters: state.filters.copyWith(
                            eventType: eventType,
                            page: 1,
                          ),
                        );
                        state.setPageIndex(1);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _EventTypePill extends StatelessWidget {
  const _EventTypePill({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 18,
            vertical: compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F6)),
            boxShadow: [
              BoxShadow(
                color: _meevoPurple.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _meevoDeepBlue,
                fontSize: compact ? 14 : 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CityExplorerSection extends StatelessWidget {
  const _CityExplorerSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final state = context.read<MeevoState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explorez par ville',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: _meevoDeepBlue,
          ),
        ),
        const SizedBox(height: 18),
        if (isDesktop)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _heroCities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1.5,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final city = _heroCities[index];
              return _CityExploreCard(
                city: city,
                onTap: () async {
                  await state.searchVenues(
                    newFilters: state.filters.copyWith(city: city, page: 1),
                  );
                  state.setPageIndex(1);
                },
              );
            },
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _heroCities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final city = _heroCities[index];
              return _CityExploreCard(
                city: city,
                compact: true,
                onTap: () async {
                  await state.searchVenues(
                    newFilters: state.filters.copyWith(city: city, page: 1),
                  );
                  state.setPageIndex(1);
                },
              );
            },
          ),
      ],
    );
  }
}

class _CityExploreCard extends StatelessWidget {
  const _CityExploreCard({
    required this.city,
    required this.onTap,
    this.compact = false,
  });

  final String city;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F6)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E1F8A).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 18,
              vertical: compact ? 10 : 16,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 34 : 42,
                    height: compact ? 34 : 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_meevoYellow, Color(0xFFFF9A62)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.corporate_fare_rounded,
                      color: _meevoDeepBlue,
                      size: compact ? 20 : 24,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 13 : 16,
                      color: _meevoDeepBlue,
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

class _LandingFeatureCard extends StatelessWidget {
  const _LandingFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 20,
        vertical: compact ? 16 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 40 : 52,
            height: compact ? 40 : 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8FF),
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0FB2FF),
              size: compact ? 22 : 28,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12.5 : 22,
              fontWeight: FontWeight.w700,
              color: _meevoDeepBlue,
            ),
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _meevoMuted,
              height: 1.35,
              fontSize: compact ? 10 : 14,
            ),
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}

class _DashboardShortcutCard extends StatelessWidget {
  const _DashboardShortcutCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Dashboard partenaire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accedez a votre espace de gestion pour ajouter vos lieux, bloquer des horaires et suivre vos reservations.',
            style: TextStyle(color: _meevoMuted, height: 1.6),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
            ),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Ouvrir le dashboard'),
          ),
        ],
      ),
    );
  }
}

class _PartnerCalloutSection extends StatelessWidget {
  const _PartnerCalloutSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _meevoDeepBlue,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 26 : 18,
              isDesktop ? 58 : 42,
              isDesktop ? 26 : 18,
              isDesktop ? 40 : 32,
            ),
            child: Column(
              children: [
                Text(
                  'Vous etes proprietaire de salle\nou prestataire ?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Rejoignez Meevo et augmentez votre visibilite aupres de milliers d organisateurs dans tout le Togo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD5DBFF),
                    fontSize: 18,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _openPartnerOnboarding(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _meevoYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Devenir prestataire',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        return Container(
          width: double.infinity,
          color: _meevoDeepBlue,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
            child: Column(
              children: [
                if (isCompact)
                  Column(
                    children: const [
                      _FooterLogo(),
                      SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _FooterLink(label: 'A propos'),
                          _FooterLink(label: 'Contact'),
                          _FooterLink(label: 'CGU'),
                        ],
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      _FooterLogo(),
                      Spacer(),
                      Wrap(
                        spacing: 28,
                        runSpacing: 10,
                        children: [
                          _FooterLink(label: 'A propos'),
                          _FooterLink(label: 'Contact'),
                          _FooterLink(label: 'CGU'),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 22),
                Text(
                  '(c) 2026 Meevo. La plateforme evenementielle du Togo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FooterLogo extends StatelessWidget {
  const _FooterLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LogoMark(size: 28),
        const SizedBox(width: 10),
        Text(
          'Meevo',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: _meevoPurple),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _meevoMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _WorkspaceNavItem {
  const _WorkspaceNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

class _WorkspaceScaffold extends StatelessWidget {
  const _WorkspaceScaffold({
    required this.title,
    required this.navItems,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.mobileBottomNavIndex,
    this.bottomNavPartnerMode = false,
  });

  final String title;
  final String? subtitle;
  final List<_WorkspaceNavItem> navItems;
  final Widget child;
  final List<Widget> actions;
  final int? mobileBottomNavIndex;
  final bool bottomNavPartnerMode;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;

    Widget buildSidebar({required bool compact}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9F7FF),
          border: compact
              ? const Border(
                  right: BorderSide(color: Color(0xFFE6DDF6)),
                )
              : null,
        ),
        child: _WorkspaceSidebar(
          title: title,
          subtitle: subtitle,
          items: navItems,
          compact: compact,
        ),
      );
    }

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              foregroundColor: _meevoDeepBlue,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: actions,
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: const Color(0xFFF9F7FF),
              child: SafeArea(child: buildSidebar(compact: false)),
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDesktop)
              SizedBox(width: 280, child: buildSidebar(compact: true)),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: !isDesktop && mobileBottomNavIndex != null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _FloatingBottomNav(
                selectedIndex: mobileBottomNavIndex!,
                isPartnerMode: bottomNavPartnerMode,
                onSelected: (index) => _goToRootPage(context, index),
              ),
            )
          : null,
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.title,
    required this.items,
    required this.compact,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_WorkspaceNavItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 14,
        18,
        compact ? 18 : 14,
        24,
      ),
      children: [
        const _MeevoLogo(compact: true),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: _meevoDeepBlue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              color: _meevoMuted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
        for (final item in items) ...[
          _WorkspaceSidebarButton(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _WorkspaceSidebarButton extends StatelessWidget {
  const _WorkspaceSidebarButton({required this.item});

  final _WorkspaceNavItem item;

  @override
  Widget build(BuildContext context) {
    final isSelected = item.selected;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        item.onTap();
      },
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _meevoDeepBlue : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _meevoDeepBlue : const Color(0xFFE7E0F4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : _meevoPurple,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _meevoDeepBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionAccordion extends StatelessWidget {
  const _DashboardSectionAccordion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE7F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _meevoYellow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _meevoPurple),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
              color: _meevoDeepBlue,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _meevoMuted, height: 1.4),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _BusinessHoursBanner extends StatelessWidget {
  const _BusinessHoursBanner({
    required this.businessHours,
    required this.isBlockedDate,
  });

  final BusinessHours businessHours;
  final bool isBlockedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBlockedDate
            ? const Color(0xFFFFF2F2)
            : const Color(0xFFF2FAF6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isBlockedDate ? Icons.event_busy_outlined : Icons.event_available,
            color: isBlockedDate
                ? const Color(0xFFD65050)
                : const Color(0xFF199F64),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBlockedDate
                  ? 'Jour bloque. Aucune reservation ne doit etre prise sur cette date.'
                  : 'Horaires d ouverture: ${businessHours.opensAt} - ${businessHours.closesAt}',
              style: TextStyle(
                color: isBlockedDate
                    ? const Color(0xFFD65050)
                    : const Color(0xFF199F64),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityTimeline extends StatelessWidget {
  const _AvailabilityTimeline({
    required this.availability,
    required this.emptyLabel,
    this.highlightedStartTime,
    this.highlightedEndTime,
  });

  final VenueAvailability availability;
  final String emptyLabel;
  final String? highlightedStartTime;
  final String? highlightedEndTime;

  @override
  Widget build(BuildContext context) {
    final slots = [...availability.slots]
      ..sort((left, right) => _compareTimes(left.startTime, right.startTime));

    final showHighlight =
        highlightedStartTime != null &&
        highlightedEndTime != null &&
        _compareTimes(highlightedEndTime!, highlightedStartTime!) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHighlight)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8D9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Creneau selectionne: $highlightedStartTime - $highlightedEndTime',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (slots.isEmpty)
          _ScheduleEmptyState(title: 'Aucun conflit', subtitle: emptyLabel)
        else
          Column(
            children: slots
                .map(
                  (slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AvailabilitySlotCard(
                      slot: slot,
                      isHighlighted:
                          showHighlight &&
                          _rangesOverlap(
                            highlightedStartTime!,
                            highlightedEndTime!,
                            slot.startTime,
                            slot.endTime,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _AvailabilitySlotCard extends StatelessWidget {
  const _AvailabilitySlotCard({
    required this.slot,
    required this.isHighlighted,
  });

  final AvailabilitySlot slot;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isManual = slot.isManualBlock || slot.source == 'manual';
    final baseColor = isManual
        ? const Color(0xFFFFE6B8)
        : const Color(0xFFE6EBFF);
    final accentColor = isManual ? const Color(0xFFB87800) : _meevoDeepBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF4CC) : baseColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _meevoYellow : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${slot.startTime} - ${slot.endTime}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isManual ? 'Blocage manuel' : (slot.status ?? 'reserve'),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isManual
                ? (slot.reason?.isNotEmpty == true
                      ? slot.reason!
                      : 'Reservation ajoutee hors plateforme.')
                : (slot.eventType?.isNotEmpty == true
                      ? slot.eventType!
                      : 'Reservation Meevo'),
            style: const TextStyle(
              color: _meevoText,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isHighlighted) ...[
            const SizedBox(height: 6),
            const Text(
              'Le creneau choisi chevauche cette occupation.',
              style: TextStyle(
                color: Color(0xFF9B6A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMonthlyAvailabilityGrid extends StatelessWidget {
  const _MiniMonthlyAvailabilityGrid({
    required this.month,
    required this.availability,
    required this.onDayTap,
  });

  final DateTime month;
  final MonthlyAvailability availability;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final busyDates = availability.busyDates.toSet();
    final year = month.year;
    final monthNumber = month.month;
    final daysInMonth = DateTime(year, monthNumber + 1, 0).day;
    final firstDay = DateTime(year, monthNumber, 1);
    final leadingEmpty = (firstDay.weekday + 6) % 7;
    final totalCells = leadingEmpty + daysInMonth;
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _MiniMonthWeekLabel('L'),
              _MiniMonthWeekLabel('M'),
              _MiniMonthWeekLabel('M'),
              _MiniMonthWeekLabel('J'),
              _MiniMonthWeekLabel('V'),
              _MiniMonthWeekLabel('S'),
              _MiniMonthWeekLabel('D'),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isCompact ? double.infinity : 560,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: isCompact ? 4 : 6,
                crossAxisSpacing: isCompact ? 4 : 6,
                childAspectRatio: isCompact ? 1 : 0.95,
              ),
              itemBuilder: (context, index) {
                if (index < leadingEmpty) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingEmpty + 1;
                final dateKey =
                    '${year.toString().padLeft(4, '0')}-${monthNumber.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                final isBusy = busyDates.contains(dateKey);
                final date = DateTime(year, monthNumber, day);

                return InkWell(
                  onTap: () => onDayTap(date),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isBusy
                          ? const Color(0xFFFFEDED)
                          : const Color(0xFFF4F6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBusy
                            ? const Color(0xFFD65050)
                            : const Color(0xFFE1E6F6),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isBusy
                              ? const Color(0xFFD65050)
                              : _meevoDeepBlue,
                          fontSize: isCompact ? 11 : 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MiniLegendDot(
              color: const Color(0xFFF4F6FF),
              borderColor: const Color(0xFFE1E6F6),
              label: 'Libre',
            ),
            const SizedBox(width: 14),
            _MiniLegendDot(
              color: const Color(0xFFFFEDED),
              borderColor: const Color(0xFFD65050),
              label: 'Occupe',
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniMonthWeekLabel extends StatelessWidget {
  const _MiniMonthWeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _meevoMuted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _MiniLegendDot extends StatelessWidget {
  const _MiniLegendDot({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _meevoMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _meevoMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StateToastListener extends StatefulWidget {
  const _StateToastListener({required this.child});

  final Widget child;

  @override
  State<_StateToastListener> createState() => _StateToastListenerState();
}

class _StateToastListenerState extends State<_StateToastListener> {
  String? _lastMessage;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final message = state.errorMessage ?? state.infoMessage;
    final isError = state.errorMessage != null;

    if (message != null && message != _lastMessage) {
      _lastMessage = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showMeevoToast(context, message, isError: isError);
        state.clearMessages();
      });
    }

    return widget.child;
  }
}

class _ProvidersPage extends StatefulWidget {
  const _ProvidersPage({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<_ProvidersPage> {
  static const _cities = ['Tout le Togo', ..._heroCities];
  static const _categories = [
    'Tous',
    'Traiteur',
    'Sonorisateur',
    'Location',
    'Hotesse',
  ];

  final _searchController = TextEditingController();
  String _selectedCity = _cities.first;
  String _selectedCategory = _categories.first;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final state = context.read<MeevoState>();
    _selectedCity = state.providerFilters.city;
    _selectedCategory = _categories.contains(state.providerFilters.category)
        ? state.providerFilters.category
        : _categories.first;
    _searchController.text = state.providerFilters.query;
    _searchController.addListener(_onQueryChanged);
    if (state.providers.isEmpty) {
      unawaited(state.loadProviders(silent: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final providers = state.providers;
    final isDesktop = widget.isDesktop;
    final pagination = state.providerPagination;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobileColumns = screenWidth >= 520 ? 4 : 3;
    final mobileCardHeight = mobileColumns >= 4
        ? (screenWidth < 620 ? 168.0 : 178.0)
        : (screenWidth < 390 ? 184.0 : 194.0);

    final content = RefreshIndicator(
      color: _meevoPurple,
      onRefresh: () => state.loadProviders(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          isDesktop ? 20 : 16,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          if (!isDesktop)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _MobileTopBar(showTitleOnly: true),
            ),
          if (!isDesktop) ...[
            const SizedBox(height: 4),
            const Text(
              'Prestataires',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Trouvez un traiteur, sonorisateur, hotesse ou location',
              style: TextStyle(color: _meevoMuted),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  if (isDesktop) _buildFilterChips() else _buildMobileFilters(),
                  const SizedBox(height: 18),
                  Text(
                    '${pagination.total == 0 ? providers.length : pagination.total} prestataires trouves',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _meevoText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (providers.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _EmptyStateCard(
                          title: 'Aucun prestataire trouve',
                          subtitle:
                              'Ajustez la ville ou la categorie pour voir des prestataires.',
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _resetProviderFilters,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reinitialiser les filtres'),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (isDesktop)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: providers.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisExtent: 334,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 18,
                                ),
                            itemBuilder: (context, index) =>
                                _ProviderCard(provider: providers[index]),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: providers.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: mobileColumns,
                                  mainAxisExtent: mobileCardHeight,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 10,
                                ),
                            itemBuilder: (context, index) =>
                                _CompactProviderCard(
                                  provider: providers[index],
                                ),
                          ),
                        if (pagination.totalPages > 1) ...[
                          const SizedBox(height: 18),
                          _PaginationBar(
                            page: pagination.page,
                            totalPages: pagination.totalPages,
                            onPageChanged: (page) {
                              state.loadProviders(
                                newFilters: state.providerFilters.copyWith(
                                  page: page,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text('Prestataires'),
            ),
      body: isDesktop
          ? Column(
              children: [
                _DesktopTopBar(state: context.read<MeevoState>()),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) {},
      decoration: InputDecoration(
        hintText: 'Rechercher un prestataire...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: _meevoBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._cities.map(
          (city) => ChoiceChip(
            selected: _selectedCity == city,
            onSelected: (_) {
              setState(() => _selectedCity = city);
              _applyFilters();
            },
            label: Text(city),
            selectedColor: _meevoYellow.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 12),
        ..._categories.map(
          (category) => ChoiceChip(
            selected: _selectedCategory == category,
            onSelected: (_) {
              setState(() => _selectedCategory = category);
              _applyFilters();
            },
            label: Text(category),
            selectedColor: _meevoYellow.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilters() {
    final cityLabel = _selectedCity == _cities.first ? 'Togo' : _selectedCity;
    final categoryLabel = _selectedCategory == _categories.first
        ? 'Categorie'
        : _selectedCategory;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MobileFilterButton(
          icon: Icons.place_outlined,
          label: cityLabel,
          isSelected: _selectedCity != _cities.first,
          onTap: _pickProviderCityFilter,
        ),
        _MobileFilterButton(
          icon: Icons.storefront_outlined,
          label: categoryLabel,
          isSelected: _selectedCategory != _categories.first,
          onTap: _pickProviderCategoryFilter,
        ),
      ],
    );
  }

  Future<void> _pickProviderCityFilter() async {
    final result = await _showSelectionSheet<String>(
      context,
      title: 'Choisir la region / ville',
      values: _cities,
      labelBuilder: (value) => value,
    );

    if (result == null) return;

    setState(() => _selectedCity = result);
    _applyFilters();
  }

  Future<void> _pickProviderCategoryFilter() async {
    final result = await _showSelectionSheet<String>(
      context,
      title: 'Choisir la categorie',
      values: ['Tous les prestataires', ..._categories.skip(1)],
      labelBuilder: (value) => value,
    );

    if (result == null) return;

    setState(
      () => _selectedCategory = result == 'Tous les prestataires'
          ? _categories.first
          : result,
    );
    _applyFilters();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final state = context.read<MeevoState>();
    state.loadProviders(
      newFilters: state.providerFilters.copyWith(
        query: _searchController.text.trim(),
        city: _selectedCity,
        category: _selectedCategory,
        page: 1,
      ),
    );
  }

  void _resetProviderFilters() {
    setState(() {
      _searchController.text = '';
      _selectedCity = _cities.first;
      _selectedCategory = _categories.first;
    });
    _applyFilters();
  }
}

class _ProviderDetailsPage extends StatefulWidget {
  const _ProviderDetailsPage({required this.provider});

  final ProviderProfile provider;

  @override
  State<_ProviderDetailsPage> createState() => _ProviderDetailsPageState();
}

class _ProviderDetailsPageState extends State<_ProviderDetailsPage> {
  int _quantity = 1;
  final _detailsController = TextEditingController();

  bool get _needsQuantity => _isQuantityCategory(widget.provider.category);

  bool get _needsDetails =>
      widget.provider.category.toLowerCase().contains('location');

  String get _quantityLabel {
    final category = widget.provider.category.toLowerCase();
    if (category.contains('hotesse')) {
      return 'Nombre d hotesses';
    }
    return 'Nombre d elements a louer';
  }

  String? _buildRequestNote() {
    if (!_needsQuantity) return null;
    final category = widget.provider.category.toLowerCase();
    if (category.contains('hotesse')) {
      return 'Bonjour, je souhaite reserver ${_quantity.toString()} hotesse(s) pour mon evenement.';
    }
    final details = _detailsController.text.trim();
    final suffix = details.isEmpty ? '' : ' Details: $details';
    return 'Bonjour, je souhaite louer ${_quantity.toString()} element(s) pour mon evenement.$suffix';
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() => _quantity = (_quantity + 1).clamp(1, 50));
  }

  void _decrementQuantity() {
    setState(() => _quantity = (_quantity - 1).clamp(1, 50));
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final imageUrl = provider.photoUrl ?? '';

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(provider.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 260,
              child: imageUrl.isEmpty
                  ? _placeholderMedia('Photo indisponible')
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _placeholderMedia('Photo indisponible'),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            provider.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            provider.category,
            style: const TextStyle(
              color: _meevoPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(
                icon: Icons.location_on_outlined,
                label: provider.city,
              ),
              _DetailChip(
                icon: Icons.star_rounded,
                label:
                    '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
              ),
              _DetailChip(
                icon: Icons.payments_outlined,
                label: _formatMoney(provider.startingPrice, provider.currency),
              ),
            ],
          ),
          if (_needsQuantity) ...[
            const SizedBox(height: 18),
            _SectionPanel(
              title: 'Votre besoin',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuantitySelector(
                    label: _quantityLabel,
                    value: _quantity,
                    onDecrement: _decrementQuantity,
                    onIncrement: _incrementQuantity,
                  ),
                  if (_needsDetails) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details de la location',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _showProviderContactSheet(
              context,
              provider,
              requestNote: _buildRequestNote(),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Contacter'),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Avis clients',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _meevoYellow),
                    const SizedBox(width: 6),
                    Text(
                      provider.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${provider.reviewCount})',
                      style: const TextStyle(color: _meevoMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  provider.reviewCount == 0
                      ? 'Aucun avis pour le moment.'
                      : 'Notes basees sur ${provider.reviewCount} avis.',
                  style: const TextStyle(color: _meevoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Description',
            child: Text(
              provider.description.isNotEmpty
                  ? provider.description
                  : 'Ce prestataire n a pas encore ajoute de description detaillee.',
              style: const TextStyle(color: _meevoMuted, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _meevoPurple),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

bool _isQuantityCategory(String category) {
  final normalized = category.toLowerCase();
  return normalized.contains('hotesse') || normalized.contains('location');
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _meevoText,
            ),
          ),
        ),
        IconButton(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_circle_outline),
          color: _meevoPurple,
        ),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: const Icon(Icons.add_circle_outline),
          color: _meevoPurple,
        ),
      ],
    );
  }
}

class _SearchFieldTile extends StatelessWidget {
  const _SearchFieldTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.showChevron = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _meevoSky),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        color: _meevoMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _meevoText,
                        fontSize: compact ? 12.5 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _meevoMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE7E2F7));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _meevoYellow,
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _MeevoLogo extends StatelessWidget {
  const _MeevoLogo({this.centered = false, this.compact = false});

  final bool centered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 30.0 : 34.0;
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LogoMark(size: logoSize),
          const SizedBox(width: 10),
          Text(
            'Meevo',
            style: GoogleFonts.poppins(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: _meevoPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_meevoYellow, _meevoPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: size * 0.7,
            ),
          );
        },
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    this.showTitleOnly = false,
    this.useBlueBackground = false,
  });

  final bool showTitleOnly;
  final bool useBlueBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: useBlueBackground ? _meevoHeaderBlue : Colors.white,
      child: Row(
        children: [
          const _MeevoLogo(compact: true),
          const Spacer(),
          IconButton(
            onPressed: () => context.read<MeevoState>().setPageIndex(1),
            icon: const Icon(Icons.search, color: _meevoPurple),
          ),
          IconButton(
            onPressed: () => _showMobileNavigationMenu(context),
            icon: const Icon(Icons.menu, color: _meevoPurple),
          ),
        ],
      ),
    );
  }
}

void _showMobileNavigationMenu(BuildContext context) {
  final state = context.read<MeevoState>();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _MobileNavAction(
              icon: Icons.meeting_room_outlined,
              label: 'Salles',
              onTap: () {
                Navigator.pop(sheetContext);
                state.setPageIndex(1);
              },
            ),
            _MobileNavAction(
              icon: Icons.storefront_outlined,
              label: 'Prestataires',
              onTap: () {
                Navigator.pop(sheetContext);
                _openProviders(context, isDesktop: false);
              },
            ),
            if (state.hasPartnerAccess)
              _MobileNavAction(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openDashboard(context);
                },
              ),
            if (state.needsPartnerSubscription)
              _MobileNavAction(
                icon: Icons.workspace_premium_outlined,
                label: 'Abonnement',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openPartnerSubscriptionPage(context);
                },
              ),
            if (state.isAdmin)
              _MobileNavAction(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAdminDashboard(context);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _openProviders(BuildContext context, {required bool isDesktop}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ProvidersPage(isDesktop: isDesktop),
    ),
  );
}

void _openProviderDetails(BuildContext context, ProviderProfile provider) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ProviderDetailsPage(provider: provider),
    ),
  );
}

void _showProviderContactSheet(
  BuildContext context,
  ProviderProfile provider, {
  String? requestNote,
}) {
  final options = <_ContactOption>[];

  if ((provider.phone ?? '').isNotEmpty) {
    final phone = _normalizePhone(provider.phone!);
    if (phone.isNotEmpty) {
      options.add(
        _ContactOption(
          icon: Icons.phone_outlined,
          label: 'Appeler',
          onTap: () => _launchUrl(Uri.parse('tel:$phone')),
        ),
      );
    }
  }

  if ((provider.whatsapp ?? '').isNotEmpty) {
    final phone = _normalizePhone(provider.whatsapp!);
    if (phone.isNotEmpty) {
      final text = requestNote == null || requestNote.isEmpty
          ? null
          : Uri.encodeComponent(requestNote);
      options.add(
        _ContactOption(
          icon: Icons.chat_bubble_outline,
          label: 'WhatsApp',
          onTap: () => _launchUrl(
            Uri.parse(
              text == null
                  ? 'https://wa.me/$phone'
                  : 'https://wa.me/$phone?text=$text',
            ),
          ),
        ),
      );
    }
  }

  if ((provider.email ?? '').isNotEmpty) {
    final body = requestNote == null || requestNote.isEmpty
        ? null
        : Uri.encodeComponent(requestNote);
    options.add(
      _ContactOption(
        icon: Icons.email_outlined,
        label: 'Email',
        onTap: () => _launchUrl(
          Uri.parse(
            body == null
                ? 'mailto:${provider.email}?subject=Contact Meevo'
                : 'mailto:${provider.email}?subject=Contact Meevo&body=$body',
          ),
        ),
      ),
    );
  }

  if (options.isEmpty) {
    _showMeevoToast(
      context,
      'Aucun contact disponible pour ce prestataire.',
      isError: true,
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contacter ${provider.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (option) => ListTile(
                leading: Icon(option.icon, color: _meevoPurple),
                title: Text(option.label),
                onTap: () {
                  Navigator.pop(sheetContext);
                  option.onTap();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ContactOption {
  const _ContactOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

String _normalizePhone(String input) {
  return input.replaceAll(RegExp(r'[^0-9]'), '');
}

class _MobileNavAction extends StatelessWidget {
  const _MobileNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _meevoPurple),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MobileFilterButton extends StatelessWidget {
  const _MobileFilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? _meevoDeepBlue : _meevoPurple,
        backgroundColor: isSelected
            ? _meevoYellow.withValues(alpha: 0.2)
            : Colors.white,
        side: BorderSide(
          color: isSelected ? _meevoYellow : const Color(0xFFD6D0F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

void _openPartnerOnboarding(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _PartnerOnboardingPage()),
  );
}

void _openPartnerSubscriptionPage(BuildContext context) {
  final state = context.read<MeevoState>();
  if (!state.isAuthenticated) {
    state.setPageIndex(3);
    state.setAuthMode('login');
    _showMeevoToast(
      context,
      'Connectez-vous d abord pour activer un abonnement partenaire.',
      isError: true,
    );
    return;
  }

  if (!state.hasPartnerProfile) {
    _openPartnerOnboarding(context);
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _PartnerSubscriptionPage()),
  );
}

void _openDashboard(BuildContext context) {
  final state = context.read<MeevoState>();
  if (state.needsPartnerSubscription) {
    _openPartnerSubscriptionPage(context);
    return;
  }
  if (!state.hasPartnerAccess) {
    state.setPageIndex(3);
    return;
  }
  unawaited(state.loadSubscriptionOverview(silent: true));
  unawaited(state.loadPartnerData(silent: true));
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _PartnerDashboardPage()),
  );
}

void _openPartnerBookings(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _PartnerBookingsPage()));
}

void _openPartnerRevenuePage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const _PartnerReservationFinancePage(),
    ),
  );
}

void _openAddVenuePage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AddVenuePage()));
}

void _openAddProviderPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AddProviderPage()));
}

void _openManualBookingPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _ManualBookingPage()));
}

void _openManualBookingsHistoryPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _ManualBookingsHistoryPage()),
  );
}

void _openMyVenuesPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _MyVenuesPage()));
}

void _openMyProvidersPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _MyProvidersPage()));
}

void _openPartnerAssetsPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _PartnerAssetsPage()));
}

void _openPartnerNotificationsPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _PartnerNotificationsPage()),
  );
}

void _openEditVenuePage(BuildContext context, Venue venue) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => _EditVenuePage(venue: venue)));
}

void _openEditProviderPage(BuildContext context, ProviderProfile provider) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _EditProviderPage(provider: provider),
    ),
  );
}

void _openAdminDashboard(BuildContext context) {
  final state = context.read<MeevoState>();
  if (!state.isAdmin) {
    _showMeevoToast(
      context,
      'Acces admin reserve aux comptes autorises.',
      isError: true,
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AdminDashboardPage()));
}

void _openAdminBookingsPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AdminBookingsPage()));
}

void _openAdminReservationFinancePage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const _AdminReservationFinancePage(),
    ),
  );
}

void _openAdminSubscriptionHistoryPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const _AdminSubscriptionHistoryPage(),
    ),
  );
}

void _openAdminUsersPage(BuildContext context) {
  final state = context.read<MeevoState>();
  if (!state.isAdmin) {
    _showMeevoToast(
      context,
      'Acces admin reserve aux comptes autorises.',
      isError: true,
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AdminUsersPage()));
}

class _PartnerDashboardPage extends StatelessWidget {
  const _PartnerDashboardPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final navItems = [
      _WorkspaceNavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selected: true,
        onTap: () {},
      ),
      _WorkspaceNavItem(
        label: 'Abonnement',
        icon: Icons.workspace_premium_outlined,
        onTap: () => _openPartnerSubscriptionPage(context),
      ),
      if (state.hasVenuePartnerAccess)
        _WorkspaceNavItem(
          label: 'Revenu',
          icon: Icons.payments_outlined,
          onTap: () => _openPartnerRevenuePage(context),
        ),
      if (state.hasVenuePartnerAccess)
        _WorkspaceNavItem(
          label: 'Reservations',
          icon: Icons.receipt_long_outlined,
          onTap: () => _openPartnerBookings(context),
        ),
      if (state.hasVenuePartnerAccess)
        _WorkspaceNavItem(
          label: 'Mes lieux',
          icon: Icons.meeting_room_outlined,
          onTap: () => _openMyVenuesPage(context),
        ),
      if (state.hasProviderPartnerAccess)
        _WorkspaceNavItem(
          label: 'Prestations',
          icon: Icons.storefront_outlined,
          onTap: () => _openMyProvidersPage(context),
        ),
    ];

    return _StateToastListener(
      child: _WorkspaceScaffold(
        title: 'Dashboard partenaire',
        subtitle:
            'Sur grand ecran la navigation reste a gauche. Sur mobile, elle sort depuis le menu.',
        navItems: navItems,
        mobileBottomNavIndex: 3,
        bottomNavPartnerMode: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 18,
            isDesktop ? 20 : 16,
            isDesktop ? 24 : 18,
            28,
          ),
          children: [
            if (state.needsPartnerSubscription)
              const _DashboardSubscriptionLock()
            else if (state.hasPartnerAccess)
              _PartnerDashboard(isDesktop: isDesktop)
            else
              const _DashboardSubscriptionLock(
                title: 'Acces partenaire requis',
                subtitle:
                    'Creez d abord votre dossier partenaire puis activez votre abonnement pour ouvrir ce dashboard.',
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSubscriptionLock extends StatelessWidget {
  const _DashboardSubscriptionLock({
    this.title = 'Abonnement requis',
    this.subtitle =
        'Votre dossier partenaire est pret, mais un abonnement actif est necessaire pour utiliser les outils du dashboard Meevo.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101735), Color(0xFF2A2B8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _meevoYellow,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.7,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _PartnerMetricChip(
                icon: Icons.payments_outlined,
                label: '50 000 FCFA / mois',
              ),
              _PartnerMetricChip(
                icon: Icons.phone_android_outlined,
                label: 'Moov et Yas Togo',
              ),
              _PartnerMetricChip(
                icon: Icons.dashboard_customize_outlined,
                label: 'Dashboard debloque apres validation',
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _openPartnerSubscriptionPage(context),
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            ),
            icon: const Icon(Icons.arrow_forward_outlined),
            label: const Text('Activer mon abonnement'),
          ),
        ],
      ),
    );
  }
}

class _PartnerAssetsPage extends StatelessWidget {
  const _PartnerAssetsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final canVenue = state.hasVenuePartnerAccess;
    final canProvider = state.hasProviderPartnerAccess;

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Mes activites'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          if (canVenue)
            _SectionPanel(
              title: 'Mes lieux',
              child: _VenuePreviewList(venues: state.myVenues, maxItems: 999),
            ),
          if (canVenue && canProvider) const SizedBox(height: 18),
          if (canProvider)
            _SectionPanel(
              title: 'Mes prestations',
              child: _ProviderPreviewList(
                providers: state.myProviders,
                maxItems: 999,
              ),
            ),
          if (canVenue) ...[
            const SizedBox(height: 18),
            _DashboardSectionAccordion(
              icon: Icons.calendar_month_outlined,
              title: 'Planning temps reel',
              subtitle: 'Selectionnez un lieu et suivez le calendrier.',
              child: _PartnerVenuePlanner(
                isDesktop: isDesktop,
                withPanel: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerNotificationsPage extends StatelessWidget {
  const _PartnerNotificationsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _PartnerNotificationsPanel(
            subscription: state.partnerSubscription,
            realtimeConnected: state.realtimeConnected,
          ),
        ],
      ),
    );
  }
}

class _PartnerBookingsPage extends StatelessWidget {
  const _PartnerBookingsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final venueIds = state.myVenues.map((venue) => venue.id).toSet();
    final partnerBookings = state.bookings
        .where(
          (booking) =>
              venueIds.contains(booking.venue?.id) &&
              booking.status != 'pending',
        )
        .toList();
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Reservations recues'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _PartnerBookingsPanel(bookings: partnerBookings, withPanel: false),
        ],
      ),
    );
  }
}

class _PartnerReservationFinancePage extends StatefulWidget {
  const _PartnerReservationFinancePage();

  @override
  State<_PartnerReservationFinancePage> createState() =>
      _PartnerReservationFinancePageState();
}

class _PartnerReservationFinancePageState
    extends State<_PartnerReservationFinancePage> {
  ReservationFinanceResponse _response =
      const ReservationFinanceResponse.empty();
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  final _payoutPhoneController = TextEditingController();
  final _payoutAccountController = TextEditingController();
  String _payoutStatus = 'Tous';
  String _paymentNetwork = 'Tous';
  String _range = 'month';
  String _payoutNetwork = 'MOOV';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final profile = context.read<MeevoState>().currentUser?.partnerProfile;
    _payoutPhoneController.text = profile?.payoutPhoneNumber ?? '';
    _payoutAccountController.text =
        profile?.payoutAccountName ??
        context.read<MeevoState>().currentUser?.fullName ??
        '';
    _payoutNetwork =
        (profile?.payoutNetwork == 'TOGOCEL' ||
            profile?.payoutNetwork == 'MOOV')
        ? profile!.payoutNetwork!
        : 'MOOV';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadFinance());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _payoutPhoneController.dispose();
    _payoutAccountController.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      unawaited(_loadFinance(silent: true));
    });
  }

  Future<void> _loadFinance({bool silent = false}) async {
    final state = context.read<MeevoState>();
    final token = state.token;
    if (token == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await state.api.fetchPartnerReservationFinance(
        token: token,
        query: _searchController.text,
        payoutStatus: _payoutStatus,
        network: _paymentNetwork,
        range: _range,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      final rawMessage = error.message.trim();
      setState(() {
        _error = rawMessage.toLowerCase() == 'route introuvable.'
            ? 'Le module utilisateurs admin n etait pas encore publie sur le serveur. Rechargez la page ou reessayez maintenant.'
            : rawMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les paiements recus.';
        _loading = false;
      });
    }
  }

  Future<void> _savePayoutProfile() async {
    final state = context.read<MeevoState>();
    final ok = await state.updatePayoutProfile(
      phoneNumber: _payoutPhoneController.text.trim(),
      network: _payoutNetwork,
      accountName: _payoutAccountController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _showMeevoToast(context, 'Numero de reversement mis a jour.');
      await _loadFinance(silent: true);
    }
  }

  Future<void> _export() async {
    final ok = await exportTsvFile(
      filename: 'paiements_partenaire.tsv',
      content: _buildReservationPaymentsTsv(
        _response.items,
        includePartner: false,
      ),
    );
    if (!mounted) return;
    _showMeevoToast(
      context,
      ok ? 'Export TSV pret.' : 'Export impossible.',
      isError: !ok,
    );
  }

  Future<void> _openPayoutProfileDialog() async {
    final state = context.read<MeevoState>();
    final profile = state.currentUser?.partnerProfile;
    _payoutPhoneController.text =
        profile?.payoutPhoneNumber ?? _payoutPhoneController.text;
    _payoutAccountController.text =
        profile?.payoutAccountName ?? _payoutAccountController.text;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final saving = dialogContext
              .watch<MeevoState>()
              .isPayoutProfileSaving;
          return AlertDialog(
            title: const Text('Numero de reversement partenaire'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meevo prepare automatiquement le reversement (95%) sur ce numero apres une reservation payee.',
                    style: TextStyle(color: _meevoMuted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _payoutPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numero Moov / Yas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _payoutNetwork,
                    decoration: const InputDecoration(
                      labelText: 'Reseau payout',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'MOOV',
                        child: Text('Moov / Flooz'),
                      ),
                      DropdownMenuItem(
                        value: 'TOGOCEL',
                        child: Text('Yas / TMoney'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => _payoutNetwork = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payoutAccountController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du beneficiaire',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        await _savePayoutProfile();
                        if (!mounted) return;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _meevoYellow,
                  foregroundColor: _meevoText,
                ),
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<MeevoState>();
    final profile = state.currentUser?.partnerProfile;
    return _WorkspaceScaffold(
      title: 'Revenu partenaire',
      subtitle: 'Paiements recus, reversements et historique partenaire.',
      navItems: [
        _WorkspaceNavItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          onTap: () => _openDashboard(context),
        ),
        _WorkspaceNavItem(
          label: 'Revenu',
          icon: Icons.payments_outlined,
          selected: true,
          onTap: () {},
        ),
        _WorkspaceNavItem(
          label: 'Abonnement',
          icon: Icons.workspace_premium_outlined,
          onTap: () => _openPartnerSubscriptionPage(context),
        ),
      ],
      actions: [
        IconButton(
          tooltip: 'Configurer le reversement',
          onPressed: _openPayoutProfileDialog,
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      ],
      mobileBottomNavIndex: 3,
      bottomNavPartnerMode: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _AdminSearchField(
            controller: _searchController,
            hint: 'Rechercher un client, une reference ou un lieu...',
            onChanged: (_) => _scheduleReload(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in const [
                  'Tous',
                  'ready',
                  'pending_profile',
                  'paid',
                ]) ...[
                  ChoiceChip(
                    label: Text(_reservationPayoutStatusLabel(status)),
                    selected: _payoutStatus == status,
                    onSelected: (_) {
                      setState(() => _payoutStatus = status);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                for (final network in const ['Tous', 'MOOV', 'TOGOCEL']) ...[
                  ChoiceChip(
                    label: Text(_reservationPaymentNetworkLabel(network)),
                    selected: _paymentNetwork == network,
                    onSelected: (_) {
                      setState(() => _paymentNetwork = network);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                for (final range in const [
                  'week',
                  'month',
                  '6m',
                  'year',
                  'all',
                ]) ...[
                  ChoiceChip(
                    label: Text(_reservationFinanceRangeLabel(range)),
                    selected: _range == range,
                    onSelected: (_) {
                      setState(() => _range = range);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : () => unawaited(_loadFinance()),
                  icon: const Icon(Icons.sync),
                  label: const Text('Actualiser'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _response.items.isEmpty ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exporter TSV'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReservationFinanceInlineTotals(
            summary: _response.summary,
            payoutLabel: profile?.payoutPhoneNumber?.isNotEmpty == true
                ? '${profile?.payoutNetwork == 'TOGOCEL' ? 'Yas' : 'Moov'} • ${profile?.payoutPhoneNumber}'
                : 'Payout: non configure',
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Tableau des paiements confirmes',
            child: _ReservationFinanceTable(
              records: _response.items,
              loading: _loading,
              showPartner: false,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminReservationFinancePage extends StatefulWidget {
  const _AdminReservationFinancePage();

  @override
  State<_AdminReservationFinancePage> createState() =>
      _AdminReservationFinancePageState();
}

class _AdminReservationFinancePageState
    extends State<_AdminReservationFinancePage> {
  ReservationFinanceResponse _response =
      const ReservationFinanceResponse.empty();
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _payoutStatus = 'Tous';
  String _paymentNetwork = 'Tous';
  String _range = 'month';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadFinance());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      unawaited(_loadFinance(silent: true));
    });
  }

  Future<void> _loadFinance({bool silent = false}) async {
    final state = context.read<MeevoState>();
    final token = state.token;
    if (!state.isAdmin || token == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await state.api.fetchAdminReservationFinance(
        token: token,
        query: _searchController.text,
        payoutStatus: _payoutStatus,
        network: _paymentNetwork,
        range: _range,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la comptabilite reservation.';
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final ok = await exportTsvFile(
      filename: 'paiements_reservations_admin.tsv',
      content: _buildReservationPaymentsTsv(
        _response.items,
        includePartner: true,
      ),
    );
    if (!mounted) return;
    _showMeevoToast(
      context,
      ok ? 'Export TSV pret.' : 'Export impossible.',
      isError: !ok,
    );
  }

  Future<void> _markPayoutPaid(ReservationPaymentData payment) async {
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marquer le reversement comme paye ?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference payout (optionnel)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note admin (optionnel)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final token = context.read<MeevoState>().token;
    if (token == null) return;

    try {
      await context.read<MeevoState>().api.markReservationPayoutPaid(
        token: token,
        paymentId: payment.id,
        payoutReference: referenceController.text.trim(),
        payoutNotes: notesController.text.trim(),
      );
      if (!mounted) return;
      _showMeevoToast(context, 'Reversement marque comme paye.');
      await _loadFinance(silent: true);
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      _showMeevoToast(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMeevoToast(
        context,
        'Impossible de mettre a jour le reversement.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    return _WorkspaceScaffold(
      title: 'Revenu admin',
      subtitle:
          'Grand tableau revenus, partenaires, retraits et historiques.',
      navItems: [
        _WorkspaceNavItem(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _openAdminDashboard(context),
        ),
        _WorkspaceNavItem(
          label: 'Revenu',
          icon: Icons.payments_outlined,
          selected: true,
          onTap: () {},
        ),
        _WorkspaceNavItem(
          label: 'Reservations',
          icon: Icons.receipt_long_outlined,
          onTap: () => _openAdminBookingsPage(context),
        ),
      ],
      mobileBottomNavIndex: 3,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _AdminSearchField(
            controller: _searchController,
            hint: 'Rechercher un partenaire, client, lieu ou reference...',
            onChanged: (_) => _scheduleReload(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in const [
                  'Tous',
                  'ready',
                  'pending_profile',
                  'paid',
                ]) ...[
                  ChoiceChip(
                    label: Text(_reservationPayoutStatusLabel(status)),
                    selected: _payoutStatus == status,
                    onSelected: (_) {
                      setState(() => _payoutStatus = status);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                for (final network in const ['Tous', 'MOOV', 'TOGOCEL']) ...[
                  ChoiceChip(
                    label: Text(_reservationPaymentNetworkLabel(network)),
                    selected: _paymentNetwork == network,
                    onSelected: (_) {
                      setState(() => _paymentNetwork = network);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                for (final range in const [
                  'week',
                  'month',
                  '6m',
                  'year',
                  'all',
                ]) ...[
                  ChoiceChip(
                    label: Text(_reservationFinanceRangeLabel(range)),
                    selected: _range == range,
                    onSelected: (_) {
                      setState(() => _range = range);
                      unawaited(_loadFinance(silent: true));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : () => unawaited(_loadFinance()),
                  icon: const Icon(Icons.sync),
                  label: const Text('Actualiser'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _response.items.isEmpty ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exporter TSV'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReservationFinanceInlineTotals(summary: _response.summary),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Tableau global des reservations payees',
            child: _ReservationFinanceTable(
              records: _response.items,
              loading: _loading,
              showPartner: true,
              onMarkPayoutPaid: _markPayoutPaid,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReservationFinanceInlineTotals extends StatelessWidget {
  const _ReservationFinanceInlineTotals({
    required this.summary,
    this.payoutLabel = '',
  });

  final ReservationFinanceSummary summary;
  final String payoutLabel;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pills = <Widget>[
      _InlineStatPill(
        label: 'Paiements',
        value: summary.successfulReservations.toString(),
        emphasis: true,
      ),
      _InlineStatPill(
        label: 'Brut',
        value: _formatMoney(summary.totalGrossAmount, 'FCFA'),
        emphasis: true,
      ),
      _InlineStatPill(
        label: 'Commission',
        value: _formatMoney(summary.totalPlatformFee, 'FCFA'),
      ),
      _InlineStatPill(
        label: 'Net partenaire',
        value: _formatMoney(summary.totalPartnerNet, 'FCFA'),
        emphasis: true,
      ),
      _InlineStatPill(
        label: 'Pret a reverser',
        value: _formatMoney(summary.readyPayoutAmount, 'FCFA'),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Totaux',
            style: TextStyle(
              color: _meevoDeepBlue,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 14 : 16,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: pills),
          if (payoutLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              payoutLabel,
              style: const TextStyle(color: _meevoMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineStatPill extends StatelessWidget {
  const _InlineStatPill({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: _meevoMuted,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _meevoDeepBlue,
              fontSize: compact ? 11 : 13,
              fontWeight: emphasis ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationFinanceTable extends StatefulWidget {
  const _ReservationFinanceTable({
    required this.records,
    required this.loading,
    required this.showPartner,
    this.onMarkPayoutPaid,
  });

  final List<ReservationPaymentData> records;
  final bool loading;
  final bool showPartner;
  final Future<void> Function(ReservationPaymentData payment)? onMarkPayoutPaid;

  @override
  State<_ReservationFinanceTable> createState() =>
      _ReservationFinanceTableState();
}

class _ReservationFinanceTableState extends State<_ReservationFinanceTable> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _nudge(double delta) async {
    if (!_horizontalController.hasClients) return;
    final max = _horizontalController.position.maxScrollExtent;
    final target = (_horizontalController.offset + delta).clamp(0.0, max);
    await _horizontalController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final headingStyle = TextStyle(
      color: _meevoDeepBlue,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 13,
    );
    final cellStyle = TextStyle(
      color: _meevoDeepBlue,
      fontSize: compact ? 12 : 13,
      height: 1.35,
    );

    if (widget.loading && widget.records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _meevoPurple)),
      );
    }

    if (widget.records.isEmpty) {
      return const Text(
        'Aucune transaction succes pour ces filtres.',
        style: TextStyle(color: _meevoMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Glissez dans le tableau ou utilisez les fleches.',
                    style: TextStyle(color: _meevoMuted, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => unawaited(_nudge(-240)),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF4F1FF),
                    minimumSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => unawaited(_nudge(240)),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF4F1FF),
                    minimumSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAE7F7)),
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: compact,
            trackVisibility: compact,
            interactive: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            thickness: compact ? 8 : 10,
            radius: const Radius.circular(999),
            child: SingleChildScrollView(
              controller: _horizontalController,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: widget.showPartner ? 1380 : 1180,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8F7FC),
                  ),
                  dataRowMinHeight: compact ? 54 : 60,
                  dataRowMaxHeight: compact ? 84 : 92,
                  horizontalMargin: compact ? 12 : 18,
                  columnSpacing: compact ? 18 : 24,
                  headingTextStyle: headingStyle,
                  dataTextStyle: cellStyle,
                  columns: [
                    DataColumn(label: Text('Lieu', style: headingStyle)),
                    if (widget.showPartner)
                      DataColumn(
                        label: Text('Partenaire', style: headingStyle),
                      ),
                    DataColumn(label: Text('Client', style: headingStyle)),
                    DataColumn(label: Text('Date', style: headingStyle)),
                    DataColumn(label: Text('Montant', style: headingStyle)),
                    DataColumn(label: Text('Commission', style: headingStyle)),
                    DataColumn(label: Text('Net', style: headingStyle)),
                    DataColumn(label: Text('Paiement', style: headingStyle)),
                    DataColumn(label: Text('Reversement', style: headingStyle)),
                    DataColumn(label: Text('Payout', style: headingStyle)),
                    DataColumn(label: Text('Reference', style: headingStyle)),
                    if (widget.onMarkPayoutPaid != null)
                      DataColumn(label: Text('Action', style: headingStyle)),
                  ],
                  rows: widget.records.map((record) {
                    final payoutLabel = switch (record.payoutStatus) {
                      'paid' => 'Reverse',
                      'ready' => 'Pret',
                      _ => 'Profil payout',
                    };
                    final payoutColor = switch (record.payoutStatus) {
                      'paid' => const Color(0xFF16A34A),
                      'ready' => const Color(0xFF2563EB),
                      _ => const Color(0xFFF59E0B),
                    };
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              record.venue?.name ?? 'Lieu',
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (widget.showPartner)
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                record.partner?.partnerProfile?.businessName ??
                                    record.partner?.fullName ??
                                    '--',
                                overflow: TextOverflow.ellipsis,
                                style: cellStyle,
                              ),
                            ),
                          ),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              '${record.customerName}\n${record.phoneNumber}',
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              '${record.eventDate}\n${record.startTime} - ${record.endTime}',
                              style: cellStyle,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatMoney(record.grossAmount, 'FCFA'),
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatMoney(record.platformFeeAmount, 'FCFA'),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatMoney(record.partnerNetAmount, 'FCFA'),
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(
                          _AdminStatusBadge(
                            label: record.status,
                            color: _subscriptionPaymentStatusColor(
                              record.status,
                            ),
                          ),
                        ),
                        DataCell(
                          _AdminStatusBadge(
                            label: payoutLabel,
                            color: payoutColor,
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              record.payoutPhoneNumber?.isNotEmpty == true
                                  ? '${record.payoutNetwork == 'TOGOCEL' ? 'Yas' : 'Moov'} • ${record.payoutPhoneNumber}'
                                  : 'Non configure',
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 190,
                            child: Text(
                              record.paymentReference?.isNotEmpty == true
                                  ? record.paymentReference!
                                  : record.identifier,
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle,
                            ),
                          ),
                        ),
                        if (widget.onMarkPayoutPaid != null)
                          DataCell(
                            record.payoutStatus == 'paid'
                                ? const Text('--')
                                : OutlinedButton(
                                    onPressed: () =>
                                        widget.onMarkPayoutPaid!(record),
                                    child: const Text('Paye'),
                                  ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddVenuePage extends StatelessWidget {
  const _AddVenuePage();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<MeevoState>();

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Ajouter un lieu'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _SectionPanel(
            title: 'Formulaire lieu',
            child: _AddVenueForm(isDesktop: isDesktop, wrapInPanel: false),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Mes lieux',
            child: _VenuePreviewList(venues: state.myVenues, maxItems: 999),
          ),
        ],
      ),
    );
  }
}

class _AddProviderPage extends StatelessWidget {
  const _AddProviderPage();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<MeevoState>();

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Ajouter une prestation'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _AddProviderForm(isDesktop: isDesktop),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Mes prestations',
            child: _ProviderPreviewList(
              providers: state.myProviders,
              maxItems: 999,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBookingPage extends StatelessWidget {
  const _ManualBookingPage();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final state = context.watch<MeevoState>();
    final venueIds = state.myVenues.map((venue) => venue.id).toSet();
    final manualBookings = state.bookings
        .where(
          (booking) =>
              venueIds.contains(booking.venue?.id) &&
              booking.source == 'manual',
        )
        .toList();

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Reservation hors plateforme'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _SectionPanel(
            title: 'Nouveau blocage',
            child: _ManualBookingForm(wrapInPanel: false),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Dernieres reservations hors plateforme',
            child: _ManualBookingPreviewList(
              bookings: manualBookings,
              onViewAll: () => _openManualBookingsHistoryPage(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBookingsHistoryPage extends StatelessWidget {
  const _ManualBookingsHistoryPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final venueIds = state.myVenues.map((venue) => venue.id).toSet();
    final manualBookings = state.bookings
        .where(
          (booking) =>
              venueIds.contains(booking.venue?.id) &&
              booking.source == 'manual',
        )
        .toList();

    Future<void> handleExport() async {
      final tsv = _buildBookingsTsv(manualBookings);
      final ok = await exportTsvFile(
        filename: 'reservations_hors_plateforme.tsv',
        content: tsv,
      );
      if (!context.mounted) return;
      _showMeevoToast(
        context,
        ok
            ? 'Fichier TSV pret a etre partage.'
            : 'Impossible d exporter le TSV.',
        isError: !ok,
      );
    }

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Historique reservations hors plateforme'),
        actions: [
          TextButton.icon(
            onPressed: manualBookings.isEmpty ? null : handleExport,
            icon: const Icon(Icons.download, color: _meevoPurple),
            label: const Text('Exporter TSV'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _PartnerBookingsPanel(bookings: manualBookings, withPanel: false),
        ],
      ),
    );
  }
}

class _MyVenuesPage extends StatelessWidget {
  const _MyVenuesPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Mes lieux'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _SectionPanel(
            title: 'Tous mes lieux',
            child: _VenuePreviewList(venues: state.myVenues, maxItems: 999),
          ),
        ],
      ),
    );
  }
}

class _MyProvidersPage extends StatelessWidget {
  const _MyProvidersPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Mes prestations'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _SectionPanel(
            title: 'Toutes mes prestations',
            child: _ProviderPreviewList(
              providers: state.myProviders,
              maxItems: 999,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditVenuePage extends StatefulWidget {
  const _EditVenuePage({required this.venue});

  final Venue venue;

  @override
  State<_EditVenuePage> createState() => _EditVenuePageState();
}

class _EditVenuePageState extends State<_EditVenuePage> {
  final _nameController = TextEditingController();
  final _districtController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _city = _heroCities.first;
  String _coverPhoto = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final venue = widget.venue;
    _nameController.text = venue.name;
    _districtController.text = venue.district ?? '';
    _capacityController.text = venue.capacity.toString();
    _priceController.text = venue.startingPrice.toStringAsFixed(0);
    _shortDescriptionController.text = venue.shortDescription ?? '';
    _descriptionController.text = venue.description ?? '';
    _city = _canonicalHeroCity(venue.city, allowAllTogo: false);
    _coverPhoto = venue.coverPhoto ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverPhoto() async {
    if (_isUploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _isUploading = true);
    final mimeType = _guessMimeType(file.name, 'image');
    final upload = await context.read<MeevoState>().uploadPartnerMedia(
      fileName: file.name,
      mimeType: mimeType,
      bytes: bytes,
      resourceType: 'image',
      folder: 'meevo/venues',
    );
    if (!mounted) return;
    setState(() => _isUploading = false);
    if (upload == null) return;
    setState(() => _coverPhoto = upload.secureUrl);
  }

  Future<void> _submit() async {
    final state = context.read<MeevoState>();
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isEmpty || capacity <= 0 || price <= 0) {
      _showMeevoToast(
        context,
        'Nom, capacite et prix de depart sont obligatoires.',
        isError: true,
      );
      return;
    }

    final updated = await state.updateVenue(
      venueId: widget.venue.id,
      data: {
        'name': name,
        'city': _city,
        'district': _districtController.text.trim(),
        'capacity': capacity,
        'startingPrice': price,
        'shortDescription': _shortDescriptionController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverPhoto': _coverPhoto,
      },
    );

    if (!mounted || updated == null) return;
    _showMeevoToast(context, 'Lieu mis a jour.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Modifier le lieu'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _SectionPanel(
            title: 'Informations principales',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom du lieu'),
                ),
                const SizedBox(height: 12),
                _ResponsiveFormRow(
                  isDesktop: MediaQuery.sizeOf(context).width >= 900,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      items: _heroCities
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _city = value);
                      },
                    ),
                    TextField(
                      controller: _districtController,
                      decoration: const InputDecoration(labelText: 'Quartier'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ResponsiveFormRow(
                  isDesktop: MediaQuery.sizeOf(context).width >= 900,
                  children: [
                    TextField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacite'),
                    ),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix (FCFA)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _shortDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description courte',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description complete',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Photo de couverture',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _coverPhoto.isEmpty
                        ? _placeholderMedia('Aucune photo')
                        : Image.network(
                            _coverPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Photo indisponible'),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickCoverPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _isUploading ? 'Televersement...' : 'Changer la photo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Enregistrer les modifications'),
          ),
        ],
      ),
    );
  }
}

class _EditProviderPage extends StatefulWidget {
  const _EditProviderPage({required this.provider});

  final ProviderProfile provider;

  @override
  State<_EditProviderPage> createState() => _EditProviderPageState();
}

class _EditProviderPageState extends State<_EditProviderPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  String _category = 'Traiteur';
  String _city = _heroCities.first;
  String _photoUrl = '';
  bool _isUploading = false;

  static const _providerCategories = [
    'Traiteur',
    'Sonorisateur',
    'Location',
    'Hotesse',
  ];

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _nameController.text = provider.name;
    _descriptionController.text = provider.description;
    _priceController.text = provider.startingPrice.toStringAsFixed(0);
    _phoneController.text = provider.phone ?? '';
    _whatsappController.text = provider.whatsapp ?? '';
    _emailController.text = provider.email ?? '';
    _category = _providerCategories.contains(provider.category)
        ? provider.category
        : _providerCategories.first;
    _city = _canonicalHeroCity(provider.city, allowAllTogo: false);
    _photoUrl = provider.photoUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickProviderPhoto() async {
    if (_isUploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _isUploading = true);
    final mimeType = _guessMimeType(file.name, 'image');
    final upload = await context.read<MeevoState>().uploadPartnerMedia(
      fileName: file.name,
      mimeType: mimeType,
      bytes: bytes,
      resourceType: 'image',
      folder: 'meevo/providers',
    );
    if (!mounted) return;
    setState(() => _isUploading = false);
    if (upload == null) return;
    setState(() => _photoUrl = upload.secureUrl);
  }

  Future<void> _submit() async {
    final state = context.read<MeevoState>();
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isEmpty || price <= 0) {
      _showMeevoToast(
        context,
        'Nom et prix de depart sont obligatoires.',
        isError: true,
      );
      return;
    }

    final updated = await state.updateProvider(
      providerId: widget.provider.id,
      data: {
        'name': name,
        'category': _category,
        'description': _descriptionController.text.trim(),
        'city': _city,
        'startingPrice': price,
        'photoUrl': _photoUrl,
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
      },
    );

    if (!mounted || updated == null) return;
    _showMeevoToast(context, 'Prestataire mis a jour.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Modifier la prestation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _SectionPanel(
            title: 'Informations prestataire',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du prestataire',
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsiveFormRow(
                  isDesktop: MediaQuery.sizeOf(context).width >= 900,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Categorie'),
                      items: _providerCategories
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _category = value);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      items: _heroCities
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _city = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                _ResponsiveFormRow(
                  isDesktop: MediaQuery.sizeOf(context).width >= 900,
                  children: [
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telephone'),
                    ),
                    TextField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp (contact client)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Photo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _photoUrl.isEmpty
                        ? _placeholderMedia('Aucune photo')
                        : Image.network(
                            _photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _placeholderMedia('Photo indisponible'),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickProviderPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _isUploading ? 'Televersement...' : 'Changer la photo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _meevoYellow,
              foregroundColor: _meevoText,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Enregistrer les modifications'),
          ),
        ],
      ),
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage();

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  AdminUsersResponse _response = const AdminUsersResponse.empty();
  bool _loading = true;
  String? _error;
  String _role = 'Tous';
  String _subscriptionStatus = 'Tous';
  DateTime? _fromDate;
  DateTime? _toDate;
  Timer? _debounce;

  String _asIsoDate(DateTime value) =>
      DateFormat('yyyy-MM-dd', 'fr_FR').format(value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadUsers());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String get _fromDateValue => _fromDate == null ? '' : _asIsoDate(_fromDate!);
  String get _toDateValue => _toDate == null ? '' : _asIsoDate(_toDate!);

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      unawaited(_loadUsers(silent: true));
    });
  }

  Future<void> _loadUsers({bool silent = false}) async {
    final token = context.read<MeevoState>().token;
    if (token == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await context.read<MeevoState>().api.fetchAdminUsers(
        token: token,
        query: _searchController.text,
        role: _role,
        subscriptionStatus: _subscriptionStatus,
        city: _cityController.text,
        from: _fromDateValue,
        to: _toDateValue,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la liste des utilisateurs.';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initialDate = isFrom
        ? (_fromDate ?? now)
        : (_toDate ?? _fromDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2022),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    await _loadUsers(silent: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _cityController.clear();
      _role = 'Tous';
      _subscriptionStatus = 'Tous';
      _fromDate = null;
      _toDate = null;
    });
    unawaited(_loadUsers(silent: true));
  }

  Future<void> _export() async {
    final ok = await exportTsvFile(
      filename: 'utilisateurs_meevo.tsv',
      content: _buildAdminUsersTsv(_response.items),
    );
    if (!mounted) return;
    _showMeevoToast(
      context,
      ok ? 'Export utilisateurs pret.' : 'Export impossible.',
      isError: !ok,
    );
  }

  Future<void> _openCreateAdminDialog() async {
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final cityController = TextEditingController(text: 'Lome');
    var loading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Ajouter un admin'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Nom complet'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe temporaire',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telephone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'Ville'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        final token = context.read<MeevoState>().token;
                        if (token == null) return;
                        setDialogState(() => loading = true);
                        try {
                          await context.read<MeevoState>().api.createAdminUser(
                            token: token,
                            fullName: fullNameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            phone: phoneController.text.trim(),
                            city: cityController.text.trim(),
                          );
                          if (!mounted) return;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _showMeevoToast(context, 'Compte admin enregistre.');
                          await _loadUsers(silent: true);
                        } on MeevoApiException catch (error) {
                          if (!mounted) return;
                          _showMeevoToast(
                            context,
                            error.message,
                            isError: true,
                          );
                          if (dialogContext.mounted) {
                            setDialogState(() => loading = false);
                          }
                        } catch (_) {
                          if (!mounted) return;
                          _showMeevoToast(
                            context,
                            'Creation admin impossible pour le moment.',
                            isError: true,
                          );
                          if (dialogContext.mounted) {
                            setDialogState(() => loading = false);
                          }
                        }
                      },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(loading ? 'Creation...' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleAdmin(AdminUserRecord record) async {
    final token = context.read<MeevoState>().token;
    if (token == null) return;
    final willBecomeAdmin = record.user.role != 'admin';

    try {
      await context.read<MeevoState>().api.updateAdminUserAdminStatus(
        token: token,
        userId: record.user.id,
        isAdmin: willBecomeAdmin,
      );
      if (!mounted) return;
      _showMeevoToast(
        context,
        willBecomeAdmin
            ? 'Utilisateur promu admin.'
            : 'Droits admin retires.',
      );
      await _loadUsers(silent: true);
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      _showMeevoToast(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMeevoToast(
        context,
        'Impossible de modifier les droits admin.',
        isError: true,
      );
    }
  }

  Future<void> _deleteUser(AdminUserRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          'Cette action supprimera ${record.user.fullName}, ses reservations, ses paiements, ses lieux et ses prestations lies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final token = context.read<MeevoState>().token;
    if (token == null) return;

    try {
      await context.read<MeevoState>().api.deleteAdminUser(
        token: token,
        userId: record.user.id,
      );
      if (!mounted) return;
      _showMeevoToast(context, 'Utilisateur supprime.');
      await _loadUsers(silent: true);
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      _showMeevoToast(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMeevoToast(
        context,
        'Suppression impossible pour le moment.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final summary = _response.summary;
    return _WorkspaceScaffold(
      title: 'Admin Meevo',
      subtitle: 'Utilisateurs, droits admin et filtres avances.',
      navItems: [
        _WorkspaceNavItem(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _openAdminDashboard(context),
        ),
        _WorkspaceNavItem(
          label: 'Utilisateurs',
          icon: Icons.people_alt_outlined,
          selected: true,
          onTap: () {},
        ),
        _WorkspaceNavItem(
          label: 'Revenu',
          icon: Icons.payments_outlined,
          onTap: () => _openAdminReservationFinancePage(context),
        ),
        _WorkspaceNavItem(
          label: 'Reservations',
          icon: Icons.receipt_long_outlined,
          onTap: () => _openAdminBookingsPage(context),
        ),
        _WorkspaceNavItem(
          label: 'Abonnements',
          icon: Icons.workspace_premium_outlined,
          onTap: () => _openAdminSubscriptionHistoryPage(context),
        ),
      ],
      mobileBottomNavIndex: 3,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _SectionPanel(
            title: 'Filtres et actions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminSearchField(
                  controller: _searchController,
                  hint: 'Rechercher par nom, email, telephone, ville ou partenaire...',
                  onChanged: (_) => _scheduleReload(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isDesktop ? 180 : double.infinity,
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(
                            value: 'customer',
                            child: Text('Clients'),
                          ),
                          DropdownMenuItem(
                            value: 'partner',
                            child: Text('Partenaires'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admins'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _role = value);
                          unawaited(_loadUsers(silent: true));
                        },
                      ),
                    ),
                    SizedBox(
                      width: isDesktop ? 220 : double.infinity,
                      child: DropdownButtonFormField<String>(
                        initialValue: _subscriptionStatus,
                        decoration: const InputDecoration(
                          labelText: 'Abonnement',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactif'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('En attente'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Actif'),
                          ),
                          DropdownMenuItem(
                            value: 'expired',
                            child: Text('Expire'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Annule'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _subscriptionStatus = value);
                          unawaited(_loadUsers(silent: true));
                        },
                      ),
                    ),
                    SizedBox(
                      width: isDesktop ? 220 : double.infinity,
                      child: TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Ville'),
                        onChanged: (_) => _scheduleReload(),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _fromDate == null
                            ? 'Date debut'
                            : _formatDisplayDate(_fromDateValue),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        _toDate == null
                            ? 'Date fin'
                            : _formatDisplayDate(_toDateValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : () => unawaited(_loadUsers()),
                      icon: const Icon(Icons.sync),
                      label: const Text('Actualiser'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _response.items.isEmpty ? null : _export,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Exporter TSV'),
                    ),
                    FilledButton.icon(
                      onPressed: _openCreateAdminDialog,
                      style: FilledButton.styleFrom(
                        backgroundColor: _meevoYellow,
                        foregroundColor: _meevoText,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Ajouter un admin'),
                    ),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Reinitialiser'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAE7F7)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InlineStatPill(
                  label: 'Utilisateurs',
                  value: summary.totalUsers.toString(),
                  emphasis: true,
                ),
                _InlineStatPill(
                  label: 'Admins',
                  value: summary.admins.toString(),
                  emphasis: true,
                ),
                _InlineStatPill(
                  label: 'Partenaires',
                  value: summary.partners.toString(),
                ),
                _InlineStatPill(
                  label: 'Clients',
                  value: summary.customers.toString(),
                ),
                _InlineStatPill(
                  label: 'Abonnements actifs',
                  value: summary.activeSubscriptions.toString(),
                  emphasis: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Grand tableau utilisateurs',
            child: _error != null && _response.items.isEmpty && !_loading
                ? _AdminUsersLoadError(
                    message: _error!,
                    onRetry: () => unawaited(_loadUsers()),
                  )
                : _AdminUsersTable(
                    records: _response.items,
                    loading: _loading,
                    onToggleAdmin: _toggleAdmin,
                    onDelete: _deleteUser,
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminUsersTable extends StatelessWidget {
  const _AdminUsersTable({
    required this.records,
    required this.loading,
    required this.onToggleAdmin,
    required this.onDelete,
  });

  final List<AdminUserRecord> records;
  final bool loading;
  final Future<void> Function(AdminUserRecord record) onToggleAdmin;
  final Future<void> Function(AdminUserRecord record) onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading && records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _meevoPurple)),
      );
    }

    if (records.isEmpty) {
      return const Text(
        'Aucun utilisateur ne correspond a ces filtres.',
        style: TextStyle(color: _meevoMuted),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1180),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              const Color(0xFFF7F6FB),
            ),
            columns: const [
              DataColumn(label: Text('Date / Heure')),
              DataColumn(label: Text('Nom')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Telephone')),
              DataColumn(label: Text('Ville')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Partenaire')),
              DataColumn(label: Text('Abonnement')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        record.user.createdAt == null
                            ? '--'
                            : _formatDisplayDate(record.user.createdAt!),
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (record.whatsapp.trim().isNotEmpty)
                            Text(
                              'WhatsApp: ${record.whatsapp}',
                              style: const TextStyle(
                                color: _meevoMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      SelectableText(
                        record.user.email,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(Text(record.user.phone?.trim().isNotEmpty == true
                        ? record.user.phone!
                        : '--')),
                    DataCell(Text(record.user.city?.trim().isNotEmpty == true
                        ? record.user.city!
                        : '--')),
                    DataCell(_AdminUserRoleBadge(role: record.user.role)),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.businessName.trim().isNotEmpty
                                ? record.businessName
                                : 'Aucun',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            record.partnerType.trim().isNotEmpty
                                ? record.partnerType
                                : 'Sans profil partenaire',
                            style: const TextStyle(
                              color: _meevoMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _AdminUserSubscriptionBadge(
                        state: record.subscriptionState,
                      ),
                    ),
                    DataCell(
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => onToggleAdmin(record),
                            icon: Icon(
                              record.user.role == 'admin'
                                  ? Icons.shield_outlined
                                  : Icons.admin_panel_settings_outlined,
                            ),
                            label: Text(
                              record.user.role == 'admin'
                                  ? 'Retirer admin'
                                  : 'Mettre admin',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => onDelete(record),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFB42318),
                            ),
                            label: const Text(
                              'Supprimer',
                              style: TextStyle(color: Color(0xFFB42318)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminUsersLoadError extends StatelessWidget {
  const _AdminUsersLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7D0CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chargement impossible',
            style: TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _meevoMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.sync),
            label: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }
}

class _AdminUserRoleBadge extends StatelessWidget {
  const _AdminUserRoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'admin' => ('Admin', const Color(0xFF4F46E5)),
      'partner' => ('Partenaire', const Color(0xFF2563EB)),
      _ => ('Client', const Color(0xFF667085)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AdminUserSubscriptionBadge extends StatelessWidget {
  const _AdminUserSubscriptionBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'active' => ('Actif', const Color(0xFF16A34A)),
      'pending' => ('En attente', const Color(0xFFF59E0B)),
      'expired' => ('Expire', const Color(0xFFB42318)),
      'cancelled' => ('Annule', const Color(0xFF7A5AF8)),
      _ => ('Inactif', const Color(0xFF667085)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum _AdminDashboardSection { stats, bookings, venues, providers, subscriptions }

class _AdminDashboardPage extends StatefulWidget {
  const _AdminDashboardPage();

  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  final _bookingSearchController = TextEditingController();
  final _venueSearchController = TextEditingController();
  final _providerSearchController = TextEditingController();
  String _bookingStatus = 'confirmed';
  _AdminDashboardSection _section = _AdminDashboardSection.stats;

  @override
  void dispose() {
    _bookingSearchController.dispose();
    _venueSearchController.dispose();
    _providerSearchController.dispose();
    super.dispose();
  }

  List<BookingItem> _filterBookings(List<BookingItem> bookings) {
    final query = _bookingSearchController.text.trim().toLowerCase();
    return bookings.where((booking) {
      if (_bookingStatus != 'Tous' && booking.status != _bookingStatus) {
        return false;
      }
      if (query.isEmpty) return true;
      final venueName = booking.venue?.name.toLowerCase() ?? '';
      final client = (booking.customerName ?? '').toLowerCase();
      final phone = (booking.customerPhone ?? '').toLowerCase();
      return venueName.contains(query) ||
          client.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    final query = _venueSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return venues;
    return venues
        .where(
          (venue) =>
              venue.name.toLowerCase().contains(query) ||
              venue.city.toLowerCase().contains(query) ||
              venue.locationLabel.toLowerCase().contains(query),
        )
        .toList();
  }

  List<ProviderProfile> _filterProviders(List<ProviderProfile> providers) {
    final query = _providerSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return providers;
    return providers
        .where(
          (provider) =>
              provider.name.toLowerCase().contains(query) ||
              provider.category.toLowerCase().contains(query) ||
              provider.city.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();
    final stats = state.homeData.stats;
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final allBookings = state.bookings;
    final filteredBookings = _filterBookings(allBookings);
    final venues = state.searchResults.isNotEmpty
        ? state.searchResults
        : state.myVenues;
    final providers = state.providers.isNotEmpty
        ? state.providers
        : state.myProviders;
    final filteredVenues = _filterVenues(venues);
    final filteredProviders = _filterProviders(providers);

    final navItems = [
      _WorkspaceNavItem(
        label: 'Stats',
        icon: Icons.grid_view_outlined,
        selected: _section == _AdminDashboardSection.stats,
        onTap: () => setState(() => _section = _AdminDashboardSection.stats),
      ),
      _WorkspaceNavItem(
        label: 'Reservations',
        icon: Icons.receipt_long_outlined,
        selected: _section == _AdminDashboardSection.bookings,
        onTap: () => setState(() => _section = _AdminDashboardSection.bookings),
      ),
      _WorkspaceNavItem(
        label: 'Lieux',
        icon: Icons.meeting_room_outlined,
        selected: _section == _AdminDashboardSection.venues,
        onTap: () => setState(() => _section = _AdminDashboardSection.venues),
      ),
      _WorkspaceNavItem(
        label: 'Prestations',
        icon: Icons.storefront_outlined,
        selected: _section == _AdminDashboardSection.providers,
        onTap: () => setState(() => _section = _AdminDashboardSection.providers),
      ),
      _WorkspaceNavItem(
        label: 'Abonnements',
        icon: Icons.workspace_premium_outlined,
        selected: _section == _AdminDashboardSection.subscriptions,
        onTap: () =>
            setState(() => _section = _AdminDashboardSection.subscriptions),
      ),
      _WorkspaceNavItem(
        label: 'Utilisateurs',
        icon: Icons.people_alt_outlined,
        onTap: () => _openAdminUsersPage(context),
      ),
      _WorkspaceNavItem(
        label: 'Revenu',
        icon: Icons.payments_outlined,
        onTap: () => _openAdminReservationFinancePage(context),
      ),
    ];

    final Widget content = switch (_section) {
      _AdminDashboardSection.stats => ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          _SectionPanel(
            title: 'Vue globale',
            child: isDesktop
                ? Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AdminStatCard(label: 'Lieux', value: stats.venuesCount),
                      _AdminStatCard(label: 'Villes', value: stats.citiesCount),
                      _AdminStatCard(
                        label: 'Prestations',
                        value: stats.providersCount,
                      ),
                      _AdminStatCard(
                        label: 'Reservations',
                        value: stats.bookingsCount,
                      ),
                    ],
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _AdminStatCard(
                        label: 'Lieux',
                        value: stats.venuesCount,
                        compact: true,
                      ),
                      _AdminStatCard(
                        label: 'Villes',
                        value: stats.citiesCount,
                        compact: true,
                      ),
                      _AdminStatCard(
                        label: 'Prestations',
                        value: stats.providersCount,
                        compact: true,
                      ),
                      _AdminStatCard(
                        label: 'Reservations',
                        value: stats.bookingsCount,
                        compact: true,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Actions admin',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashboardActionCard(
                  icon: Icons.meeting_room_outlined,
                  title: 'Toutes les salles',
                  subtitle: 'Voir les lieux publies.',
                  onTap: () => _goToRootPage(context, 1),
                ),
                _DashboardActionCard(
                  icon: Icons.storefront_outlined,
                  title: 'Tous les prestataires',
                  subtitle: 'Voir toutes les prestations.',
                  onTap: () => _openProviders(context, isDesktop: isDesktop),
                ),
                _DashboardActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Toutes les reservations',
                  subtitle: 'Suivi complet des reservations.',
                  onTap: () => setState(
                    () => _section = _AdminDashboardSection.bookings,
                  ),
                ),
                _DashboardActionCard(
                  icon: Icons.payments_outlined,
                  title: 'Revenu admin',
                  subtitle: 'Grand tableau, filtres et retraits.',
                  onTap: () => _openAdminReservationFinancePage(context),
                ),
                _DashboardActionCard(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Abonnements',
                  subtitle: 'Suivre, filtrer et exporter.',
                  onTap: () => setState(
                    () => _section = _AdminDashboardSection.subscriptions,
                  ),
                ),
                _DashboardActionCard(
                  icon: Icons.people_alt_outlined,
                  title: 'Utilisateurs',
                  subtitle: 'Tableau global, filtres et droits admin.',
                  onTap: () => _openAdminUsersPage(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Dernieres reservations',
            child: _PartnerBookingsPanel(
              bookings: allBookings,
              withPanel: false,
            ),
          ),
        ],
      ),
      _AdminDashboardSection.bookings => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _AdminSearchField(
            controller: _bookingSearchController,
            hint: 'Rechercher une reservation (client, lieu, tel)...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in const [
                'Tous',
                'confirmed',
                'rejected',
                'cancelled',
              ])
                ChoiceChip(
                  label: Text(status),
                  selected: _bookingStatus == status,
                  onSelected: (_) => setState(() => _bookingStatus = status),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: filteredBookings.isEmpty
                    ? null
                    : () async {
                        final tsv = _buildBookingsTsv(filteredBookings);
                        final ok = await exportTsvFile(
                          filename: 'reservations_global.tsv',
                          content: tsv,
                        );
                        if (!context.mounted) return;
                        _showMeevoToast(
                          context,
                          ok ? 'Export TSV pret.' : 'Export impossible.',
                          isError: !ok,
                        );
                      },
                icon: const Icon(Icons.download),
                label: const Text('Exporter TSV'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PartnerBookingsPanel(
            bookings: filteredBookings,
            withPanel: false,
          ),
        ],
      ),
      _AdminDashboardSection.venues => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _AdminSearchField(
            controller: _venueSearchController,
            hint: 'Filtrer les lieux...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: filteredVenues.isEmpty
                  ? null
                  : () async {
                      final tsv = _buildVenuesTsv(filteredVenues);
                      final ok = await exportTsvFile(
                        filename: 'lieux_global.tsv',
                        content: tsv,
                      );
                      if (!context.mounted) return;
                      _showMeevoToast(
                        context,
                        ok ? 'Export TSV pret.' : 'Export impossible.',
                        isError: !ok,
                      );
                    },
              icon: const Icon(Icons.download),
              label: const Text('Exporter TSV'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Lieux disponibles',
            child: _VenuePreviewList(venues: filteredVenues, maxItems: 999),
          ),
        ],
      ),
      _AdminDashboardSection.providers => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _AdminSearchField(
            controller: _providerSearchController,
            hint: 'Filtrer les prestations...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: filteredProviders.isEmpty
                  ? null
                  : () async {
                      final tsv = _buildProvidersTsv(filteredProviders);
                      final ok = await exportTsvFile(
                        filename: 'prestations_global.tsv',
                        content: tsv,
                      );
                      if (!context.mounted) return;
                      _showMeevoToast(
                        context,
                        ok ? 'Export TSV pret.' : 'Export impossible.',
                        isError: !ok,
                      );
                    },
              icon: const Icon(Icons.download),
              label: const Text('Exporter TSV'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionPanel(
            title: 'Prestations disponibles',
            child: _ProviderPreviewList(
              providers: filteredProviders,
              maxItems: 999,
            ),
          ),
        ],
      ),
      _AdminDashboardSection.subscriptions => const _AdminSubscriptionsTab(),
    };

    return _StateToastListener(
      child: _WorkspaceScaffold(
        title: 'Admin Meevo',
        subtitle:
            'Menu fixe a gauche sur grand ecran, menu hamburger sur mobile.',
        navItems: navItems,
        mobileBottomNavIndex: 3,
        child: content,
      ),
    );
  }
}

class _AdminSearchField extends StatelessWidget {
  const _AdminSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFFF7F6FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 160,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: _meevoMuted, fontSize: compact ? 12 : 14),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: _meevoDeepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubscriptionsTab extends StatefulWidget {
  const _AdminSubscriptionsTab();

  @override
  State<_AdminSubscriptionsTab> createState() => _AdminSubscriptionsTabState();
}

class _AdminSubscriptionsTabState extends State<_AdminSubscriptionsTab> {
  AdminSubscriptionResponse _response = const AdminSubscriptionResponse.empty();
  bool _loading = true;
  String? _error;
  String _paymentStatus = 'Tous';
  final String _subscriptionState = 'Tous';
  final String _network = 'Tous';
  final String _yearFilter = 'Tous';
  final String _monthFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSubscriptions());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  int? get _selectedYear =>
      _yearFilter == 'Tous' ? null : int.tryParse(_yearFilter);

  int? get _selectedMonth =>
      _monthFilter == 'Tous' ? null : int.tryParse(_monthFilter);

  Future<void> _loadSubscriptions({bool silent = false}) async {
    final state = context.read<MeevoState>();
    final token = state.token;
    if (!state.isAdmin || token == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await state.api.fetchAdminSubscriptions(
        token: token,
        query: '',
        status: _paymentStatus,
        subscriptionState: _subscriptionState,
        network: _network,
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les abonnements pour le moment.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final summary = _response.summary;
    final records = _response.items;
    final finalizedRecords = records
        .where(
          (record) => _isFinalSubscriptionPaymentStatus(record.payment.status),
        )
        .toList();
    final previewRecords = finalizedRecords.take(isDesktop ? 6 : 4).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 18,
        18,
        isDesktop ? 24 : 18,
        28,
      ),
      children: [
        _SectionPanel(
          title: 'Actions abonnement',
          child: Builder(
            builder: (context) {
              final actions = [
                _DashboardActionCard(
                  icon: Icons.history_outlined,
                  title: 'Historique complet',
                  subtitle: 'Recherche, filtres et export TSV.',
                  onTap: () => _openAdminSubscriptionHistoryPage(context),
                ),
                _DashboardActionCard(
                  icon: Icons.download_outlined,
                  title: 'Exporter finalises',
                  subtitle:
                      'Abonnements success, expires, failed ou cancelled.',
                  onTap: finalizedRecords.isEmpty
                      ? () {}
                      : () async {
                          final ok = await exportTsvFile(
                            filename: 'abonnements_finalises.tsv',
                            content: _buildSubscriptionsTsv(finalizedRecords),
                          );
                          if (!context.mounted) return;
                          _showMeevoToast(
                            context,
                            ok
                                ? 'Export abonnement pret.'
                                : 'Export impossible.',
                            isError: !ok,
                          );
                        },
                ),
                _DashboardActionCard(
                  icon: Icons.sync_outlined,
                  title: 'Recharger',
                  subtitle: 'Actualiser les stats et paiements.',
                  onTap: () => unawaited(_loadSubscriptions()),
                ),
                _DashboardActionCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Suivi pending',
                  subtitle:
                      'Les paiements en attente restent suivis ici, hors historique.',
                  onTap: () {
                    setState(() => _paymentStatus = 'pending');
                    unawaited(_loadSubscriptions());
                  },
                ),
              ];

              if (isDesktop) {
                return Wrap(spacing: 12, runSpacing: 12, children: actions);
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: actions,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _SectionPanel(
          title: 'Vue abonnement',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suivez les renouvellements, la grace de 7 jours, les revenus et les partenaires a relancer.',
                style: const TextStyle(color: _meevoMuted, height: 1.55),
              ),
              const SizedBox(height: 12),
              if (isDesktop)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _AdminMoneyStatCard(
                      label: 'Revenus filtres',
                      value: _formatMoney(summary.totalRevenue, 'FCFA'),
                      accent: const Color(0xFF4F46E5),
                    ),
                    _AdminMoneyStatCard(
                      label: 'Ce mois',
                      value: _formatMoney(summary.currentMonthRevenue, 'FCFA'),
                      accent: const Color(0xFF2563EB),
                    ),
                    _AdminMoneyStatCard(
                      label: 'Paiements OK',
                      value: summary.successfulPayments.toString(),
                      accent: const Color(0xFF16A34A),
                    ),
                    _AdminMoneyStatCard(
                      label: 'Grace 7 jours',
                      value: summary.gracePartners.toString(),
                      accent: const Color(0xFFF59E0B),
                    ),
                    _AdminMoneyStatCard(
                      label: 'Masques',
                      value: summary.hiddenPartners.toString(),
                      accent: const Color(0xFFB42318),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InlineStatPill(
                      label: 'Revenus',
                      value: _formatMoney(summary.totalRevenue, 'FCFA'),
                      emphasis: true,
                    ),
                    _InlineStatPill(
                      label: 'Ce mois',
                      value: _formatMoney(summary.currentMonthRevenue, 'FCFA'),
                      emphasis: true,
                    ),
                    _InlineStatPill(
                      label: 'Paiements OK',
                      value: summary.successfulPayments.toString(),
                      emphasis: true,
                    ),
                    _InlineStatPill(
                      label: 'Grace',
                      value: summary.gracePartners.toString(),
                    ),
                    _InlineStatPill(
                      label: 'Masques',
                      value: summary.hiddenPartners.toString(),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionPanel(
          title: 'Paiements finalises recents',
          child: _AdminSubscriptionList(
            records: previewRecords,
            loading: _loading,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openAdminSubscriptionHistoryPage(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ouvrir l historique complet'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminMoneyStatCard extends StatelessWidget {
  const _AdminMoneyStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _meevoDeepBlue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubscriptionList extends StatelessWidget {
  const _AdminSubscriptionList({required this.records, required this.loading});

  final List<AdminSubscriptionRecord> records;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _meevoPurple)),
      );
    }

    if (records.isEmpty) {
      return const Text(
        'Aucun abonnement finalise trouve pour ces filtres.',
        style: TextStyle(color: _meevoMuted),
      );
    }

    return Column(
      children: [
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AdminSubscriptionRecordCard(record: record),
          ),
      ],
    );
  }
}

class _AdminSubscriptionRecordCard extends StatelessWidget {
  const _AdminSubscriptionRecordCard({required this.record});

  final AdminSubscriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final businessName =
        record.user.partnerProfile?.businessName.isNotEmpty == true
        ? record.user.partnerProfile!.businessName
        : record.user.fullName;
    final stateLabel = switch (record.subscriptionState) {
      'pending' => 'Paiement en attente',
      'active' => 'Actif',
      'expiring_soon' => 'Expire bientot',
      'grace' => 'Grace 7 jours',
      'expired' => 'Masque',
      _ => 'Inactif',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        color: _meevoDeepBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.user.fullName} • ${record.user.email}',
                      style: const TextStyle(color: _meevoMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _AdminStatusBadge(
                label: record.payment.status,
                color: _subscriptionPaymentStatusColor(record.payment.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.payments_outlined,
                label: _formatMoney(record.payment.totalAmount, 'FCFA'),
              ),
              _DetailChip(
                icon: Icons.smartphone_outlined,
                label: record.payment.network == 'TOGOCEL'
                    ? 'Yas / TMoney'
                    : 'Moov / Flooz',
              ),
              _DetailChip(
                icon: Icons.calendar_month_outlined,
                label:
                    '${record.payment.months} mois • ${_formatDisplayDate(record.payment.createdAt ?? '')}',
              ),
              _DetailChip(
                icon: Icons.visibility_outlined,
                label: record.isVisiblePublicly ? 'Visible' : 'Masque',
              ),
              _DetailChip(
                icon: Icons.verified_user_outlined,
                label: stateLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reference: ${record.payment.identifier}',
            style: const TextStyle(
              color: _meevoMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            record.expiresAt == null
                ? 'Fin abonnement non definie.'
                : record.inGracePeriod
                ? 'Expire le ${_formatDisplayDate(record.expiresAt!)} • fin de grace le ${_formatDisplayDate(record.graceEndsAt ?? '')}.'
                : 'Expire le ${_formatDisplayDate(record.expiresAt!)}.',
            style: const TextStyle(color: _meevoMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _AdminSubscriptionHistoryPage extends StatefulWidget {
  const _AdminSubscriptionHistoryPage();

  @override
  State<_AdminSubscriptionHistoryPage> createState() =>
      _AdminSubscriptionHistoryPageState();
}

class _AdminSubscriptionHistoryPageState
    extends State<_AdminSubscriptionHistoryPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  AdminSubscriptionResponse _response = const AdminSubscriptionResponse.empty();
  bool _loading = true;
  String? _error;
  String _paymentStatus = 'Tous';
  String _subscriptionState = 'Tous';
  String _network = 'Tous';
  String _yearFilter = 'Tous';
  String _monthFilter = 'Tous';

  static const _paymentStatuses = [
    'Tous',
    'success',
    'expired',
    'cancelled',
    'failed',
  ];

  static const _subscriptionStates = [
    'Tous',
    'active',
    'expiring_soon',
    'grace',
    'expired',
    'inactive',
  ];

  static const _networks = ['Tous', 'MOOV', 'TOGOCEL'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSubscriptions());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int? get _selectedYear =>
      _yearFilter == 'Tous' ? null : int.tryParse(_yearFilter);

  int? get _selectedMonth =>
      _monthFilter == 'Tous' ? null : int.tryParse(_monthFilter);

  List<String> _yearOptions() {
    final currentYear = DateTime.now().year;
    return [
      'Tous',
      for (int offset = 0; offset < 5; offset += 1) '${currentYear - offset}',
    ];
  }

  List<(String, String)> _monthOptions() {
    return const [
      ('Tous', 'Tous les mois'),
      ('1', 'Janvier'),
      ('2', 'Fevrier'),
      ('3', 'Mars'),
      ('4', 'Avril'),
      ('5', 'Mai'),
      ('6', 'Juin'),
      ('7', 'Juillet'),
      ('8', 'Aout'),
      ('9', 'Septembre'),
      ('10', 'Octobre'),
      ('11', 'Novembre'),
      ('12', 'Decembre'),
    ];
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_loadSubscriptions());
    });
  }

  List<(IconData, String)> _activeFilterTags() {
    final tags = <(IconData, String)>[];
    if (_paymentStatus != 'Tous') {
      tags.add((Icons.payments_outlined, _paymentStatus));
    }
    if (_subscriptionState != 'Tous') {
      tags.add((Icons.verified_user_outlined, _subscriptionState));
    }
    if (_network != 'Tous') {
      tags.add((
        Icons.smartphone_outlined,
        _network == 'TOGOCEL' ? 'Yas / TMoney' : 'Moov / Flooz',
      ));
    }
    if (_yearFilter != 'Tous') {
      tags.add((Icons.calendar_today_outlined, _yearFilter));
    }
    if (_monthFilter != 'Tous') {
      final month = _monthOptions().firstWhere(
        (item) => item.$1 == _monthFilter,
        orElse: () => (_monthFilter, _monthFilter),
      );
      tags.add((Icons.date_range_outlined, month.$2));
    }
    return tags;
  }

  Future<void> _openFiltersSheet() async {
    final result = await showModalBottomSheet<_AdminSubscriptionHistoryFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        var paymentStatus = _paymentStatus;
        var subscriptionState = _subscriptionState;
        var network = _network;
        var yearFilter = _yearFilter;
        var monthFilter = _monthFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtres historique',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _meevoDeepBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gardez l ecran principal leger et choisissez ici les filtres a appliquer.',
                        style: TextStyle(color: _meevoMuted, height: 1.55),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Paiement',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _meevoDeepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in _paymentStatuses)
                            ChoiceChip(
                              label: Text(status),
                              selected: paymentStatus == status,
                              onSelected: (_) {
                                setSheetState(() => paymentStatus = status);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Abonnement',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _meevoDeepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in _subscriptionStates)
                            ChoiceChip(
                              label: Text(status),
                              selected: subscriptionState == status,
                              onSelected: (_) {
                                setSheetState(() => subscriptionState = status);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: network,
                        decoration: _adminDropdownDecoration('Reseau'),
                        items: _networks
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  item == 'TOGOCEL' ? 'Yas / TMoney' : item,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => network = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: yearFilter,
                        decoration: _adminDropdownDecoration('Annee'),
                        items: _yearOptions()
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => yearFilter = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: monthFilter,
                        decoration: _adminDropdownDecoration('Mois'),
                        items: _monthOptions()
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.$1,
                                child: Text(item.$2),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => monthFilter = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(
                                  sheetContext,
                                  const _AdminSubscriptionHistoryFilters(
                                    paymentStatus: 'Tous',
                                    subscriptionState: 'Tous',
                                    network: 'Tous',
                                    yearFilter: 'Tous',
                                    monthFilter: 'Tous',
                                  ),
                                );
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reinitialiser'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(
                                  sheetContext,
                                  _AdminSubscriptionHistoryFilters(
                                    paymentStatus: paymentStatus,
                                    subscriptionState: subscriptionState,
                                    network: network,
                                    yearFilter: yearFilter,
                                    monthFilter: monthFilter,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Appliquer'),
                            ),
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
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _paymentStatus = result.paymentStatus;
      _subscriptionState = result.subscriptionState;
      _network = result.network;
      _yearFilter = result.yearFilter;
      _monthFilter = result.monthFilter;
    });
    await _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final state = context.read<MeevoState>();
    final token = state.token;
    if (!state.isAdmin || token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await state.api.fetchAdminSubscriptions(
        token: token,
        query: _searchController.text,
        status: _paymentStatus,
        subscriptionState: _subscriptionState,
        network: _network,
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } on MeevoApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l historique abonnement.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final compactActionStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      minimumSize: WidgetStateProperty.all(const Size(0, 42)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    final records = _response.items
        .where(
          (record) => _isFinalSubscriptionPaymentStatus(record.payment.status),
        )
        .toList();
    final activeTags = _activeFilterTags();
    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _meevoDeepBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Historique abonnements',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 18,
          18,
          isDesktop ? 24 : 18,
          28,
        ),
        children: [
          const Text(
            'Cette page regroupe uniquement les paiements finalises. Les pending restent suivis dans la vue abonnement admin.',
            style: TextStyle(color: _meevoMuted, height: 1.55),
          ),
          const SizedBox(height: 12),
          _AdminSearchField(
            controller: _searchController,
            hint: 'Rechercher un email, business, reference ou contact...',
            onChanged: (_) => _scheduleReload(),
          ),
          const SizedBox(height: 12),
          if (activeTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in activeTags)
                    _DetailChip(icon: tag.$1, label: tag.$2),
                ],
              ),
            ),
          if (isDesktop)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  style: compactActionStyle,
                  onPressed: _openFiltersSheet,
                  icon: const Icon(Icons.tune),
                  label: const Text('Filtres'),
                ),
                OutlinedButton.icon(
                  style: compactActionStyle,
                  onPressed: _loading
                      ? null
                      : () => unawaited(_loadSubscriptions()),
                  icon: const Icon(Icons.sync),
                  label: const Text('Actualiser'),
                ),
                OutlinedButton.icon(
                  style: compactActionStyle,
                  onPressed: records.isEmpty
                      ? null
                      : () async {
                          final ok = await exportTsvFile(
                            filename: 'abonnements_historique.tsv',
                            content: _buildSubscriptionsTsv(records),
                          );
                          if (!context.mounted) return;
                          _showMeevoToast(
                            context,
                            ok
                                ? 'Export historique pret.'
                                : 'Export impossible.',
                            isError: !ok,
                          );
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exporter TSV'),
                ),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilledButton.icon(
                    style: compactActionStyle,
                    onPressed: _openFiltersSheet,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Filtres'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: compactActionStyle,
                    onPressed: _loading
                        ? null
                        : () => unawaited(_loadSubscriptions()),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Actualiser'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: compactActionStyle,
                    onPressed: records.isEmpty
                        ? null
                        : () async {
                            final ok = await exportTsvFile(
                              filename: 'abonnements_historique.tsv',
                              content: _buildSubscriptionsTsv(records),
                            );
                            if (!context.mounted) return;
                            _showMeevoToast(
                              context,
                              ok
                                  ? 'Export historique pret.'
                                  : 'Export impossible.',
                              isError: !ok,
                            );
                          },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Exporter'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: compactActionStyle,
                    onPressed: () {
                      setState(() {
                        _paymentStatus = 'Tous';
                        _subscriptionState = 'Tous';
                        _network = 'Tous';
                        _yearFilter = 'Tous';
                        _monthFilter = 'Tous';
                      });
                      unawaited(_loadSubscriptions());
                    },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _SectionPanel(
            title: 'Historique finalise',
            child: _AdminSubscriptionHistoryView(
              records: records,
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubscriptionHistoryView extends StatefulWidget {
  const _AdminSubscriptionHistoryView({
    required this.records,
    required this.loading,
  });

  final List<AdminSubscriptionRecord> records;
  final bool loading;

  @override
  State<_AdminSubscriptionHistoryView> createState() =>
      _AdminSubscriptionHistoryViewState();
}

class _AdminSubscriptionHistoryViewState
    extends State<_AdminSubscriptionHistoryView> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _nudgeHorizontal(double delta) async {
    if (!_horizontalController.hasClients) return;
    final max = _horizontalController.position.maxScrollExtent;
    final target = (_horizontalController.offset + delta).clamp(0.0, max);
    await _horizontalController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    if (widget.loading && widget.records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _meevoPurple)),
      );
    }

    if (widget.records.isEmpty) {
      return const Text(
        'Aucun abonnement finalise trouve pour ces filtres.',
        style: TextStyle(color: _meevoMuted),
      );
    }

    final headingStyle = TextStyle(
      color: _meevoDeepBlue,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 13,
    );
    final cellStyle = TextStyle(
      color: _meevoDeepBlue,
      fontSize: compact ? 12 : 13,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Glissez dans le tableau ou utilisez les fleches.',
                    style: TextStyle(color: _meevoMuted, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => unawaited(_nudgeHorizontal(-220)),
                  tooltip: 'Voir a gauche',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: _meevoDeepBlue,
                    backgroundColor: const Color(0xFFF4F1FF),
                    minimumSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => unawaited(_nudgeHorizontal(220)),
                  tooltip: 'Voir a droite',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: _meevoDeepBlue,
                    backgroundColor: const Color(0xFFF4F1FF),
                    minimumSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAE7F7)),
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: compact,
            trackVisibility: compact,
            interactive: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            thickness: compact ? 8 : 10,
            radius: const Radius.circular(999),
            child: SingleChildScrollView(
              controller: _horizontalController,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: compact ? 980 : 1180),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8F7FC),
                  ),
                  dataRowMinHeight: compact ? 52 : 60,
                  dataRowMaxHeight: compact ? 72 : 86,
                  horizontalMargin: compact ? 12 : 18,
                  columnSpacing: compact ? 20 : 28,
                  headingTextStyle: headingStyle,
                  dataTextStyle: cellStyle,
                  columns: [
                    DataColumn(label: Text('Business', style: headingStyle)),
                    DataColumn(label: Text('Contact', style: headingStyle)),
                    DataColumn(label: Text('Reference', style: headingStyle)),
                    DataColumn(label: Text('Reseau', style: headingStyle)),
                    DataColumn(label: Text('Mois', style: headingStyle)),
                    DataColumn(label: Text('Montant', style: headingStyle)),
                    DataColumn(label: Text('Paiement', style: headingStyle)),
                    DataColumn(label: Text('Abonnement', style: headingStyle)),
                    DataColumn(label: Text('Visible', style: headingStyle)),
                    DataColumn(label: Text('Expire le', style: headingStyle)),
                  ],
                  rows: widget.records.map((record) {
                    final businessName =
                        record.user.partnerProfile?.businessName.isNotEmpty ==
                            true
                        ? record.user.partnerProfile!.businessName
                        : record.user.fullName;
                    final subscriptionLabel =
                        switch (record.subscriptionState) {
                          'active' => 'Actif',
                          'expiring_soon' => 'Expire bientot',
                          'grace' => 'Grace',
                          'expired' => 'Expire',
                          _ => 'Inactif',
                        };
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: compact ? 120 : 180,
                            child: Text(
                              businessName,
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: compact ? 190 : 230,
                            child: Text(
                              '${record.user.fullName}\n${record.user.email}',
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: compact ? 160 : 220,
                            child: Text(
                              record.payment.identifier,
                              overflow: TextOverflow.ellipsis,
                              style: cellStyle,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            record.payment.network == 'TOGOCEL'
                                ? 'Yas / TMoney'
                                : 'Moov / Flooz',
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            record.payment.months.toString(),
                            style: cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatMoney(record.payment.totalAmount, 'FCFA'),
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(
                          _AdminStatusBadge(
                            label: record.payment.status,
                            color: _subscriptionPaymentStatusColor(
                              record.payment.status,
                            ),
                          ),
                        ),
                        DataCell(
                          _AdminStatusBadge(
                            label: subscriptionLabel,
                            color: switch (record.subscriptionState) {
                              'active' => const Color(0xFF16A34A),
                              'expiring_soon' => const Color(0xFFF59E0B),
                              'grace' => const Color(0xFFF97316),
                              'expired' => const Color(0xFFB42318),
                              _ => const Color(0xFF667085),
                            },
                          ),
                        ),
                        DataCell(
                          _AdminStatusBadge(
                            label: record.isVisiblePublicly
                                ? 'Visible'
                                : 'Masque',
                            color: record.isVisiblePublicly
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF667085),
                          ),
                        ),
                        DataCell(
                          Text(
                            record.expiresAt == null
                                ? '--'
                                : _formatDisplayDate(record.expiresAt!),
                            style: cellStyle,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminSubscriptionHistoryFilters {
  const _AdminSubscriptionHistoryFilters({
    required this.paymentStatus,
    required this.subscriptionState,
    required this.network,
    required this.yearFilter,
    required this.monthFilter,
  });

  final String paymentStatus;
  final String subscriptionState;
  final String network;
  final String yearFilter;
  final String monthFilter;
}

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AdminBookingsPage extends StatelessWidget {
  const _AdminBookingsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MeevoState>();

    return Scaffold(
      backgroundColor: _meevoBackground,
      appBar: AppBar(
        backgroundColor: _meevoHeaderBlue,
        title: const Text('Toutes les reservations'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _PartnerBookingsPanel(bookings: state.bookings, withPanel: false),
        ],
      ),
    );
  }
}

Future<T?> _showSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T value) labelBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.78;
      return SafeArea(
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final value = values[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(labelBuilder(value)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(sheetContext, value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showMeevoToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFB53B3B) : _meevoDeepBlue,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
    ),
  );
}

void _goToRootPage(BuildContext context, int index) {
  final state = context.read<MeevoState>();
  Navigator.of(context).popUntil((route) => route.isFirst);
  state.setPageIndex(index);
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.selectedIndex,
    required this.isPartnerMode,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool isPartnerMode;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home, 'Accueil'),
      (Icons.search_outlined, Icons.search, 'Recherche'),
      (Icons.calendar_month_outlined, Icons.calendar_month, 'Reservation'),
      (Icons.person_outline, Icons.person, 'Profil'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = selectedIndex == index;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _meevoYellow.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isActive ? item.$2 : item.$1,
                        color: isActive ? _meevoPurple : _meevoMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? _meevoPurple : _meevoMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

String _formatMoney(double amount, String currency) {
  final formatter = NumberFormat.decimalPattern('fr_FR');
  return '${formatter.format(amount.round())} $currency';
}

String _formatShortDate(DateTime value) =>
    DateFormat('dd MMM', 'fr_FR').format(value);

String _formatDisplayDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd MMM yyyy', 'fr_FR').format(parsed.toLocal());
}

String _userInitials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'ME';
  if (parts.length == 1) {
    final name = parts.first;
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _formatApiDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Uri? _buildVenueMapsUri(Venue venue) {
  if ((venue.googleMapsUrl ?? '').isNotEmpty) {
    return Uri.tryParse(venue.googleMapsUrl!);
  }

  if (venue.latitude != null && venue.longitude != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${venue.latitude},${venue.longitude}',
    );
  }

  return null;
}

TimeOfDay _parseTime(
  String? value, {
  required int fallbackHour,
  required int fallbackMinute,
}) {
  if (value == null || !value.contains(':')) {
    return TimeOfDay(hour: fallbackHour, minute: fallbackMinute);
  }

  final parts = value.split(':');
  final hour = int.tryParse(parts.first);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;

  return TimeOfDay(
    hour: hour ?? fallbackHour,
    minute: minute ?? fallbackMinute,
  );
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _timeToMinutes(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return hour * 60 + minute;
}

int _compareTimes(String left, String right) {
  return _timeToMinutes(left).compareTo(_timeToMinutes(right));
}

String _minutesToTimeString(int value) {
  final normalized = value.clamp(0, 23 * 60 + 59);
  final hour = (normalized ~/ 60).toString().padLeft(2, '0');
  final minute = (normalized % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _addOneHour(String value) {
  return _minutesToTimeString(_timeToMinutes(value) + 60);
}

String _subtractOneHour(String value) {
  return _minutesToTimeString(_timeToMinutes(value) - 60);
}

String _timeFromDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

bool _rangesOverlap(
  String leftStart,
  String leftEnd,
  String rightStart,
  String rightEnd,
) {
  final leftStartMinutes = _timeToMinutes(leftStart);
  final leftEndMinutes = _timeToMinutes(leftEnd);
  final rightStartMinutes = _timeToMinutes(rightStart);
  final rightEndMinutes = _timeToMinutes(rightEnd);

  return leftStartMinutes < rightEndMinutes &&
      rightStartMinutes < leftEndMinutes;
}

List<String> _mergeUniqueLabels(Iterable<String> values) {
  final merged = <String>[];
  final seen = <String>{};

  for (final value in values) {
    final trimmed = value.trim();
    final normalized = _normalizedLabelKey(trimmed);
    if (trimmed.isEmpty || normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    merged.add(trimmed);
  }

  return merged;
}

String _formatCompactMoney(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M FCFA';
  }

  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 0)}k FCFA';
  }

  return '${amount.toStringAsFixed(0)} FCFA';
}

InputDecoration _adminDropdownDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7F6FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

Color _subscriptionPaymentStatusColor(String status) {
  switch (status) {
    case 'success':
      return const Color(0xFF199F64);
    case 'pending':
    case 'processing':
      return const Color(0xFFF59E0B);
    case 'expired':
    case 'cancelled':
    case 'failed':
      return const Color(0xFFB42318);
    default:
      return _meevoDeepBlue;
  }
}

String _guessMimeType(String fileName, String resourceType) {
  final parts = fileName.toLowerCase().split('.');
  final extension = parts.length > 1 ? parts.last : '';

  if (resourceType == 'video') {
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

String _buildBookingsTsv(List<BookingItem> bookings) {
  const headers = [
    'Lieu',
    'Client',
    'Telephone',
    'Date',
    'Debut',
    'Fin',
    'Invites',
    'Budget',
    'Total',
    'Statut',
    'Source',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final booking in bookings) {
    buffer.writeln(
      [
        booking.venue?.name ?? '',
        booking.customerName ?? '',
        booking.customerPhone ?? '',
        booking.eventDate,
        booking.startTime,
        booking.endTime,
        booking.guestCount.toString(),
        booking.budget?.toStringAsFixed(0) ?? '',
        booking.totalAmount.toStringAsFixed(0),
        booking.status,
        booking.source,
      ].join('\t'),
    );
  }

  return buffer.toString();
}

String _buildReservationPaymentsTsv(
  List<ReservationPaymentData> payments, {
  required bool includePartner,
}) {
  final headers = [
    if (includePartner) 'Partenaire',
    'Lieu',
    'Client',
    'Telephone',
    'Date',
    'Debut',
    'Fin',
    'Invites',
    'Montant_brut',
    'Commission_meevo',
    'Net_partenaire',
    'Reseau_client',
    'Paiement',
    'Reversement',
    'Numero_reversement',
    'Reference_paiement',
    'Reference_reversement',
    'Date_paiement',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final payment in payments) {
    buffer.writeln(
      [
        if (includePartner)
          payment.partner?.partnerProfile?.businessName ??
              payment.partner?.fullName ??
              '',
        payment.venue?.name ?? '',
        payment.customerName,
        payment.phoneNumber,
        payment.eventDate,
        payment.startTime,
        payment.endTime,
        payment.guestCount.toString(),
        payment.grossAmount.toStringAsFixed(0),
        payment.platformFeeAmount.toStringAsFixed(0),
        payment.partnerNetAmount.toStringAsFixed(0),
        payment.network,
        payment.status,
        payment.payoutStatus,
        payment.payoutPhoneNumber ?? '',
        payment.paymentReference?.isNotEmpty == true
            ? payment.paymentReference!
            : payment.identifier,
        payment.payoutReference ?? '',
        payment.paidAt ?? '',
      ].join('\t'),
    );
  }

  return buffer.toString();
}

String _reservationPayoutStatusLabel(String status) {
  switch (status) {
    case 'ready':
      return 'Pret';
    case 'paid':
      return 'Reverse';
    case 'pending_profile':
      return 'Profil payout';
    default:
      return status;
  }
}

String _reservationPaymentNetworkLabel(String network) {
  switch (network) {
    case 'MOOV':
      return 'Moov';
    case 'TOGOCEL':
      return 'Yas';
    default:
      return network;
  }
}

String _reservationFinanceRangeLabel(String range) {
  switch (range) {
    case 'week':
      return 'Semaine';
    case 'month':
      return 'Mois';
    case '6m':
      return '6 mois';
    case 'year':
      return 'Annee';
    case 'all':
      return 'Tout';
    default:
      return range;
  }
}

String _buildVenuesTsv(List<Venue> venues) {
  const headers = [
    'Nom',
    'Ville',
    'Quartier',
    'Capacite',
    'Prix_depart',
    'Note',
    'Avis',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final venue in venues) {
    buffer.writeln(
      [
        venue.name,
        venue.city,
        venue.district ?? '',
        venue.capacity.toString(),
        venue.startingPrice.toStringAsFixed(0),
        venue.rating.toStringAsFixed(1),
        venue.reviewCount.toString(),
      ].join('\t'),
    );
  }

  return buffer.toString();
}

String _buildProvidersTsv(List<ProviderProfile> providers) {
  const headers = [
    'Nom',
    'Categorie',
    'Ville',
    'Prix_depart',
    'Note',
    'Avis',
    'Telephone',
    'Whatsapp',
    'Email',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final provider in providers) {
    buffer.writeln(
      [
        provider.name,
        provider.category,
        provider.city,
        provider.startingPrice.toStringAsFixed(0),
        provider.rating.toStringAsFixed(1),
        provider.reviewCount.toString(),
        provider.phone ?? '',
        provider.whatsapp ?? '',
        provider.email ?? '',
      ].join('\t'),
    );
  }

  return buffer.toString();
}

String _buildSubscriptionsTsv(List<AdminSubscriptionRecord> records) {
  const headers = [
    'Business',
    'Contact',
    'Email',
    'Telephone',
    'Reference',
    'Reseau',
    'Mois',
    'Montant',
    'Statut_paiement',
    'Etat_abonnement',
    'Visible_public',
    'Expire_le',
    'Fin_grace',
    'Cree_le',
    'Paye_le',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final record in records) {
    buffer.writeln(
      [
        record.user.partnerProfile?.businessName ?? record.user.fullName,
        record.user.fullName,
        record.user.email,
        record.user.phone ?? '',
        record.payment.identifier,
        record.payment.network,
        record.payment.months.toString(),
        record.payment.totalAmount.toStringAsFixed(0),
        record.payment.status,
        record.subscriptionState,
        record.isVisiblePublicly ? 'oui' : 'non',
        record.expiresAt ?? '',
        record.graceEndsAt ?? '',
        record.payment.createdAt ?? '',
        record.payment.paidAt ?? '',
      ].join('\t'),
    );
  }

  return buffer.toString();
}

String _buildAdminUsersTsv(List<AdminUserRecord> records) {
  const headers = [
    'Nom',
    'Email',
    'Telephone',
    'Ville',
    'Role',
    'Business',
    'Type_partenaire',
    'Whatsapp',
    'Etat_abonnement',
    'Cree_le',
  ];

  final buffer = StringBuffer()..writeln(headers.join('\t'));

  for (final record in records) {
    buffer.writeln(
      [
        record.user.fullName,
        record.user.email,
        record.user.phone ?? '',
        record.user.city ?? '',
        record.user.role,
        record.businessName,
        record.partnerType,
        record.whatsapp,
        record.subscriptionState,
        record.user.createdAt ?? '',
      ].join('\t'),
    );
  }

  return buffer.toString();
}

bool _isFinalSubscriptionPaymentStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized != 'pending' && normalized != 'processing';
}

Color _bookingStatusColor(String status) {
  switch (status) {
    case 'confirmed':
      return const Color(0xFF199F64);
    case 'rejected':
    case 'cancelled':
      return const Color(0xFFE05D5D);
    case 'pending':
    default:
      return const Color(0xFFE59C10);
  }
}

Widget _placeholderMedia(String label) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_meevoPurpleLight, _meevoPurple],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

Future<void> _launchUrl(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
