import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/lunora_localization.dart';
import '../../core/platform/lunora_tray_service.dart';

class LunoraWindowTitleBar extends StatefulWidget {
  const LunoraWindowTitleBar({super.key});

  @override
  State<LunoraWindowTitleBar> createState() => _LunoraWindowTitleBarState();
}

class _LunoraWindowTitleBarState extends State<LunoraWindowTitleBar> {
  final _windowManager = WindowManager.instance;
  int? _listenerId;
  int? _windowId;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    final window = _windowManager.getCurrent();
    _windowId = window?.id;
    _listenerId = _windowManager.addListener((event) {
      if (!mounted || event.windowId != _windowId) return;
      if (event is WindowMaximizedEvent) {
        setState(() => _maximized = true);
      } else if (event is WindowRestoredEvent) {
        setState(() => _maximized = false);
      }
    });
  }

  @override
  void dispose() {
    final listenerId = _listenerId;
    if (listenerId != null) {
      _windowManager.removeListener(listenerId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    final border = palette.border.withValues(alpha: 0.7);
    final window = _windowManager.getCurrent();
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      size: 16,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Lunora',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                _WindowButton(
                  icon: Icons.remove_rounded,
                  tooltip: LunoraLocalization.text('Свернуть', 'Minimize'),
                  onTap: () => LunoraTrayService.instance.minimizeWindow(),
                ),
                _WindowButton(
                  icon: _maximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
                  tooltip: _maximized
                      ? LunoraLocalization.text('Восстановить', 'Restore')
                      : LunoraLocalization.text('Развернуть', 'Maximize'),
                  onTap: () {
                    if (_maximized) {
                      window?.unmaximize();
                    } else {
                      window?.maximize();
                    }
                  },
                ),
                _WindowButton(
                  icon: Icons.close_rounded,
                  tooltip: LunoraLocalization.text('Закрыть', 'Close'),
                  isClose: true,
                  onTap: () => window?.close(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered
              ? (widget.isClose ? const Color(0xFFE35D6A) : palette.border)
              : palette.surface,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              width: 46,
              height: 38,
              child: Icon(
                widget.icon,
                size: 15,
                color: _hovered && widget.isClose ? Colors.white : palette.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
