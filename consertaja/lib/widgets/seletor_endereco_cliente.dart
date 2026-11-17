import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../meus_enderecos.dart';

/// Um endereço do cliente (ass_usuario_endereco + enderecos).
class EnderecoCliente {
  const EnderecoCliente({
    required this.id,
    required this.rua,
    required this.bairroCidade,
    this.apelido,
    this.latitude,
    this.longitude,
    this.ativo = false,
  });

  final int id;
  final String rua;
  final String bairroCidade;
  final String? apelido;
  final double? latitude;
  final double? longitude;
  final bool ativo;

  String get titulo =>
      bairroCidade.isNotEmpty ? bairroCidade : (rua.isNotEmpty ? rua : '—');
}

/// Carrega e lembra (no aparelho) o endereço escolhido pelo cliente. A
/// escolha vale para a home e para a busca.
class EnderecosCliente {
  EnderecosCliente._();

  static const _chave = 'endereco_cliente_escolhido';

  static Future<List<EnderecoCliente>> carregar() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) return const [];
    try {
      final u = await db
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      final idUsuario = (u?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return const [];
      final ass = await db
          .from('ass_usuario_endereco')
          .select('fk_endereco, apelido_endereco, endereco_ativo')
          .eq('fk_usuario', idUsuario);
      if (ass.isEmpty) return const [];
      final ids = [for (final a in ass) (a['fk_endereco'] as num).toInt()];
      final ends = await db
          .from('enderecos')
          .select(
            'id_endereco, logradouro, numero, bairro, fk_cidade, latitude, longitude',
          )
          .inFilter('id_endereco', ids);
      final idsCidade = {
        for (final e in ends)
          if (e['fk_cidade'] != null) (e['fk_cidade'] as num).toInt(),
      };
      final cidades = <int, String>{};
      if (idsCidade.isNotEmpty) {
        final cs = await db
            .from('cidades')
            .select('id_cidade, nome_cidade')
            .inFilter('id_cidade', idsCidade.toList());
        for (final c in cs) {
          cidades[(c['id_cidade'] as num).toInt()] =
              c['nome_cidade']?.toString() ?? '';
        }
      }
      final porId = {
        for (final e in ends) (e['id_endereco'] as num).toInt(): e,
      };
      final lista = <EnderecoCliente>[];
      for (final a in ass) {
        final e = porId[(a['fk_endereco'] as num).toInt()];
        if (e == null) continue;
        String t(Object? v) => (v ?? '').toString().trim();
        final rua = [
          t(e['logradouro']),
          t(e['numero']),
        ].where((x) => x.isNotEmpty).join(', ');
        final cidade = e['fk_cidade'] == null
            ? ''
            : cidades[(e['fk_cidade'] as num).toInt()] ?? '';
        lista.add(
          EnderecoCliente(
            id: (e['id_endereco'] as num).toInt(),
            rua: rua,
            bairroCidade: [
              t(e['bairro']),
              cidade,
            ].where((x) => x.isNotEmpty).join(', '),
            apelido: t(a['apelido_endereco']).isEmpty
                ? null
                : t(a['apelido_endereco']),
            latitude: (e['latitude'] as num?)?.toDouble(),
            longitude: (e['longitude'] as num?)?.toDouble(),
            ativo: a['endereco_ativo'] == true,
          ),
        );
      }
      return lista;
    } catch (e) {
      debugPrint('[enderecos cliente] $e');
      return const [];
    }
  }

  /// O endereço ATIVO (banco); sem ativo, o último escolhido no aparelho;
  /// senão o primeiro.
  static Future<EnderecoCliente?> escolhido(List<EnderecoCliente> lista) async {
    if (lista.isEmpty) return null;
    for (final e in lista) {
      if (e.ativo) return e;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_chave);
      for (final e in lista) {
        if (e.id == id) return e;
      }
    } catch (_) {}
    return lista.first;
  }

  /// Torna [e] o endereço ATIVO do cliente (ass_usuario_endereco).
  static Future<void> escolher(EnderecoCliente e) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_chave, e.id);
    } catch (_) {}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) return;
    try {
      final u = await db
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      final idUsuario = (u?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return;
      await db
          .from('ass_usuario_endereco')
          .update({'endereco_ativo': false})
          .eq('fk_usuario', idUsuario)
          .neq('fk_endereco', e.id);
      await db
          .from('ass_usuario_endereco')
          .update({'endereco_ativo': true})
          .eq('fk_usuario', idUsuario)
          .eq('fk_endereco', e.id);
    } catch (err) {
      debugPrint('[enderecos cliente] ativar: $err');
    }
  }
}

