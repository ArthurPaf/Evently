import 'package:flutter/material.dart';

/// Keeps forms readable on desktop and preserves all available space on phones.
class EventlyScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final double maxWidth;
  const EventlyScaffold({
    super.key,
    this.appBar,
    this.body,
    this.drawer,
    this.floatingActionButton,
    this.maxWidth = 1180,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    drawer: drawer,
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      top: appBar == null,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox.expand(child: body),
        ),
      ),
    ),
  );
}

class EventlyAuthLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String description;
  const EventlyAuthLayout({
    super.key,
    required this.child,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      final form = Container(
        margin: EdgeInsets.all(wide ? 32 : 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: child,
      );
      if (!wide) return form;
      return Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 24, 0, 24),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF36166D),
                    Color(0xFF7138C9),
                    Color(0xFF995BE5),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFE2CAFF),
                        size: 52,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'EVENTLY',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFFE8DCFA),
                          fontSize: 17,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _AuthChip(Icons.event_outlined, 'Eventos'),
                          _AuthChip(Icons.storefront_outlined, 'Barracas'),
                          _AuthChip(Icons.qr_code_rounded, 'Conexões'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: form),
        ],
      );
    },
  );
}

class _AuthChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AuthChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}
