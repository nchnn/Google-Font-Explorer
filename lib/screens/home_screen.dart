import 'package:material_ui/material_ui.dart';

import '../data/font_data.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/font_card.dart';
import '../widgets/font_text.dart';
import '../widgets/style_sample.dart';
import '../widgets/section_heading.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              // Header with Brand and Theme Switcher
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : AppColors.charcoal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: const Icon(Icons.text_fields_rounded, color: Colors.white),
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
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'GOOGLE FONTS EXPLORER',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Theme Toggle Button
                  IconButton(
                    onPressed: appState.toggleTheme,
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    icon: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Make every word',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'feel different.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Explore typefaces, test your own text, and discover the right typography for every idea.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => appState.selectedTab = 1,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore fonts'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: 'Your current font', subtitle: 'Selected typeface preview'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                                fontSize: 17,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(Icons.check_circle, size: 19, color: theme.colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FontText(
                        fontFamily: selectedFont.name,
                        text: 'Aa Bb Cc 123',
                        style: TextStyle(fontSize: 38, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedFont.description,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => appState.selectedTab = 2,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Customize preview'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(
                title: 'Popular typefaces',
                subtitle: 'A few styles to get you started',
                trailing: TextButton(onPressed: () => appState.selectedTab = 1, child: const Text('See all')),
              ),
              const SizedBox(height: 12),
              ...availableFonts.take(3).map(
                (font) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FontCard(
                    font: font,
                    isSelected: selectedFont.name == font.name,
                    onTap: () => appState.selectFont(font, preview: PreviewState.read(context)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SectionHeading(title: 'Typography styles', subtitle: 'One family, many levels of hierarchy'),
              const SizedBox(height: 12),
              StyleSample(font: selectedFont.name, label: 'Display', size: 34, weight: FontWeight.w700),
              StyleSample(font: selectedFont.name, label: 'Heading 1', size: 28, weight: FontWeight.w700),
              StyleSample(font: selectedFont.name, label: 'Heading 2', size: 23, weight: FontWeight.w600),
              StyleSample(font: selectedFont.name, label: 'Heading 3', size: 19, weight: FontWeight.w600),
              StyleSample(font: selectedFont.name, label: 'Subtitle', size: 16, weight: FontWeight.w500),
              StyleSample(font: selectedFont.name, label: 'Body text', size: 14, weight: FontWeight.w400),
              StyleSample(font: selectedFont.name, label: 'Caption', size: 12, weight: FontWeight.w400),
              StyleSample(font: selectedFont.name, label: 'Bold / Italic', size: 15, weight: FontWeight.w700, italic: true),
            ]),
          ),
        ),
      ],
    );
  }
}
