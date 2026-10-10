import 'package:flutter/material.dart';

import '../models/evento_model.dart';

/// The same roomy, responsive cards used by the organizer dashboard.
class EventlyPanelGrid extends StatelessWidget {
  final String title;
  final String subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
  final Future<void> Function()? onRefresh;

  const EventlyPanelGrid({
    super.key,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.icon = Icons.event_note_rounded,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 24),
              if (itemCount == 0)
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(icon, size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          emptyTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(emptyMessage, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                    itemCount,
                    (index) => SizedBox(
                      width:
                          (constraints.maxWidth - 40 - (columns - 1) * 16) /
                          columns,
                      child: itemBuilder(context, index),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    return onRefresh == null
        ? content
        : RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}

class EventlyPanelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> details;
  final String actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onOptions;
  final String? status;

  const EventlyPanelCard({
    super.key,
    required this.icon,
    required this.title,
    required this.details,
    required this.actionLabel,
    required this.onTap,
    this.onOptions,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onOptions,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      status ?? '',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onOptions != null)
                    IconButton(
                      tooltip: 'Opções do evento',
                      onPressed: onOptions,
                      icon: const Icon(Icons.more_horiz),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(title, style: theme.textTheme.titleLarge),
              for (final detail in details) ...[
                const SizedBox(height: 8),
                Text(detail, style: TextStyle(color: colors.onSurfaceVariant)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventlyEventsPanel extends StatelessWidget {
  final List<Evento> eventos;
  final String title;
  final String description;
  final String actionLabel;
  final ValueChanged<Evento> onOpen;
  final ValueChanged<Evento>? onOptions;
  final Future<void> Function() onRefresh;

  const EventlyEventsPanel({
    super.key,
    required this.eventos,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onOpen,
    required this.onRefresh,
    this.onOptions,
  });

  String _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return EventlyPanelGrid(
      title: title,
      subtitle: description,
      itemCount: eventos.length,
      emptyTitle: 'Nenhum evento por aqui',
      emptyMessage: 'Você ainda não foi vinculado a nenhum evento.',
      onRefresh: onRefresh,
      itemBuilder: (context, index) {
        final evento = eventos[index];
        return EventlyPanelCard(
          icon: Icons.event_available_outlined,
          title: evento.nome,
          status: evento.encerrado ? 'Encerrado' : 'Ativo',
          details: [
            '${_date(evento.dataInicio)} até ${_date(evento.dataFim)}',
            evento.local.isEmpty ? 'Sem local definido' : evento.local,
          ],
          actionLabel: actionLabel,
          onTap: () => onOpen(evento),
          onOptions: onOptions == null ? null : () => onOptions!(evento),
        );
      },
    );
  }
}
