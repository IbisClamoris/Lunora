import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lunora/core/navigation/lunora_navigation.dart';
import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/search/global_search_page.dart';
import 'package:lunora/features/books/pages/books_page.dart';
import 'package:lunora/features/diary/pages/diary_gallery_page.dart';
import 'package:lunora/features/diary/pages/diary_page.dart';
import 'package:lunora/features/diary/pages/diary_editor_page.dart';
import 'package:lunora/features/shopping/pages/shopping_editor_page.dart';
import 'package:lunora/features/recipes/pages/recipe_editor_page.dart';

import 'package:lunora/features/movies/pages/movies_page.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/pages/notifications_page.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';
import 'package:lunora/features/notifications/services/system_notification_service.dart';
import 'package:lunora/features/recipes/pages/recipes_page.dart';
import 'package:lunora/features/shopping/pages/shopping_page.dart';
import 'package:lunora/features/wishlist/pages/wishlist_page.dart';
import 'package:lunora/shared/widgets/lunora_theme_backdrop.dart';

import '../config/menu_entries.dart';
import '../pages/settings_page.dart';
import 'lunora_dashboard.dart';
import 'lunora_section_page.dart';
import 'lunora_sidebar.dart';
import 'lunora_top_bar.dart';
import 'lunora_window_title_bar.dart';

class LunoraHome extends StatefulWidget {
  const LunoraHome({super.key});

  @override
  State<LunoraHome> createState() => _LunoraHomeState();
}

class _LunoraHomeState extends State<LunoraHome> {
  static const double _sidebarBreakpoint = 900;

  final LunoraNavigation _navigation = LunoraNavigation();

  StreamSubscription<String>? _notificationSubscription;

  bool sidebarExpanded = true;

  String _searchQuery = '';
  int _financeInitialTabIndex = 0;
  bool _openPlannerNoteOnSection = false;

