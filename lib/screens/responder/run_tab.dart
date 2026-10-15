import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'responder_feed.dart';
import 'responder_incident_screen.dart';
import 'responder_shell.dart';

/// RUN — the raised disc (REPLIT (MAIN) 07 · R06–R10): the Area this
/// responder is going to, on scene at, or was stood down from.
///
/// With no run, it says how one starts and sends them to Duty; nothing is
/// shown that is not theirs.
class RunTab extends StatelessWidget {
  const RunTab({super.key, required this.feed, required this.shell});

  final ResponderFeed feed;
  final ResponderShellState shell;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final id = feed.runId;
        if (id == null) {
          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabHeader(eyebrow: feed.unit, title: 'Run'),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    child: EmptyState(
                      icon: AppIcons.fireTruck,
                      tone: context.pal.accentInk,
                      title: 'No run',
                      body:
                          'When you tap I am going on an Area, your run is '
                          'here: the way there, your crew, and what happens '
                          'next.',
                      action: AppButton.secondary(
                        'Open duty',
                        onPressed: () => shell.show(ResponderTab.duty),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ResponderIncidentScreen(
          key: ValueKey(id),
          incidentId: id,
          myId: feed.myId,
          agency: feed.agency,
          orgId: feed.orgId,
          unit: feed.unit,
          api: feed.api,
          tracker: feed.tracker,
          embedded: true,
          onBackToDuty: shell.backToDuty,
        );
      },
    );
  }
}
