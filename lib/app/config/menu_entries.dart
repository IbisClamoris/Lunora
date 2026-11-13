import 'package:flutter/material.dart';

class MenuEntry {
  final String title;
  final IconData icon;
  final String description;

  const MenuEntry(this.title, this.icon, this.description);
}

const List<MenuEntry> menuEntries = [
  MenuEntry(
    'Главная',
    Icons.home_outlined,
    'Твои миры, твой ритм. Всё важное собрано в одном месте.',
  ),
  MenuEntry(
    'Календарь',
    Icons.calendar_month_outlined,
    'Общий календарь личных дел, учёбы и важных событий.',
  ),
  MenuEntry(
    'Уведомления',
    Icons.notifications_none,
    'Напоминания о важных событиях и сроках.',
  ),
  MenuEntry(
    'Список покупок',
    Icons.shopping_basket_outlined,
    'Единый список покупок для всех твоих планов.',
  ),
  MenuEntry(
    'Мой планер',
    Icons.event_note_outlined,
    'Личные планы, дела и цели.',
  ),
  MenuEntry(
    'Учебный планер',
    Icons.school_outlined,
    'Учебные материалы, задания и расписание.',
  ),
  MenuEntry(
    'Мои финансы',
    Icons.account_balance_wallet_outlined,
    'Доходы, расходы, кредиты и финансовые цели.',
  ),
  MenuEntry(
    'Моя база знаний',
    Icons.auto_stories_outlined,
    'Твоя личная библиотека знаний и материалов.',
  ),
  MenuEntry(
    'Дневник',
    Icons.edit_note_outlined,
    'Личные записи, мысли и воспоминания.',
  ),
  MenuEntry(
    'Галерея дневника',
    Icons.photo_library_outlined,
    'Фотографии из твоих дневниковых записей и воспоминаний.',
  ),
  MenuEntry(
    'Мой книжный мир',
    Icons.menu_book_outlined,
    'Книги, читательский дневник и личная библиотека.',
  ),
  MenuEntry(
    'Мир кино и сериалов',
    Icons.movie_outlined,
    'Фильмы, сериалы и список просмотра.',
  ),
  MenuEntry(
    'Моя книга рецептов',
    Icons.restaurant_menu_outlined,
    'Рецепты, меню и кулинарные заметки.',
  ),
  MenuEntry(
    'Вишлист',
    Icons.auto_awesome_outlined,
    'Желания, покупки мечты и планы на будущее.',
  ),
  MenuEntry(
    'Настройки',
    Icons.settings_outlined,
    'Внешний вид, уведомления, данные и поведение Lunora.',
  ),
];