  static const Duration animationDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_onSettingsChanged);

    _notificationSubscription = SystemNotificationService
        .instance
        .onNotificationTap
        .listen(_handleNotificationTap);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final payload = SystemNotificationService.instance.takeLaunchPayload();

      if (payload != null) {
        _handleNotificationTap(payload);
      }
    });
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void openPage(int index) {
    if (index < 0 || index >= LunoraSection.values.length) return;

    setState(() {
      _searchQuery = '';
      _financeInitialTabIndex = 0;
    });

    _navigation.goTo(LunoraSection.values[index]);
  }

  Future<void> _openDashboardEditor(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
  }

  void _createPlannerNote() {
    setState(() {
      _searchQuery = '';
      _openPlannerNoteOnSection = true;
    });
    _navigation.goTo(LunoraSection.planner);
  }

  Future<void> _createDiaryEntry() async {
    await _openDashboardEditor(const DiaryEditorPage());
  }

  Future<void> _createShoppingItem() async {
    await _openDashboardEditor(const ShoppingEditorPage());
  }

  Future<void> _createRecipe() async {
    await _openDashboardEditor(const RecipeEditorPage());
  }

  void _openShoppingSection() => openPage(LunoraSection.shoppingList.index);

  void _openDebtSection() {
    setState(() {
      _searchQuery = '';
      _financeInitialTabIndex = 3;
    });
    _navigation.goTo(LunoraSection.finances);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  void toggleSidebar() {
    setState(() {
      sidebarExpanded = !sidebarExpanded;
    });
  }

  Future<void> _handleNotificationTap(String notificationId) async {
    try {
      final notification = await NotificationService.instance.getById(
        notificationId,
      );

      if (!mounted) return;

      if (notification == null) {
        _navigation.goTo(LunoraSection.notifications);
        return;
      }

      await NotificationService.instance.markRead(notificationId);

      if (!mounted) return;

      setState(() {
        _searchQuery = '';
      });

      _navigation.goTo(_getTargetSection(notification));
    } catch (error, stackTrace) {
      debugPrint('Ошибка перехода по уведомлению: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _searchQuery = '';
        });

        _navigation.goTo(LunoraSection.notifications);
      }
    }
  }

  LunoraSection _getTargetSection(NotificationItem notification) {
    switch (notification.sourceModule) {
      case 'task':
      case 'tasks':
        return LunoraSection.calendar;

      case 'calendar':
        return LunoraSection.calendar;

      case 'shopping_list':
      case 'shoppingList':
        return LunoraSection.shoppingList;

      case 'planner':
        return LunoraSection.planner;

      case 'study':
      case 'study_planner':
      case 'studyPlanner':
        return LunoraSection.studyPlanner;

      case 'finance':
      case 'finances':
        return LunoraSection.finances;

      case 'knowledge_base':
      case 'knowledgeBase':
        return LunoraSection.knowledgeBase;

      case 'books':
        return LunoraSection.books;

      case 'movies':
        return LunoraSection.movies;

      case 'recipes':
        return LunoraSection.recipes;

      case 'settings':
        return LunoraSection.settings;

      case 'import_export':
      case 'importExport':
      case 'backups':
        return LunoraSection.notifications;

      default:
        return _getTargetByCategory(notification.category);
    }
  }

  LunoraSection _getTargetByCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.tasks:
        return LunoraSection.calendar;

      case NotificationCategory.calendar:
        return LunoraSection.calendar;

      case NotificationCategory.finance:
        return LunoraSection.finances;

      case NotificationCategory.study:
        return LunoraSection.studyPlanner;

      case NotificationCategory.cooking:
        return LunoraSection.recipes;

      case NotificationCategory.importExport:
      case NotificationCategory.backups:
      case NotificationCategory.system:
      case NotificationCategory.other:
        return LunoraSection.notifications;
    }
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    _notificationSubscription?.cancel();
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final visibleIndices = <int>[
      for (var i = 0; i < LunoraSection.values.length; i++)
        if (i == LunoraSection.home.index ||
            i == LunoraSection.settings.index ||
            settings.isSectionEnabled(LunoraSection.values[i].name))
          i,
    ];

    return AnimatedBuilder(
      animation: _navigation,
      builder: (context, child) {
        var currentSection = _navigation.currentSection;
        if (currentSection != LunoraSection.home &&
            currentSection != LunoraSection.settings &&
            !settings.isSectionEnabled(currentSection.name)) {
          currentSection = LunoraSection.home;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigation.goHome();
          });
        }
        final currentIndex = currentSection.index;

        if (currentSection == LunoraSection.planner &&
            _openPlannerNoteOnSection) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _openPlannerNoteOnSection) {
              setState(() => _openPlannerNoteOnSection = false);
            }
          });
        }

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < _sidebarBreakpoint;

              final effectiveSidebarExpanded = sidebarExpanded && !isCompact;

              return Row(
                children: [
                  LunoraSidebar(
                    expanded: effectiveSidebarExpanded,
                    selectedIndex: currentIndex,
                    onSelect: openPage,
                    onToggle: toggleSidebar,
                    duration: animationDuration,
                    visibleIndices: visibleIndices,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const LunoraWindowTitleBar(),
                        LunoraTopBar(
                          onNotifications: () {
                            setState(() {
                              _searchQuery = '';
                            });

                            _navigation.goTo(LunoraSection.notifications);
                          },
                          onHome: () {
                            setState(() {
                              _searchQuery = '';
                            });

                            _navigation.goHome();
                          },
                          onSearchChanged: _onSearchChanged,
                        ),
                        Expanded(
                          child: LunoraThemeBackdrop(
                            opacity: 0.24,
                            enabled: settings.botanicalDecorations,
                            child: _searchQuery.isNotEmpty
                                ? GlobalSearchPage(
                                    key: const ValueKey('global_search'),
                                    query: _searchQuery,
                                    onOpenSection: (section) {
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _navigation.goTo(section);
                                    },
                                  )
                                : switch (currentSection) {
                                    LunoraSection.home => LunoraDashboard(
                                      onNavigate: openPage,
                                      onCreatePlannerNote: _createPlannerNote,
                                      onCreateDiaryEntry: _createDiaryEntry,
                                      onCreateShoppingItem: _createShoppingItem,
                                      onCreateRecipe: _createRecipe,
                                      onOpenShopping: _openShoppingSection,
                                      onOpenDebts: _openDebtSection,
                                    ),
                                    LunoraSection.settings =>
                                      const SettingsPage(),
                                    LunoraSection.notifications =>
                                      const NotificationsPage(),
                                    LunoraSection.diary => const DiaryPage(),
                                    LunoraSection.diaryGallery =>
                                      const DiaryGalleryPage(),
                                    LunoraSection.books => const BooksPage(),
                                    LunoraSection.movies => const MoviesPage(),
                                    LunoraSection.recipes =>
                                      const RecipesPage(),
                                    LunoraSection.wishlist =>
                                      const WishlistPage(),
                                    LunoraSection.shoppingList =>
                                      const ShoppingPage(),
                                    _ => LunoraSectionPage(
                                      entry: menuEntries[currentIndex],
                                      onNavigate: openPage,
                                      financeInitialTabIndex:
                                          _financeInitialTabIndex,
                                      plannerOpenNewNoteOnStart:
                                          _openPlannerNoteOnSection,
                                    ),
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