/// "📍 Mooca, São Paulo  Trocar ▾": toque abre um menu com os endereços.
class SeletorEnderecoCliente extends StatefulWidget {
  const SeletorEnderecoCliente({
    super.key,
    this.cor = Colors.white,
    this.corIcone,
    this.corTrocar,
    this.mostrarTrocar = true,
    this.aoMudar,
    this.aoTocarSemPermissao,
  });

  final Color cor;
  final Color? corIcone;
  final Color? corTrocar;
  final bool mostrarTrocar;
  final ValueChanged<EnderecoCliente>? aoMudar;

  /// Visitante: em vez de abrir o menu, chama isto.
  final VoidCallback? aoTocarSemPermissao;

  @override
  State<SeletorEnderecoCliente> createState() => _SeletorEnderecoClienteState();
}

class _SeletorEnderecoClienteState extends State<SeletorEnderecoCliente> {
  List<EnderecoCliente> _lista = const [];
  EnderecoCliente? _atual;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.aoTocarSemPermissao != null) {
      setState(() => _carregando = false);
      return;
    }
    final lista = await EnderecosCliente.carregar();
    final atual = await EnderecosCliente.escolhido(lista);
    if (!mounted) return;
    setState(() {
      _lista = lista;
      _atual = atual;
      _carregando = false;
    });
  }

  Future<void> _abrirMenu() async {
    if (widget.aoTocarSemPermissao != null) {
      widget.aoTocarSemPermissao!();
      return;
    }
    if (_lista.isEmpty) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MeusEnderecosPage()));
      if (!mounted) return;
      setState(() => _carregando = true);
      await _carregar();
      final atual = _atual;
      if (atual != null) widget.aoMudar?.call(atual);
      return;
    }
    final caixa = context.findRenderObject() as RenderBox;
    final pos = caixa.localToGlobal(Offset(0, caixa.size.height + 4));
    final escolhido = await showMenu<EnderecoCliente>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (final e in _lista)
          PopupMenuItem(
            value: e,
            child: Row(
              children: [
                Icon(
                  e.id == _atual?.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: const Color(0xFF0FB3FF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.apelido ?? e.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        e.rua,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (escolhido == null || !mounted) return;
    await EnderecosCliente.escolher(escolhido);
    setState(() => _atual = escolhido);
    widget.aoMudar?.call(escolhido);
  }

  @override
  Widget build(BuildContext context) {
    final texto = _carregando
        ? 'Carregando…'
        : _atual?.titulo ??
              (widget.aoTocarSemPermissao != null
                  ? 'Entre para ver seu endereço'
                  : 'Adicionar endereço');
    return InkWell(
      onTap: _carregando ? null : _abrirMenu,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            color: widget.corIcone ?? widget.cor,
            size: 18,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.cor,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // "Trocar" só quando há endereço para trocar.
          if (widget.mostrarTrocar && _lista.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              'Trocar',
              style: TextStyle(
                color: widget.corTrocar ?? widget.cor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: widget.corTrocar ?? widget.cor,
              ),
            ),
          ],
          if (_lista.isNotEmpty || widget.aoTocarSemPermissao != null)
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: widget.corTrocar ?? widget.cor,
              size: 18,
            )
          else
            Icon(
              Icons.add_circle_outline_rounded,
              color: widget.corTrocar ?? widget.cor,
              size: 16,
            ),
        ],
      ),
    );
  }
}
