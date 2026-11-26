import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/expert.dart';
import '../data/rules.dart';
import '../i18n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _msgs = <(bool user, String text)>[
    (
      false,
      'Ask about irrigation, the pump, sensor faults or your last leaf check. I only answer from the app\'s own data and never give spray doses.',
    ),
  ];

  void _send() {
    final v = _q.text.trim();
    if (v.isEmpty) return;
    _q.clear();
    _focus.requestFocus(); // keep typing after Enter
    setState(() {
      _msgs.add((true, v));
      _msgs.add((false, answer(FarmScope.of(context), v)));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context);
    final s = f.lastScan;
    final waText = s == null
        ? 'Leaf check'
        : s.accepted
        ? 'Leaf check: ${s.crop}, ${s.disease} (${(s.confidence * 100).toStringAsFixed(0)}% confidence). Please advise.'
        : 'Leaf check was not sure. Please advise.';
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHead(tr(f.lang, 'ask'), trailing: const StatusChip("Answers from this app's own data", kind: ChipKind.plain)),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 320,
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Furrow.ink)),
                    ),
                    child: ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _msgs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final (user, text) = _msgs[i];
                        return Align(
                          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: .8,
                            alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                            child: Align(
                              alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: user ? Furrow.ink : Furrow.paper,
                                  border: user ? null : Border.all(color: Furrow.rule),
                                  borderRadius: BorderRadius.circular(Furrow.radiusCard),
                                ),
                                child: Text(text, style: Furrow.body(15, color: user ? Furrow.paper2 : Furrow.ink)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _q,
                          focusNode: _focus,
                          onSubmitted: (_) => _send(),
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(hintText: 'Why did the pump start?', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _send, child: Text(tr(f.lang, 'send'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Talk to a person',
              child: Column(
                children: [
                  RuledRow(
                    top: true,
                    label: const Text('Kisan Call Centre, free, 6 am to 10 pm'),
                    value: TextButton(
                      onPressed: () => launchUrl(Uri.parse('tel:18001801551')),
                      child: Text(kccNumber, style: Furrow.mono(15)),
                    ),
                  ),
                  RuledRow(
                    label: const Text('Share your last leaf check on WhatsApp'),
                    value: TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(waText)}'), mode: LaunchMode.externalApplication),
                      child: const Text('Open WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
