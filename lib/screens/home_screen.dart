import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/font_data.dart';
import '../models/font_model.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/font_shelf_tile.dart';
import '../widgets/font_text.dart';
import '../widgets/style_sample.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  late final AnimationController _blobController;
  late final Animation<double> _blobScale;

  late final AnimationController _entranceController;
  late final List<Animation<double>> _sectionFades;
  late final List<Animation<Offset>> _sectionSlides;

  static const _heroWords = [
    'Expressive.',
    'Distinct.',
    'Refined.',
    'Timeless.',
    'Yours.',
  ];
  int _heroWordIndex = 0;
  Timer? _heroWordTimer;

  static const _sectionCount = 6;

  @override
  void initState() {
    super.initState();

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _blobScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _blobController, curve: Curves.easeInOut),
    );

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
        );
    _heroController.forward();

    _heroWordTimer = Timer(const Duration(milliseconds: 2400), _cycleHeroWord);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sectionFades = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 0.7);
      final end = (start + 0.3).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _sectionSlides = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 0.7);
      final end = (start + 0.3).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _entranceController.forward();
  }

  void _cycleHeroWord() {
    if (!mounted) return;
    _heroController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _heroWordIndex = (_heroWordIndex + 1) % _heroWords.length;
      });
      _heroController.forward().then((_) {
        if (!mounted) return;
        _heroWordTimer = Timer(
          const Duration(milliseconds: 2400),
          _cycleHeroWord,
        );
      });
    });
  }

  @override
  void dispose() {
    _heroWordTimer?.cancel();
    _heroController.dispose();
    _blobController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Widget _section(int index, Widget child) {
    return FadeTransition(
      opacity: _sectionFades[index],
      child: SlideTransition(position: _sectionSlides[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedFont = appState.selectedFont;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            kFloatingPillNavigationClearance + 28,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _section(0, _buildHeader(appState, theme, isDark)),
              const SizedBox(height: 28),
              _section(1, _buildHero(theme, isDark, selectedFont)),
              const SizedBox(height: 20),
              _section(2, _buildStatsAndCta(appState, theme, isDark)),
              const SizedBox(height: 32),
              _section(
                3,
                _buildSelectedCard(appState, theme, isDark, selectedFont),
              ),
              const SizedBox(height: 32),
              _section(
                4,
                _buildFontShelf(appState, theme, isDark, selectedFont),
              ),
              const SizedBox(height: 32),
              _section(5, _buildTypographyRamp(theme, isDark, selectedFont)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppState appState, ThemeData theme, bool isDark) {
    return Row(
      children: [
        SvgPicture.asset(
          isDark ? 'assets/icons/logo_dark.svg' : 'assets/icons/logo_light.svg',
          width: 38,
          height: 38,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TypeStudio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              'GOOGLE FONTS EXPLORER',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSecondarySurface
                : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: IconButton(
            onPressed: appState.toggleTheme,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildHero(ThemeData theme, bool isDark, FontModel selectedFont) {
    final accentColor = isDark
        ? const Color(0xFF7B7BFF)
        : const Color(0xFF4B4BDF);

    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -20,
            right: -30,
            child: AnimatedBuilder(
              animation: _blobScale,
              builder: (_, _) => Transform.scale(
                scale: _blobScale.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        accentColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -20,
            child: AnimatedBuilder(
              animation: _blobScale,
              builder: (_, _) => Transform.scale(
                scale: 1.0 + (1.15 - _blobScale.value) * 0.6,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? AppColors.darkPrimaryAccent
                                : AppColors.charcoal)
                            .withValues(alpha: isDark ? 0.08 : 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Make every word',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: FontText(
                      fontFamily: selectedFont.name,
                      text: _heroWords[_heroWordIndex],
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        height: 1.1,
                        letterSpacing: -0.3,
                        color: accentColor,
                      ),
                      showErrorNotice: false,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Explore typefaces, test your text, and find the\nright typography for every idea.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndCta(AppState appState, ThemeData theme, bool isDark) {
    final stats = [
      (Icons.text_fields_rounded, '1,500+', 'Fonts'),
      (Icons.category_outlined, '9', 'Categories'),
      (Icons.lock_open_rounded, 'Free', 'Open Source'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: stats.map((s) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _StatChip(
                  icon: s.$1,
                  value: s.$2,
                  label: s.$3,
                  isDark: isDark,
                  theme: theme,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _AnimatedCta(
          label: 'Explore fonts',
          icon: Icons.explore_outlined,
          isDark: isDark,
          onPressed: () => appState.selectedTab = 1,
        ),
      ],
    );
  }

  Widget _buildSelectedCard(
    AppState appState,
    ThemeData theme,
    bool isDark,
    FontModel selectedFont,
  ) {
    final shadowAmbient = BoxShadow(
      color: isDark
          ? AppColors.shadowAmbientDark
          : AppColors.shadowAmbientLight,
      blurRadius: 20,
      offset: const Offset(0, 4),
    );
    final shadowKey = BoxShadow(
      color: isDark ? AppColors.shadowKeyDark : AppColors.shadowKeyLight,
      blurRadius: 8,
      offset: const Offset(0, 6),
    );
    final highlightBorder = isDark
        ? AppColors.glassHighlightDark
        : AppColors.glassHighlightLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: 'Current font',
          subtitle: 'Your selected typeface',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: [shadowAmbient, shadowKey],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: highlightBorder),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedFont.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: -0.3,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSecondarySurface
                                  : const Color(0xFFEBEBEB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FontText(
                        fontFamily: selectedFont.name,
                        text: 'Aa Bb Cc 123',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedFont.description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => appState.selectedTab = 2,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: const Text('Customize preview'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.border,
                          ),
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
    );
  }

  Widget _buildFontShelf(
    AppState appState,
    ThemeData theme,
    bool isDark,
    FontModel selectedFont,
  ) {
    final fonts = availableFonts.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionLabel(
                title: 'Popular typefaces',
                subtitle: 'Swipe to browse',
              ),
            ),
            TextButton(
              onPressed: () => appState.selectedTab = 1,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: FontShelfTile.tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: fonts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => FontShelfTile(
              font: fonts[i],
              isSelected: selectedFont.name == fonts[i].name,
              onTap: () => appState.selectFont(
                fonts[i],
                preview: PreviewState.read(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypographyRamp(
    ThemeData theme,
    bool isDark,
    FontModel selectedFont,
  ) {
    final samples = [
      ('Display', 34.0, FontWeight.w700, false),
      ('Heading 1', 28.0, FontWeight.w700, false),
      ('Heading 2', 23.0, FontWeight.w600, false),
      ('Heading 3', 19.0, FontWeight.w600, false),
      ('Subtitle', 16.0, FontWeight.w500, false),
      ('Body text', 14.0, FontWeight.w400, false),
      ('Caption', 12.0, FontWeight.w400, false),
      ('Bold / Italic', 15.0, FontWeight.w700, true),
    ];

    final shadowAmbient = BoxShadow(
      color: isDark
          ? AppColors.shadowAmbientDark
          : AppColors.shadowAmbientLight,
      blurRadius: 16,
      offset: const Offset(0, 3),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: 'Typography styles',
          subtitle: 'One family, many levels of hierarchy',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: [shadowAmbient],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              children: [
                for (int i = 0; i < samples.length; i++) ...[
                  ColoredBox(
                    color: i.isOdd
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.015)
                              : Colors.black.withValues(alpha: 0.012))
                        : Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: StyleSample(
                        font: selectedFont.name,
                        label: samples[i].$1,
                        size: samples[i].$2,
                        weight: samples[i].$3,
                        italic: samples[i].$4,
                      ),
                    ),
                  ),
                  if (i < samples.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.5)
                          : AppColors.border.withValues(alpha: 0.6),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Local helper widgets
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    required this.theme,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSecondarySurface
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.shadowAmbientDark
                : AppColors.shadowAmbientLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
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

class _AnimatedCta extends StatefulWidget {
  const _AnimatedCta({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  State<_AnimatedCta> createState() => _AnimatedCtaState();
}

class _AnimatedCtaState extends State<_AnimatedCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal;
    final fg = widget.isDark ? AppColors.darkBackground : Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              splashColor: Colors.white.withValues(alpha: 0.08),
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: fg, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.only(left: _pressed ? 2 : 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: fg,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
