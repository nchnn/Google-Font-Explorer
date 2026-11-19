import 'package:material_ui/material_ui.dart';

import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/preview_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/floating_pill_navigation.dart';

class TypeStudioApp extends StatelessWidget {
  const TypeStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      child: const _TypeStudioShell(),
    );
  }
}

/// The shell rebuilds only when [AppState] notifies (tab, theme, or font
/// change). Preview-specific mutations (font size, weight, alignment) go
/// through [PreviewState] and only the preview screen rebuilds.
class _TypeStudioShell extends StatelessWidget {
  const _TypeStudioShell();

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);

    return MaterialApp(
      title: 'TypeStudio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: IndexedStack(
                index: appState.selectedTab,
                children: const [
                  HomeScreen(),
                  ExploreScreen(),
                  PreviewScreen(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 1,
                    child: FloatingPillNavigation(
                      selectedIndex: appState.selectedTab,
                      onDestinationSelected: (index) {
                        if (index == appState.selectedTab) return;
                        appState.selectedTab = index;
                      },
                      destinations: const [
                        FloatingPillDestination(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: 'Home',
                        ),
                        FloatingPillDestination(
                          icon: Icons.grid_view_rounded,
                          selectedIcon: Icons.grid_view_rounded,
                          label: 'Explore',
                        ),
                        FloatingPillDestination(
                          icon: Icons.text_fields_rounded,
                          selectedIcon: Icons.text_fields_rounded,
                          label: 'Preview',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
