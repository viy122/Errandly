import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';

/// One accessible input supports full-code paste and normal keyboard editing.
class CompletionPinInput extends StatefulWidget {
  const CompletionPinInput({
    super.key,
    required this.controller,
    this.error,
    this.onChanged,
  });
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  @override
  State<CompletionPinInput> createState() => _CompletionPinInputState();
}

class _CompletionPinInputState extends State<CompletionPinInput> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(update);
    focus.addListener(update);
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CompletionPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(update);
      widget.controller.addListener(update);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(update);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final position = widget.controller.selection.baseOffset.clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter 6-digit completion PIN',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 58,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.error != null
                                ? const Color(0xFFFFF2EF)
                                : canvas,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.error != null
                                  ? const Color(0xFFAE4137)
                                  : focus.hasFocus && i == position
                                  ? teal
                                  : const Color(0xFFD9E4DE),
                              width: focus.hasFocus && i == position ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            i < code.length ? code[i] : '',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: TextField(
                  key: const ValueKey('completion-pin-input'),
                  controller: widget.controller,
                  focusNode: focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableSuggestions: false,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 23,
                  ),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    hintText: 'Six-digit completion PIN',
                    hintStyle: TextStyle(color: Colors.transparent),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            widget.error ?? 'You can type or paste all six digits.',
            key: ValueKey(widget.error),
            style: TextStyle(
              fontSize: 11,
              color: widget.error == null ? muted : const Color(0xFFAE4137),
            ),
          ),
        ),
      ],
    );
  }
}
