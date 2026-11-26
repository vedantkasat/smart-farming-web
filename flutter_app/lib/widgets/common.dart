import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

enum ChipKind { ok, warn, bad, plain, on }

class StatusChip extends StatelessWidget {
  final String text;
  final ChipKind kind;
  final bool mono;
  const StatusChip(this.text, {super.key, this.kind = ChipKind.ok, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      ChipKind.ok => (Furrow.greenSoft, Furrow.ink),
      ChipKind.warn => (Furrow.accentSoft, Furrow.ink),
      ChipKind.bad => (Furrow.errorSoft, Furrow.error),
      ChipKind.plain => (Furrow.paper3, Furrow.ink),
      ChipKind.on => (Furrow.green, Furrow.paper2),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Furrow.radiusPill)),
      child: Text(
        text,
        style: mono ? Furrow.mono(13, color: fg, weight: FontWeight.w500) : Furrow.body(13, color: fg, weight: FontWeight.w500),
      ),
    );
  }
}

/// Plain card on paper with a hairline rule.
class Panel extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool sheet;
  const Panel({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(20), this.sheet = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: sheet ? Furrow.sheet : Furrow.paper2,
        border: sheet ? null : Border.all(color: Furrow.rule),
        borderRadius: BorderRadius.circular(sheet ? 3 : Furrow.radiusCard),
        boxShadow: sheet
            ? [
                BoxShadow(color: Furrow.ink.withValues(alpha: .08), blurRadius: 2, offset: const Offset(0, 1)),
                BoxShadow(color: Furrow.ink.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 14), spreadRadius: -16),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(title!, style: Furrow.display(16).copyWith(letterSpacing: -0.16, height: 1.2))),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// The "field record": ink header strip over a paper body.
class EntryCard extends StatelessWidget {
  final Widget head;
  final Widget? headTrailing;
  final List<Widget> children;
  const EntryCard({super.key, required this.head, this.headTrailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Furrow.paper2,
        borderRadius: BorderRadius.circular(Furrow.radiusEntry),
        border: Border.all(color: Furrow.ink),
        boxShadow: [BoxShadow(color: Furrow.ink.withValues(alpha: .25), blurRadius: 44, offset: const Offset(0, 24), spreadRadius: -20)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Furrow.ink,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: Furrow.display(16, color: Furrow.paper2).copyWith(letterSpacing: -0.16),
                    child: head,
                  ),
                ),
                if (headTrailing != null)
                  DefaultTextStyle(
                    style: Furrow.mono(13, color: Furrow.paper2),
                    child: headTrailing!,
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Label on the left, value on the right, ruled underneath.
class RuledRow extends StatelessWidget {
  final Widget label;
  final Widget value;
  final bool top;
  const RuledRow({super.key, required this.label, required this.value, this.top = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Furrow.ink) : BorderSide.none,
          bottom: const BorderSide(color: Furrow.rule),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: DefaultTextStyle(style: Furrow.body(15), child: label),
          ),
          const SizedBox(width: 12),
          value,
        ],
      ),
    );
  }
}

class Note extends StatelessWidget {
  final String text;
  const Note(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.only(top: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Furrow.rule)),
    ),
    child: Text(text, style: Furrow.body(13.5, color: Furrow.muted)),
  );
}

/// Every pump command needs a confirm step: first tap arms the button for 4 s,
/// the second tap sends the command.
class ConfirmButton extends StatefulWidget {
  final String label;
  final String confirmLabel;
  final bool primary;
  final VoidCallback? onConfirmed;
  const ConfirmButton({super.key, required this.label, required this.confirmLabel, this.primary = false, this.onConfirmed});

  @override
  State<ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<ConfirmButton> {
  bool armed = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _tap() {
    if (armed) {
      _t?.cancel();
      setState(() => armed = false);
      widget.onConfirmed?.call();
    } else {
      setState(() => armed = true);
      _t = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => armed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(armed ? widget.confirmLabel : widget.label);
    final onTap = widget.onConfirmed == null ? null : _tap;
    if (widget.primary || armed) {
      return FilledButton(
        onPressed: onTap,
        style: armed && !widget.primary ? FilledButton.styleFrom(backgroundColor: Furrow.ink, foregroundColor: Furrow.paper2) : null,
        child: text,
      );
    }
    return OutlinedButton(onPressed: onTap, child: text);
  }
}

String fmtTime(int? t) {
  if (t == null || t == 0) return '--:--';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class ScreenHead extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ScreenHead(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(title, style: Furrow.display(28)),
        ?trailing,
      ],
    ),
  );
}

/// 12-column grid behaviour: side by side on wide screens, stacked on phones.
class Columns extends StatelessWidget {
  final List<(int flex, Widget child)> items;
  const Columns(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i].$2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(flex: items[i].$1, child: items[i].$2),
            ],
          ],
        );
      },
    );
  }
}
