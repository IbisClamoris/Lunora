import 'package:flutter/material.dart';

/// Единая точка показа диалогов Lunora:
/// мягкое затемнение фона, одинаковое во всех разделах.
Future<T?> showLunoraDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color.fromRGBO(35, 29, 34, 0.30),
    builder: builder,
  );
}
