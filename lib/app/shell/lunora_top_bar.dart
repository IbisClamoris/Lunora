import 'package:flutter/material.dart';

import '../../core/localization/lunora_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/services/notification_service.dart';

class LunoraTopBar extends StatefulWidget {
  final VoidCallback onNotifications;
  final VoidCallback onHome;
  final ValueChanged<String> onSearchChanged;
  const LunoraTopBar({
    super.key,
    required this.onNotifications,
    required this.onHome,
    required this.onSearchChanged,
  });
  @override
  State<LunoraTopBar> createState() => _LunoraTopBarState();
}

class _LunoraTopBarState extends State<LunoraTopBar> {
  final _controller = TextEditingController();
  void _handleSearch(String value) {
    setState(() {});
    widget.onSearchChanged(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final veryCompact = constraints.maxWidth < 360;
        return Container(
          height: compact ? 62 : 68,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 24),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Text(
                  LunoraLocalization.text('ТВОЁ ПРОСТРАНСТВО', 'YOUR SPACE'),
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
                const Spacer(),
              ],
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: TextField(
                    controller: _controller,
                    onChanged: _handleSearch,
                    style: TextStyle(color: p.text, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: compact
                          ? LunoraLocalization.text('Поиск…', 'Search…')
                          : LunoraLocalization.text('Найти что-нибудь…', 'Search anything…'),
                      prefixIcon: Icon(Icons.search_rounded, color: p.secondary, size: 19),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                widget.onSearchChanged('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded, size: 17),
                            ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      fillColor: p.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: p.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: p.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: p.accent, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              AnimatedBuilder(
                animation: NotificationService.instance,
                builder: (context, _) {
                  return FutureBuilder<int>(
                    future: NotificationService.instance.getUnreadCount(),
                    builder: (context, s) {
                      final count = s.data ?? 0;
                      return _ActionButton(
                        compact: compact,
                        icon: Icons.notifications_none_rounded,
                        badge: count,
                        onTap: widget.onNotifications,
                        tooltip: LunoraLocalization.text('Уведомления', 'Notifications'),
                      );
                    },
                  );
                },
              ),
              SizedBox(width: compact ? 6 : 8),
              _ActionButton(
                compact: compact,
                icon: Icons.home_rounded,
                onTap: widget.onHome,
                tooltip: LunoraLocalization.text('Главная', 'Home'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = 0,
    this.compact = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badge;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.background,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: p.secondary),
                if (badge > 0)
                  Positioned(
                    right: 6,
                    top: 5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 1.5),
                      ),
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
