Here is the current architectural gold standard for handling adaptive layouts and custom design systems in Flutter.
The gold standard is not to create entirely separate "main screens" based on device type. Doing so creates massive code duplication and breaks state when a user rotates their phone, plugs into an external display, or resizes a window in split-screen mode. [1, 2, 3] 
Instead, the modern standard relies on Responsive Shells with Slot-Based Layouts driven entirely by Window Size (Width) rather than device model. [2, 4] 
## The Strategy: Unified Screen, Adaptive Slots
You should have one single dashboard or screen widget that adjusts its architecture reactively using standard Flutter layout boundaries. The typical breakpoint for mobile-to-tablet/desktop transitions is 600 logical pixels. [3, 4, 5, 6, 7] 

   1. Abstract Content from Layout: Pass data or small sub-widgets into a single structural widget.
   2. Use LayoutBuilder or MediaQuery.sizeOf: Rely on these to inspect constraints dynamically without killing state.
   3. Switch Components, Not Screens: On mobile (< 600px), render a BottomNavigationBar. On tablet (≥ 600px), swap only the navigation wrapper out for a NavigationRail or a fixed lateral menu while keeping the inner content view exactly the same. [2, 3, 4, 7, 8] 

## Recommended Packages

* 
* Built-in LayoutBuilder / MediaQuery.sizeOf(context): For most clean architectures, this is all you need. It introduces zero outside dependencies and operates strictly on reactive box constraints. [3, 5, 7, 8] 
* responsive_framework: The current ecosystem leader. Instead of forcing boilerplate layout conditions everywhere, it allows your app to scale or rearrange elements gracefully using a single wrapper. [8, 9] 
* [dynamic_layouts](https://pub.dev/packages/dynamic_layouts): A newer, lightweight, dependency-free approach built strictly for reactive window and safe-area adjustments across mobile and desktop. [5] 
* 

------------------------------
If you are intentionally avoiding Material Design's massive color palette, token naming conventions (surfaceContainerHighest, onPrimaryContainer), and component styling, the absolute gold standard is using ThemeExtension. [10, 11] 
Instead of writing a custom InheritedWidget from scratch, ThemeExtension lets you hook directly into Flutter’s existing Theme.of(context) system while using a completely custom, minimal, domain-specific design token schema. [11] 
## The Strategy: Defining Custom Classes
Create a custom immutable class that extends ThemeExtension. This allows you to define exactly the properties you need (e.g., just brandColor, background, textPrimary) without polluting your code with Material constraints.

class AppThemeData extends ThemeExtension<AppThemeData> {
  final Color background;
  final Color accent;
  final TextStyle headline;

  AppThemeData({
    required this.background,
    required this.accent,
    required this.headline,
  });

  @override
  AppThemeData copyWith({Color? background, Color? accent, TextStyle? headline}) {
    return AppThemeData(
      background: background ?? this.background,
      accent: accent ?? this.accent,
      headline: headline ?? this.headline,
    );
  }

  @override
  AppThemeData lerp(ThemeExtension<AppThemeData>? other, double t) {
    if (other is! AppThemeData) return this;
    return AppThemeData(
      background: Color.lerp(background, other.background, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
    );
  }
}

You inject your custom classes inside your standard MaterialApp configuration using the extensions parameter:

MaterialApp(
  theme: ThemeData(
    extensions: [
      AppThemeData(
        background: Colors.white,
        accent: Colors.blue,
        headline: TextStyle(fontSize: 24, color: Colors.black),
      ),
    ],
  ),
  darkTheme: ThemeData(
    extensions: [
      AppThemeData(
        background: Colors.black,
        accent: Colors.blueAccent,
        headline: TextStyle(fontSize: 24, color: Colors.white),
      ),
    ],
  ),
);

To call your custom, tight design system cleanly in your widgets:

final customTheme = Theme.of(context).extension<AppThemeData>()!;// Use: customTheme.background or customTheme.accent

## Recommended Packages

* 
* [theme_tailor](https://pub.dev/packages/theme_tailor): The current definitive package for this approach. It uses code generation to completely eliminate the tedious boilerplate of writing copyWith and lerp methods for your ThemeExtension models. You just define your light/dark fields, and it builds the rest. [12] 
* [adaptive_theme](https://pub.dev/packages/adaptive_theme): Perfect for persisting the user's manual selection (light vs. dark) to local storage automatically while handling runtime transitions cleanly. [12] 
* 

If you want to know more about structuring these concepts, let me know:

* 
* What state management framework you plan to use (Riverpod, Bloc, Provider, etc.)?
* Whether you want to view a code snippet for an adaptive master-detail layout skeleton? [13, 14, 15] 
* 


[1] [https://docs.flutter.dev](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)
[2] [https://www.freecodecamp.org](https://www.freecodecamp.org/news/how-to-build-responsive-uis-in-flutter/)
[3] [https://liudonghua123.github.io](https://liudonghua123.github.io/flutter_website/ui/layout/adaptive-responsive/)
[4] [https://docs.flutter.dev](https://docs.flutter.dev/ui/adaptive-responsive/general)
[5] [https://pub.dev](https://pub.dev/packages/dynamic_layouts)
[6] [https://docs.flutter.dev](https://docs.flutter.dev/learn/pathway/tutorial/adaptive-layout)
[7] [https://medium.com](https://medium.com/@smtoramesh/flutter-adaptive-responsive-ui-0f8289844819)
[8] [https://nurobyte.medium.com](https://nurobyte.medium.com/say-goodbye-to-broken-layouts-flutters-best-responsive-ui-tools-in-2025-125d297e5a62)
[9] [https://medium.com](https://medium.com/@tiger.chirag/build-responsive-flutter-ui-that-works-across-all-devices-in-2025-the-smart-way-1da9cdc3432b)
[10] [https://stackoverflow.com](https://stackoverflow.com/questions/78433156/implementing-darktheme-configuration-in-custom-flutter-app-structure)
[11] [https://blog.anmolthedeveloper.com](https://blog.anmolthedeveloper.com/flutter-theme-guide-light-mode-dark-mode-system-theme-and-custom-brand-colors)
[12] [https://fluttergems.dev](https://fluttergems.dev/light-mode-dark-mode-themes/)
[13] [https://www.youtube.com](https://www.youtube.com/watch?v=ZQEjNPvFk2c)
[14] [https://www.youtube.com](https://www.youtube.com/watch?v=tyTs269hUqI&t=70)
[15] [https://fluttergems.dev](https://fluttergems.dev/responsive-ui/)


Using Riverpod pairs perfectly with adaptive shells and custom theme extensions because its global providers allow you to watch window changes and theme transitions cleanly without polluting the widget tree.
Here is how you structure both systems using Riverpod.
## 1. Riverpod Setup for Adaptive Layouts
Instead of calling MediaQuery.sizeOf(context) inside every single widget, the current best practice is to compute the breakpoint or window size in a global provider. This prevents unnecessary widget rebuilds.

import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';
enum DisplayProfile { mobile, tablet }
// 1. A provider that exposes the current DisplayProfile based on the window sizefinal displayProfileProvider = Provider<DisplayProfile>((ref) {
  // We use PlatformDispatcher to read window metrics outside the widget tree safely
  final container = PlatformDispatcher.instance.views.first;
  final logicalWidth = container.physicalSize.width / container.devicePixelRatio;
  
  return logicalWidth < 600 ? DisplayProfile.mobile : DisplayProfile.tablet;
});
// 2. An Adaptive Shell Widget using Riverpodclass AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile. The widget only rebuilds if the profile actually switches.
    final displayProfile = ref.watch(displayProfileProvider);

    if (displayProfile == DisplayProfile.tablet) {
      return Scaffold(
        body: Row(
          children: [
            const NavigationRail(
              destinations: [/* Your Destinations */], 
              selectedIndex: 0,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNavigationBar(
        items: [/* Your Items */],
      ),
    );
  }
}

------------------------------
## 2. Riverpod Setup for Your Custom Design System
To manage your non-Material theme mode (Light, Dark, or System default) and persist the user's choice, you can use a NotifierProvider.

import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';// Note: If you use the 'theme_tailor' package, import your generated theme file here instead
// 1. Manage the theme mode stateclass ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system; // Fallback to device preference

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
  
  void setMode(ThemeMode mode) => state = mode;
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
// 2. Wrap your MaterialApp using the providerclass MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      themeMode: themeMode,
      // Minimal Material wrappers containing only your clean ThemeExtensions
      theme: ThemeData(
        extensions: [
          AppThemeData(
            background: Colors.white,
            textPrimary: Colors.black,
          ),
        ],
      ),
      darkTheme: ThemeData(
        extensions: [
          AppThemeData(
            background: Colors.black,
            textPrimary: Colors.white,
          ),
        ],
      ),
      home: const DashboardScreen(),
    );
  }
}

## How to toggle it from any Widget:

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.palette),
      onPressed: () {
        // Reads the notifier and triggers the toggle cleanly via Riverpod
        ref.read(themeModeProvider.notifier).toggleTheme();
      },
    );
  }
}

To take this a step further, let me know if you would like me to:

* Provide code to automatically persist the chosen theme to local storage using shared_preferences inside Riverpod?
* Show how to pair this setup with routing frameworks like GoRouter for adaptive split-screen navigation?


To pair an adaptive layout with GoRouter, the modern architectural standard is to use a StatefulShellRoute.
This allows you to maintain independent navigation states for each tab/item, keep your core layouts unified without duplicating screens, and reactively swap between a mobile BottomNavigationBar and a tablet/desktop NavigationRail or sidebar based on window size.
Here is how you implement an adaptive split-screen navigation system using GoRouter and Riverpod based on our past setup:
## 1. Defining the Adaptive Shell Widget
This widget wraps your target nested pages (navigationShell). It watches your Riverpod displayProfileProvider to dynamically render the navigation skeleton without breaking state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/display_profile_provider.dart'; // From past conversation

class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({
    super.key,
    required this.navigationShell,
  });

  // StatefulShellRoute passes a StatefulNavigationShell containing nested routes
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayProfile = ref.watch(displayProfileProvider);

    // Desktop/Tablet View: Lateral Navigation
    if (displayProfile == DisplayProfile.tablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true, // Shows icons + text labels
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onTap(context, index),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // The split-screen content pane
            Expanded(
              child: navigationShell,
            ),
          ],
        ),
      );
    }

    // Mobile View: Bottom Navigation
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    // Navigates to the associated branch root, preserving branch state automatically
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

## 2. Setting Up the GoRouter Architecture
We use StatefulShellRoute.indexedStack to cleanly group separate navigation stacks (branches) inside the layout wrapper.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'adaptive_shell.dart';

// Global router provider for Riverpod
final routerProvider = Provider<GoRouter>((ref) {
  // Global navigator key for top-level pages (like Login, Modals, etc.)
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: '/dashboard',
    navigatorKey: rootNavigatorKey,
    routes: [
      // The Adaptive Stateful Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Dashboard Navigation Stack
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  // Sub-route inside the Dashboard stack (maintains split-screen navigation)
                  GoRoute(
                    path: 'details',
                    builder: (context, state) => const DetailScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Settings Navigation Stack
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

## 3. Updating your main app entry point
Feed the routerProvider into your root MaterialApp.router constructor to link the Riverpod state initialization completely with GoRouter.

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider); // From past setup

    return MaterialApp.router(
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(extensions: [/* Custom Light Extensions */]),
      darkTheme: ThemeData(extensions: [/* Custom Dark Extensions */]),
    );
  }
}

If you are expanding this architecture further, let me know if you would like me to:

* Provide code for an adaptive master-detail structure that transitions from a single screen on mobile into a side-by-side pane view on tablet?
* Show how to handle deep linking parameters or query strings gracefully inside these isolated shell branches?


To pair an adaptive layout with GoRouter, the modern architectural standard is to use a StatefulShellRoute.
This allows you to maintain independent navigation states for each tab/item, keep your core layouts unified without duplicating screens, and reactively swap between a mobile BottomNavigationBar and a tablet/desktop NavigationRail or sidebar based on window size.
Here is how you implement an adaptive split-screen navigation system using GoRouter and Riverpod based on our past setup:
## 1. Defining the Adaptive Shell Widget
This widget wraps your target nested pages (navigationShell). It watches your Riverpod displayProfileProvider to dynamically render the navigation skeleton without breaking state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/display_profile_provider.dart'; // From past conversation

class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({
    super.key,
    required this.navigationShell,
  });

  // StatefulShellRoute passes a StatefulNavigationShell containing nested routes
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayProfile = ref.watch(displayProfileProvider);

    // Desktop/Tablet View: Lateral Navigation
    if (displayProfile == DisplayProfile.tablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true, // Shows icons + text labels
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onTap(context, index),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // The split-screen content pane
            Expanded(
              child: navigationShell,
            ),
          ],
        ),
      );
    }

    // Mobile View: Bottom Navigation
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    // Navigates to the associated branch root, preserving branch state automatically
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

## 2. Setting Up the GoRouter Architecture
We use StatefulShellRoute.indexedStack to cleanly group separate navigation stacks (branches) inside the layout wrapper.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'adaptive_shell.dart';

// Global router provider for Riverpod
final routerProvider = Provider<GoRouter>((ref) {
  // Global navigator key for top-level pages (like Login, Modals, etc.)
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: '/dashboard',
    navigatorKey: rootNavigatorKey,
    routes: [
      // The Adaptive Stateful Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Dashboard Navigation Stack
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  // Sub-route inside the Dashboard stack (maintains split-screen navigation)
                  GoRoute(
                    path: 'details',
                    builder: (context, state) => const DetailScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Settings Navigation Stack
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

## 3. Updating your main app entry point
Feed the routerProvider into your root MaterialApp.router constructor to link the Riverpod state initialization completely with GoRouter.

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider); // From past setup

    return MaterialApp.router(
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(extensions: [/* Custom Light Extensions */]),
      darkTheme: ThemeData(extensions: [/* Custom Dark Extensions */]),
    );
  }
}

If you are expanding this architecture further, let me know if you would like me to:

* Provide code for an adaptive master-detail structure that transitions from a single screen on mobile into a side-by-side pane view on tablet?
* Show how to handle deep linking parameters or query strings gracefully inside these isolated shell branches?


To achieve a clean master-detail flow that handles window transitions reactively without losing state, the modern standard is to build a flexible dual-pane container.
On a mobile layout, selecting an item pushes a new route onto the navigation stack via GoRouter. On a tablet layout, the screen splits into a side-by-side pane where selecting an item updates the right-hand panel instantly on the same page.
Here is the robust implementation matching your Riverpod and GoRouter setup:
## 1. The Adaptive Master-Detail Container
This screen watches your global displayProfileProvider. If a user is on a tablet, it forces a two-pane layout. It reads a dynamic query or path parameter (selectedId) from GoRouter to understand which details to render in the right-hand split view.

import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';import 'package:go_router/go_router.dart';import 'providers/display_profile_provider.dart';
class AdaptiveMasterDetailScreen extends ConsumerWidget {
  const AdaptiveMasterDetailScreen({
    super.key,
    this.selectedItemId,
  });

  // Passed down via GoRouter URL pattern or query parameters
  final String? selectedItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayProfile = ref.watch(displayProfileProvider);

    // Tablet Layout: Split-pane View
    if (displayProfile == DisplayProfile.tablet) {
      return Scaffold(
        body: Row(
          children: [
            // Left Side: Fixed-width Master List
            SizedBox(
              width: 320,
              child: MasterList(
                selectedId: selectedItemId,
                onItemSelected: (id) {
                  // In tablet view, replace the URL state without pushing a brand new screen
                  context.go('/items?id=$id');
                },
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Right Side: Flexible Detail Pane
            Expanded(
              child: selectedItemId != null
                  ? DetailPane(itemId: selectedItemId!)
                  : const Center(child: Text('Select an item to view details')),
            ),
          ],
        ),
      );
    }

    // Mobile Layout: Single Pane List View
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: MasterList(
        selectedId: null,
        onItemSelected: (id) {
          // In mobile view, push a separate deep page into the navigation stack
          context.go('/items/detail/$id');
        },
      ),
    );
  }
}

## 2. Updating your GoRouter Configuration
To make this work seamlessly on both configurations, GoRouter needs to match two distinct paths or handle parameters gracefully. We map a base route with an optional query parameter for tablet sizing, and a sub-route specifically for mobile fallback stacks.

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/items',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShell(navigationShell: navigationShell); // From previous step
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/items',
                builder: (context, state) {
                  // Captures query parameter like: /items?id=123 (Used by Tablet)
                  final selectedId = state.uri.queryParameters['id'];
                  return AdaptiveMasterDetailScreen(selectedItemId: selectedId);
                },
                routes: [
                  // Sub-route path like: /items/detail/123 (Used by Mobile fallback stack)
                  GoRoute(
                    path: 'detail/:itemId',
                    builder: (context, state) {
                      final itemId = state.pathParameters['itemId']!;
                      return MobileDetailFallbackScreen(itemId: itemId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

## 3. Supporting Presentation Widgets
Here is how you write clean, non-duplicated UI components for the list and detail items.

// The shared Master List Widgetclass MasterList extends StatelessWidget {
  const MasterList({super.key, required this.selectedId, required this.onItemSelected});
  final String? selectedId;
  final ValueChanged<String> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        final itemId = 'item_$index';
        final isSelected = itemId == selectedId;

        return ListTile(
          title: Text('Item Blueprint #$index'),
          subtitle: Text('ID: $itemId'),
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          onTap: () => onItemSelected(itemId),
        );
      },
    );
  }
}
// The shared Detail Pane Widgetclass DetailPane extends StatelessWidget {
  const DetailPane({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details for $itemId', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const Text('This sub-view remains pure and handles content rendering without knowing whether it is living inside a split screen tablet or a standalone mobile window view.'),
        ],
      ),
    );
  }
}
// Mobile-only standalone wrapper page to provide a Scaffold + Back Buttonclass MobileDetailFallbackScreen extends StatelessWidget {
  const MobileDetailFallbackScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: DetailPane(itemId: itemId), // Reuses the exact same detail view layout
    );
  }
}

## What this achieves:

   1. Zero Layout Duplication: MasterList and DetailPane remain isolated from context windows. They just take callbacks and string variables.
   2. State Conservation on Rotation: If a tablet user resizes their screen or splits it down to standard mobile parameters, GoRouter and Riverpod catch the scale change natively.

If you want to fine-tune this implementation, let me know if you would like me to:

* Show how to implement a cross-fade transition animation using GoRouter's custom pageBuilder when switching items in the detail pane?
* Integrate an automated synchronizer that updates the URL if a phone pivots into landscape layout midway through a task?


