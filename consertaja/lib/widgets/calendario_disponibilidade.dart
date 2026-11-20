import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calendário do mês com os dias em que o profissional/empresa atende
/// (agenda_profissional) e as exceções (grade_horario_excecao).
/// Verde = atende; vermelho = folga/exceção; cinza = não atende.
class CalendarioDisponibilidade extends StatefulWidget {
  const CalendarioDisponibilidade({
    super.key,
    this.idProfissional,
    this.idGrupoEmpresa,
  });

  final int? idProfissional;
  final int? idGrupoEmpresa;

  @override
  State<CalendarioDisponibilidade> createState() =>
      _CalendarioDisponibilidadeState();
}

class _CalendarioDisponibilidadeState extends State<CalendarioDisponibilidade> {
  static const _azul = Color(0xFF0FB3FF);
  static const _verde = Color(0xFF16A34A);
  static const _vermelho = Color(0xFFDC2626);
  static const _texto = Color(0xFF0F172A);
  static const _sec = Color(0xFF64748B);

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  /// weekday (1 = seg ... 7 = dom) -> "08:00 - 18:00"
  final Map<int, String> _horario = {};

  /// "aaaa-mm-dd" -> observação da exceção
  final Map<String, String> _excecoes = {};

  /// Exceção parcial: "aaaa-mm-dd" -> "14:00 - 16:00" (não atende só nesse
  /// intervalo).
  final Map<String, String> _parciais = {};
  bool _carregado = false;
  DateTime? _selecionado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  int? _diaDaSemana(String d) {
    final t = d.trim().toLowerCase().replaceAll('ç', 'c').replaceAll('á', 'a');
    if (t.startsWith('seg')) return 1;
    if (t.startsWith('ter')) return 2;
    if (t.startsWith('qua')) return 3;
    if (t.startsWith('qui')) return 4;
    if (t.startsWith('sex')) return 5;
    if (t.startsWith('sab')) return 6;
    if (t.startsWith('dom')) return 7;
    return null;
  }

