import 'package:flutter/foundation.dart';

enum LunoraSection {
  home,
  calendar,
  notifications,
  shoppingList,
  planner,
  studyPlanner,
  finances,
  knowledgeBase,
  diary,
  diaryGallery,
  books,
  movies,
  recipes,
  wishlist,
  settings,
}

class LunoraNavigation extends ChangeNotifier {
  LunoraSection _currentSection = LunoraSection.home;

  LunoraSection get currentSection => _currentSection;

  void goTo(LunoraSection section) {
    if (_currentSection == section) return;

    _currentSection = section;
    notifyListeners();
  }

  void goHome() {
    goTo(LunoraSection.home);
  }
}
