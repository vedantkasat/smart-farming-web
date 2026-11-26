import 'package:material_ui/material_ui.dart';

import '../i18n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _kinds = {
  'dry': ('Dry soil', ChipKind.warn),
  'pump': ('Pump', ChipKind.plain),
  'fault': ('Fault', ChipKind.bad),
  'disease': ('Disease', ChipKind.warn),
};

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FarmScope.of(context);
    final small = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      textStyle: Furrow.body(13.5, weight: FontWeight.w500),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHead(
          tr(f.lang, 'alerts'),
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(style: small, onPressed: f.alerts.isEmpty ? null : f.ackAll, child: const Text('Acknowledge all')),
              OutlinedButton(
                style: small,
                onPressed: f.alerts.isEmpty
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Clear all alerts?'),
                            content: const Text('This removes every alert from Firebase for everyone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear all')),
                            ],
                          ),
                        );
                        if (ok == true) f.clearAlerts();
                      },
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        Panel(
          sheet: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.alerts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No alerts. Dry soil, pump changes, sensor faults and disease results show up here.',
                    style: Furrow.body(14, color: Furrow.muted),
                  ),
                ),
              for (final a in f.alerts)
                Opacity(
                  opacity: a.ack ? .55 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Furrow.rule)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusChip(
                              (_kinds[a.type] ?? ('Info', ChipKind.plain)).$1,
                              kind: (_kinds[a.type] ?? ('Info', ChipKind.plain)).$2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: Furrow.body(15, weight: FontWeight.w500)),
                              Text(a.message, style: Furrow.body(13.5, color: Furrow.muted)),
                              Text(fmtTime(a.time), style: Furrow.mono(12.5, color: Furrow.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        a.ack
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('Seen', style: Furrow.body(13, color: Furrow.muted)),
                              )
                            : OutlinedButton(style: small, onPressed: () => f.ack(a), child: const Text('Acknowledge')),
                      ],
                    ),
                  ),
                ),
              const Note(
                "Farmers also get these as SMS and WhatsApp messages. This list mirrors alerts/ in Firebase.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}
