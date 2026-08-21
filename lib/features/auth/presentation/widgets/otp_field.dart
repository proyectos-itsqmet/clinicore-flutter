import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';

/// The six-digit code input.
///
/// Six boxes, each borrowing [AppChip]'s resting geometry — `surface` fill,
/// a 1.5px `line` border, a 16px radius — and going to a 2px `blue` border
/// when it is the box being filled, which is the same focus treatment the
/// text fields use. The digits are [AppFigure]s, so they are tabular and the
/// row does not shift as it fills.
///
/// ## How it works
///
/// There is exactly ONE text field, invisible, stretched across the row. The
/// boxes are decoration painted from its value. This is the standard approach
/// for a reason: six separate fields means six focus nodes, six controllers,
/// and hand-written logic for backspace, paste and autofill — all of which a
/// single field gets from the platform for free, including the "from
/// Messages" code suggestion above the keyboard on iOS.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;

  /// Fired the moment the last digit lands, so the caller can submit without
  /// making the user reach for a button they no longer need.
  final ValueChanged<String>? onCompleted;

  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final String value = widget.controller.text;
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final String value = widget.controller.text;

    return Stack(
      children: <Widget>[
        Row(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (int i = 0; i < widget.length; i++)
              Expanded(
                child: _OtpBox(
                  digit: i < value.length ? value[i] : null,
                  // The "active" box is the next empty one, and only while
                  // the field actually has focus.
                  active: _focusNode.hasFocus && i == value.length,
                ),
              ),
          ],
        ),

        // The real input: invisible, on top, and the whole row's tap target.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: widget.length,
              showCursor: false,
              enableInteractiveSelection: false,
              autofillHints: const <String>[AutofillHints.oneTimeCode],
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.tone,
      curve: AppMotion.easeBrand,
      // `minHeight`, not `height`: the box has to be able to grow when the OS
      // text size is turned up, or the digit clips inside it.
      constraints: const BoxConstraints(minHeight: 58),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.tileLgAll,
        border: Border.all(
          color: active ? AppColors.blue : AppColors.line,
          width: active ? 2 : 1.5,
        ),
      ),
      child: digit == null
          ? const SizedBox.shrink()
          : AppFigure(value: digit!, size: 22),
    );
  }
}