  String _chave(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _carregar() async {
    final db = Supabase.instance.client;
    try {
      var q = db
          .from('agenda_profissional')
          .select('dias_semana, hora_ini, hora_fim')
          .eq('fk_solicitacao', 0);
      q = widget.idGrupoEmpresa != null
          ? q.eq('fk_grupo_empresa', widget.idGrupoEmpresa!)
          : q.eq('fk_profissional', widget.idProfissional ?? -1);
      final linhas = await q;
      _horario.clear();
      for (final r in linhas) {
        final ini = (r['hora_ini']?.toString() ?? '')
            .padRight(5)
            .substring(0, 5);
        final fim = (r['hora_fim']?.toString() ?? '')
            .padRight(5)
            .substring(0, 5);
        for (final d in (r['dias_semana']?.toString() ?? '').split(',')) {
          final w = _diaDaSemana(d);
          if (w != null) _horario[w] = '${ini.trim()} - ${fim.trim()}';
        }
      }
    } catch (e) {
      debugPrint('[calendário] agenda: $e');
    }
    try {
      final inicio = DateTime(_mes.year, _mes.month, 1);
      final fim = DateTime(_mes.year, _mes.month + 1, 0);
      var q = db
          .from('grade_horario_excecao')
          .select('dia_semana, observacao, hora_ini, hora_fim')
          .gte('dia_semana', _chave(inicio))
          .lte('dia_semana', _chave(fim));
      q = widget.idGrupoEmpresa != null
          ? q.eq('fk_grupo_empresa', widget.idGrupoEmpresa!)
          : q.eq('fk_profissional', widget.idProfissional ?? -1);
      final ex = await q;
      _excecoes.clear();
      _parciais.clear();
      String hhmm(Object? v) {
        final t = v?.toString() ?? '';
        return t.length >= 5 ? t.substring(0, 5) : t;
      }

      for (final e in ex) {
        final d = DateTime.tryParse(e['dia_semana']?.toString() ?? '');
        final ini = hhmm(e['hora_ini']);
        final fim = hhmm(e['hora_fim']);
        if (d != null && ini.isNotEmpty && fim.isNotEmpty) {
          _parciais[_chave(d)] = '$ini - $fim';
        }
        if (d != null) {
          _excecoes[_chave(
            d,
          )] = e['observacao']?.toString().trim().isNotEmpty == true
              ? e['observacao'].toString().trim()
              : 'Indisponível';
        }
      }
    } catch (e) {
      debugPrint('[calendário] exceções: $e');
    }
    if (mounted) setState(() => _carregado = true);
  }

  void _mudarMes(int passo) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + passo);
      _selecionado = null;
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final primeiro = DateTime(_mes.year, _mes.month, 1);
    final dias = DateTime(_mes.year, _mes.month + 1, 0).day;
    final vazios = primeiro.weekday % 7; // domingo primeiro
    final hoje = DateTime.now();
    final sel = _selecionado;
    String? infoSel;
    if (sel != null) {
      infoSel =
          _excecoes[_chave(sel)] ??
          (_horario[sel.weekday] != null
              ? 'Atende das ${_horario[sel.weekday]}'
              : 'Não atende neste dia');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_outlined, color: _azul),
              SizedBox(width: 8),
              Text(
                'Disponibilidade',
                style: TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _mudarMes(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${_meses[_mes.month - 1]} ${_mes.year}',
                style: const TextStyle(
                  color: _texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _mudarMes(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: _sec,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!_carregado)
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: vazios + dias,
              itemBuilder: (_, i) {
                if (i < vazios) return const SizedBox.shrink();
                final dia = DateTime(_mes.year, _mes.month, i - vazios + 1);
                final passado = dia.isBefore(
                  DateTime(hoje.year, hoje.month, hoje.day),
                );
                final parcial = _parciais.containsKey(_chave(dia));
                final excecao = _excecoes.containsKey(_chave(dia)) && !parcial;
                final atende = _horario.containsKey(dia.weekday) && !excecao;
                final cor = excecao
                    ? _vermelho
                    : parcial
                    ? _laranja
                    : atende
                    ? _verde
                    : const Color(0xFFCBD5E1);
                final ehSel = sel != null && _chave(sel) == _chave(dia);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selecionado = dia);
                    _mostrarDia(dia);
                  },
                  child: Opacity(
                    opacity: passado ? 0.4 : 1,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ehSel ? cor : cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${dia.day}',
                        style: TextStyle(
                          color: ehSel
                              ? Colors.white
                              : (atende || excecao ? cor : _sec),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          if (infoSel != null)
            Text(
              infoSel,
              style: const TextStyle(
                color: _texto,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 14,
              children: [
                _legenda(_verde, 'Atende'),
                _legenda(_vermelho, 'Folga/indisponível'),
                _legenda(_laranja, 'Parcial'),
                _legenda(const Color(0xFFCBD5E1), 'Não atende'),
              ],
            ),
        ],
      ),
    );
  }

  static const _laranja = Color(0xFFF59E0B);

  static const _semana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  /// Bottom sheet do dia: horário de atendimento, ou o motivo da exceção
  /// (dia inteiro em vermelho; parcial com o intervalo em que não atende).
  void _mostrarDia(DateTime dia) {
    final chave = _chave(dia);
    final parcial = _parciais[chave];
    final motivo = _excecoes[chave];
    final horario = _horario[dia.weekday];
    final (
      Color cor,
      IconData icone,
      String titulo,
      String texto,
    ) = parcial != null
        ? (
            _laranja,
            Icons.schedule_rounded,
            'Indisponível das $parcial',
            '${motivo ?? 'Indisponível'}'
                '${horario != null ? '\nNo restante do dia atende das $horario.' : ''}',
          )
        : motivo != null
        ? (_vermelho, Icons.event_busy_rounded, 'Não atende neste dia', motivo)
        : horario != null
        ? (
            _verde,
            Icons.event_available_rounded,
            'Atende neste dia',
            'Horário de atendimento: $horario',
          )
        : (
            _sec,
            Icons.do_not_disturb_on_outlined,
            'Não atende neste dia',
            'Este dia não está na agenda.',
          );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: cor, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                '${_semana[dia.weekday - 1]}, ${dia.day.toString().padLeft(2, '0')}/${dia.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: _sec,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _sec, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legenda(Color cor, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(texto, style: const TextStyle(color: _sec, fontSize: 12)),
    ],
  );
}
