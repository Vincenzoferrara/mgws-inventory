import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/extensions.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../reuse_class/datagridview/datagridview_list.gui.dart';
import '../reuse_class/image_url_resolver.dart';
import '../theme/theme.dart';
import 'class_user_global.dart';

/// Elenco degli utenti del sito WordPress del negozio: personale e clienti.
///
/// E' una [DataGridListView] sui campi di [UserGlobal]: ricerca, ruolo e
/// ordinamento per nome, email o data vanno al server (`/wp/v2/users`). La
/// pagina e' in sola lettura: i permessi si cambiano dal dipendente MGWS
/// collegato all'utente, nella sezione Dipendenti.
class UtentiGestisciPage extends StatelessWidget {
  const UtentiGestisciPage({super.key});

  Future<PaginatedResult<UserGlobal>> _caricaPagina(
    DataGridPageRequest request,
  ) {
    final ruoli = request.filterOn('ruoli');
    final sort = request.sort;
    final sortField = sort == null
        ? null
        : DataGridFilterEngine.fieldByName(
            UserGlobal.gridFields,
            sort.fieldName,
          );
    return PlatformManager.utenti.getUtentiPaginati(
      page: request.page,
      perPage: request.perPage,
      search: request.search,
      roles: ruoli?.valori,
      orderBy: sortField?.serverSortParam ?? 'registered_date',
      ascending: sort?.ascending ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DataGridListView<UserGlobal>(
      fields: UserGlobal.gridFields,
      idOf: (utente) => '${utente.id ?? 0}',
      loadPage: _caricaPagina,
      cacheKey: 'utenti',
      defaultColumns: const [
        'username',
        'nome',
        'email',
        'ruoli',
        'dataRegistrazione',
      ],
      defaultMobileColumns: const ['username', 'ruoli'],
      cellsOf: (context, utente) => <String, Widget>{
        'username': Text(
          utente.username ?? '-',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        'dataRegistrazione': Text(
          utente.registeredDate == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(utente.registeredDate!),
        ),
      },
      emptyDetailsIcon: Icons.manage_accounts_outlined,
      emptyDetailsTitle: (context) => context.l10n.usersSelectUser,
      detailsOf: (context, utente, inPage) => inPage
          ? Scaffold(
              appBar: AppBar(title: Text(utente.username ?? '')),
              body: _UtenteDettagli(utente: utente),
            )
          : _UtenteDettagli(utente: utente),
    );
  }
}

class _UtenteDettagli extends StatelessWidget {
  final UserGlobal utente;

  const _UtenteDettagli({required this.utente});

  String _ruolo(BuildContext context, String slug) {
    for (final option in UserGlobal.ruoliNoti) {
      if (option.value == slug) return option.label(context.l10n);
    }
    return slug;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = resolveImageUrl(utente.avatarUrl);
    final permessi =
        (utente.capabilities ?? const <String, dynamic>{}).entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList()
          ..sort();
    final nome = (utente.name ?? '').trim();

    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
              foregroundImage: avatar == null ? null : NetworkImage(avatar),
              child: Icon(Icons.person, size: 40, color: theme.primaryColor),
            ),
          ),
          SizedBox(height: context.spacing.l),
          Center(
            child: Text(
              nome.isNotEmpty ? nome : (utente.username ?? 'N/D'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              utente.email ?? 'N/D',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ),
          Divider(height: context.spacing.xxl),
          _Sezione(
            titolo: context.l10n.usersProfile,
            icona: Icons.person,
            children: [
              _InfoRow(
                context.l10n.usersFieldUsername,
                utente.username ?? 'N/D',
              ),
              _InfoRow(context.l10n.usersFieldName, nome.isEmpty ? 'N/D' : nome),
              _InfoRow(context.l10n.usersFieldEmail, utente.email ?? 'N/D'),
              _InfoRow(
                context.l10n.usersFieldRegistered,
                utente.registeredDate == null
                    ? 'N/D'
                    : DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(utente.registeredDate!.toLocal()),
              ),
            ],
          ),
          SizedBox(height: context.spacing.l),
          _Sezione(
            titolo: context.l10n.usersFieldRoles,
            icona: Icons.badge_outlined,
            children: [
              Wrap(
                spacing: context.spacing.s,
                runSpacing: context.spacing.s,
                children: [
                  for (final ruolo in utente.roles ?? const <String>[])
                    Chip(label: Text(_ruolo(context, ruolo))),
                ],
              ),
            ],
          ),
          SizedBox(height: context.spacing.l),
          _Sezione(
            titolo: context.l10n.usersCapabilities,
            icona: Icons.lock_outline,
            children: [
              Text(
                context.l10n.usersPermissionsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.subtitleColor,
                ),
              ),
              SizedBox(height: context.spacing.s),
              Wrap(
                spacing: context.spacing.xs,
                runSpacing: context.spacing.xs,
                children: [
                  for (final permesso in permessi)
                    Chip(
                      label: Text(permesso),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sezione extends StatelessWidget {
  final String titolo;
  final IconData icona;
  final List<Widget> children;

  const _Sezione({
    required this.titolo,
    required this.icona,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: context.spacing.iM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, size: 20, color: Theme.of(context).primaryColor),
                SizedBox(width: context.spacing.s),
                Text(
                  titolo,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: context.spacing.m),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
