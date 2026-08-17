import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dados de uma exceção de calendário (dia bloqueado total ou parcialmente).
class _DadosExcecao {
  const _DadosExcecao({
    required this.diaInteiro,
    this.horaInicio,
    this.horaFim,
    this.observacao,
  });

  final bool diaInteiro;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFim;
  final String? observacao;

  factory _DadosExcecao.diaInteiro({String? observacao}) =>
      _DadosExcecao(diaInteiro: true, observacao: observacao);

  factory _DadosExcecao.parcial({
    required TimeOfDay horaInicio,
    required TimeOfDay horaFim,
    String? observacao,
  }) =>
      _DadosExcecao(
        diaInteiro: false,
        horaInicio: horaInicio,
        horaFim: horaFim,
        observacao: observacao,
      );
}

class AlterarDisponibilidadePage extends StatefulWidget {
  const AlterarDisponibilidadePage({super.key});

  @override
  State<AlterarDisponibilidadePage> createState() =>
      _AlterarDisponibilidadePageState();
}

class _AlterarDisponibilidadePageState
    extends State<AlterarDisponibilidadePage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _cardBlueBg = Color(0xFFE8F7FF);
  static const Color _dayInactiveBg = Color(0xFFF0F0F0);
  static const Color _timeFieldBg = Color(0xFFF5F5F5);
  static const Color _blockedRed = Color(0xFF9B2335);
  static const Color _blockedBg = Color(0xFFFFF0F3);
  static const Color _blockedBorder = Color(0xFFCE4257);

  static const List<String> _letrasDias = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  // Nomes por extenso na mesma ordem dos índices (0=Domingo ... 6=Sábado)
  static const List<String> _nomesDias = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];

  static const List<String> _meses = [
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

  final SupabaseClient _supabase = Supabase.instance.client;

  // Índice: 0=Domingo, 1=Segunda, 2=Terça, 3=Quarta, 4=Quinta, 5=Sexta, 6=Sábado
  final Set<int> _diasSemanaAtivos = {};
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 18, minute: 0);

  DateTime _mesExibido = DateTime(DateTime.now().year, DateTime.now().month);
  int? _diaSelecionado;
  final Set<int> _diasBloqueados = {};

  // Exceções locais (chave YYYY-MM-DD).
  final Map<String, _DadosExcecao> _excecoesLocal = {};
  // Espelho das exceções persistidas no banco.
  final Map<String, _DadosExcecao> _excecoesBanco = {};
  // Meses ("YYYY-MM") já carregados na sessão para preservar edições locais.
  final Set<String> _mesesExcecoesCarregados = {};

  final Set<int> _diasComEventos = {};

  bool _salvando = false;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDisponibilidade();
  }

  String _formatarHorario(TimeOfDay time) {
    final hora = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuto = time.minute.toString().padLeft(2, '0');
    final periodo = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hora.toString().padLeft(2, '0')}:$minuto $periodo';
  }

  Future<int?> _buscarIdUsuario(String authId) async {
    final response = await _supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (response == null) return null;
    final id = response['id_usuario'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<int?> _buscarIdProfissional() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) return null;

      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      if (dadosProf == null) return null;

      return (dadosProf['id_profissional'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Erro ao buscar id_profissional: $e');
      return null;
    }
  }

  /// Carrega os dias e horários já salvos na agenda_profissional e as
  /// exceções de calendário (grade_horario_excecao) do mês exibido.
  Future<void> _carregarDisponibilidade() async {
    setState(() => _carregando = true);

    try {
      final idProfissional = await _buscarIdProfissional();
      if (idProfissional == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // Busca o registro único de disponibilidade recorrente (fk_solicitacao = 0)
      final response = await _supabase
          .from('agenda_profissional')
          .select('dias_semana, hora_ini, hora_fim')
          .eq('fk_profissional', idProfissional)
          .eq('fk_solicitacao', 0)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Converte a lista "segunda-feira,quinta-feira,sexta-feira"
        // em índices de dia da semana (0=Domingo ... 6=Sábado).
        final diasAtivos = <int>{};
        final diasRaw = response['dias_semana']?.toString();
        if (diasRaw != null && diasRaw.trim().isNotEmpty) {
          for (final nome in diasRaw.split(',')) {
            final indice = _nomesDias.indexOf(nome.trim().toLowerCase());
            if (indice >= 0) diasAtivos.add(indice);
          }
        }

        final horarioInicioFinal = _parseTimetz(response['hora_ini']);
        final horarioFimFinal = _parseTimetz(response['hora_fim']);

        if (mounted) {
          setState(() {
            _diasSemanaAtivos
              ..clear()
              ..addAll(diasAtivos);
            if (horarioInicioFinal != null) _horaInicio = horarioInicioFinal;
            if (horarioFimFinal != null) _horaFim = horarioFimFinal;
          });
        }
      }

      // Carrega as exceções (dias bloqueados) do mês atualmente exibido.
      await _carregarExcecoes(idProfissional: idProfissional);

      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Carrega as exceções do mês exibido da grade_horario_excecao.
  ///
  /// A coluna `dia_semana` é do tipo `date` (formato "YYYY-MM-DD"). As datas
  /// encontradas são convertidas em dias do mês para destacar no calendário.
  Future<void> _carregarExcecoes({int? idProfissional}) async {
    try {
      final id = idProfissional ?? await _buscarIdProfissional();
      if (id == null) return;

      final ano = _mesExibido.year;
      final mes = _mesExibido.month;
      final chaveMes = '$ano-${mes.toString().padLeft(2, '0')}';

      final primeiroDia = DateTime(ano, mes, 1);
      final ultimoDia = DateTime(ano, mes + 1, 0);

      final response = await _supabase
          .from('grade_horario_excecao')
          .select('dia_semana, hora_ini, hora_fim, observacao')
          .eq('fk_profissional', id)
          .gte('dia_semana', _formatarDataCompleta(primeiroDia))
          .lte('dia_semana', _formatarDataCompleta(ultimoDia));

      if (!mounted) return;

      setState(() {
        final primeiroCarregamento = _mesesExcecoesCarregados.add(chaveMes);

        for (final row in response) {
          final dataExcecao = _parseDataExcecao(row['dia_semana']);
          if (dataExcecao == null) continue;
          final chave = _formatarDataCompleta(dataExcecao);
          final dados = _parseDadosExcecao(row);
          _excecoesBanco[chave] = dados;
          if (primeiroCarregamento) {
            _excecoesLocal[chave] = dados;
          }
        }

        if (ano == _mesExibido.year && mes == _mesExibido.month) {
          _sincronizarDiasBloqueadosVisiveis();
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar exceções de calendário: $e');
    }
  }

  /// Converte uma string timetz (ex: "08:00:00-03") em TimeOfDay.
  TimeOfDay? _parseTimetz(Object? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  /// Converte um TimeOfDay em string timetz (ex: "08:00:00-03:00").
  String _formatarTimetz(TimeOfDay time) {
    final offset = DateTime.now().timeZoneOffset;
    final sinal = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final offsetHh = abs.inHours.toString().padLeft(2, '0');
    final offsetMm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00$sinal$offsetHh:$offsetMm';
  }

  /// Converte um valor `time` (ex: "08:00:00") em TimeOfDay.
  TimeOfDay? _parseTime(Object? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  /// Monta [_DadosExcecao] a partir de uma linha da grade_horario_excecao.
  _DadosExcecao _parseDadosExcecao(Map<String, dynamic> row) {
    final horaIni = _parseTime(row['hora_ini']);
    final horaFim = _parseTime(row['hora_fim']);
    final observacao = row['observacao']?.toString();
    if (horaIni != null && horaFim != null) {
      return _DadosExcecao.parcial(
        horaInicio: horaIni,
        horaFim: horaFim,
        observacao: observacao,
      );
    }
    return _DadosExcecao.diaInteiro(observacao: observacao);
  }

  /// Converte [_DadosExcecao] em mapa para insert/update no Supabase.
  Map<String, dynamic> _excecaoParaSupabase(
    String data,
    _DadosExcecao excecao,
    int idProfissional,
  ) {
    final observacao = excecao.observacao?.trim();
    final map = <String, dynamic>{
      'dia_semana': data,
      'fk_profissional': idProfissional,
      'observacao': (observacao != null && observacao.isNotEmpty)
          ? observacao
          : (excecao.diaInteiro ? 'Indisponível' : 'Ausência parcial'),
    };
    if (!excecao.diaInteiro &&
        excecao.horaInicio != null &&
        excecao.horaFim != null) {
      map['hora_ini'] = _formatarTime(excecao.horaInicio!);
      map['hora_fim'] = _formatarTime(excecao.horaFim!);
    }
    return map;
  }

  /// Converte um TimeOfDay em string time (ex: "08:00:00") para a coluna
  /// `time` da grade_horario_excecao.
  String _formatarTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  /// Converte a coluna `date` (formato "YYYY-MM-DD") em DateTime.
  DateTime? _parseDataExcecao(Object? raw) {
    if (raw == null) return null;
    final texto = raw.toString().trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
    if (match == null) return DateTime.tryParse(texto);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Formata um DateTime como "YYYY-MM-DD", formato usado na coluna `date`.
  String _formatarDataCompleta(DateTime data) {
    final mm = data.month.toString().padLeft(2, '0');
    final dd = data.day.toString().padLeft(2, '0');
    return '${data.year}-$mm-$dd';
  }

  /// Formata o dia informado do mês exibido como "YYYY-MM-DD".
  String _formatarDataExcecao(int dia) {
    return _formatarDataCompleta(
      DateTime(_mesExibido.year, _mesExibido.month, dia),
    );
  }

  /// Reconstrói os dias destacados no calendário com base nas datas locais
  /// bloqueadas que pertencem ao mês exibido.
  void _sincronizarDiasBloqueadosVisiveis() {
    final prefixo =
        '${_mesExibido.year}-${_mesExibido.month.toString().padLeft(2, '0')}-';
    _diasBloqueados
      ..clear()
      ..addAll(
        _excecoesLocal.keys
            .where((data) => data.startsWith(prefixo))
            .map((data) => int.tryParse(data.substring(8)))
            .whereType<int>(),
      );
  }

  Future<void> _selecionarHorario({required bool inicio}) async {
    final horario = await showTimePicker(
      context: context,
      initialTime: inicio ? _horaInicio : _horaFim,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _blue),
          ),
          child: child!,
        );
      },
    );

    if (horario == null || !mounted) return;

    setState(() {
      if (inicio) {
        _horaInicio = horario;
      } else {
        _horaFim = horario;
      }
    });
  }

  void _alternarDiaSemana(int indice) {
    setState(() {
      if (_diasSemanaAtivos.contains(indice)) {
        _diasSemanaAtivos.remove(indice);
      } else {
        _diasSemanaAtivos.add(indice);
      }
    });
  }

  Future<void> _mesAnterior() async {
    setState(() {
      _mesExibido = DateTime(_mesExibido.year, _mesExibido.month - 1);
      _diaSelecionado = null;
    });
    _sincronizarDiasBloqueadosVisiveis();
    await _carregarExcecoes();
  }

  Future<void> _proximoMes() async {
    setState(() {
      _mesExibido = DateTime(_mesExibido.year, _mesExibido.month + 1);
      _diaSelecionado = null;
    });
    _sincronizarDiasBloqueadosVisiveis();
    await _carregarExcecoes();
  }

  void _selecionarDiaCalendario(int dia) {
    setState(() => _diaSelecionado = dia);
    _abrirBottomSheetExcecao(dia);
  }

  Future<void> _persistirExcecao(String data, _DadosExcecao excecao) async {
    final idProfissional = await _buscarIdProfissional();
    if (idProfissional == null) return;

    await _supabase
        .from('grade_horario_excecao')
        .delete()
        .eq('fk_profissional', idProfissional)
        .eq('dia_semana', data);

    await _supabase.from('grade_horario_excecao').insert(
          _excecaoParaSupabase(data, excecao, idProfissional),
        );
  }

  Future<void> _removerExcecao(String data) async {
    final idProfissional = await _buscarIdProfissional();
    if (idProfissional == null) return;

    await _supabase
        .from('grade_horario_excecao')
        .delete()
        .eq('fk_profissional', idProfissional)
        .eq('dia_semana', data);
  }

  Future<void> _confirmarExcecao(int dia, _DadosExcecao excecao) async {
    final data = _formatarDataExcecao(dia);

    try {
      await _persistirExcecao(data, excecao);

      if (!mounted) return;

      setState(() {
        _excecoesLocal[data] = excecao;
        _excecoesBanco[data] = excecao;
        _diasComEventos.remove(dia);
        _diaSelecionado = dia;
        _sincronizarDiasBloqueadosVisiveis();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exceção salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar exceção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar exceção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirBottomSheetExcecao(int dia) {
    final data = _formatarDataExcecao(dia);
    final excecaoExistente = _excecoesLocal[data];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GerenciarExcecaoBottomSheet(
        dataFormatada: _nomeDiaPorNumero(dia),
        excecaoExistente: excecaoExistente,
        onConfirmar: (excecao) async {
          Navigator.pop(context);
          await _confirmarExcecao(dia, excecao);
        },
        onCancelar: () => Navigator.pop(context),
        onRetirar: excecaoExistente != null
            ? () async {
                Navigator.pop(context);
                await _restaurarDiaSelecionado(dia);
              }
            : null,
      ),
    );
  }

  Future<void> _restaurarDiaSelecionado([int? dia]) async {
    final diaAlvo = dia ?? _diaSelecionado;
    if (diaAlvo == null) return;

    final data = _formatarDataExcecao(diaAlvo);

    try {
      await _removerExcecao(data);

      if (!mounted) return;

      setState(() {
        _excecoesLocal.remove(data);
        _excecoesBanco.remove(data);
        _sincronizarDiasBloqueadosVisiveis();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exceção removida.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao remover exceção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover exceção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _salvarDisponibilidade() async {
    if (_diasSemanaAtivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos 1 dia da semana.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final idProfissional = await _buscarIdProfissional();
      if (idProfissional == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível identificar seu perfil profissional.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _salvando = false);
        return;
      }

      // Dias escolhidos em texto, ex: "segunda-feira,terça-feira,sexta-feira"
      final diasOrdenados = _diasSemanaAtivos.toList()..sort();
      final diasTexto =
          diasOrdenados.map((indice) => _nomesDias[indice]).join(',');

      // Deleta os registros antigos de disponibilidade recorrente deste
      // profissional para que não fiquem dias/horários acumulados de saves antigos.
      await _supabase
          .from('agenda_profissional')
          .delete()
          .eq('fk_profissional', idProfissional)
          .eq('fk_solicitacao', 0);

      // Salva um único registro com todos os dias da semana e o horário
      // padrão de início/fim (fk_solicitacao = 0 = disponibilidade recorrente).
      await _supabase.from('agenda_profissional').insert({
        'dias_semana': diasTexto,
        'hora_ini': _formatarTimetz(_horaInicio),
        'hora_fim': _formatarTimetz(_horaFim),
        'fk_profissional': idProfissional,
        'fk_status': 1,
        'fk_solicitacao': 0,
      });

      // Exceções são salvas imediatamente pelo Bottom Sheet.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disponibilidade salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar disponibilidade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar disponibilidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _nomeDiaPorNumero(int dia) {
    return '$dia de ${_meses[_mesExibido.month - 1]}';
  }

  String _descricaoExcecao(_DadosExcecao excecao) {
    if (excecao.diaInteiro) return 'Bloqueado (Indisponível)';
    final ini = _formatarHorario(excecao.horaInicio!);
    final fim = _formatarHorario(excecao.horaFim!);
    return 'Ausente das $ini às $fim';
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _blue, size: 20),
          ),
          const Expanded(
            child: Text(
              'Ajustar Disponibilidade',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIntroducao() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilidade',
            style: TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Configure seus dias e horários de trabalho padrão, ou ajuste dias específicos no calendário abaixo.',
            style: TextStyle(
              color: _textGray,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icone,
    required String titulo,
    required Widget conteudo,
    String? descricao,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _cardBlueBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: _blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (descricao != null) ...[
            const SizedBox(height: 10),
            Text(
              descricao,
              style: const TextStyle(
                color: _textGray,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          conteudo,
        ],
      ),
    );
  }

  Widget _buildSeletorDiasSemana() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dias da semana',
          style: TextStyle(color: _textGray, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final ativo = _diasSemanaAtivos.contains(index);
            return GestureDetector(
              onTap: () => _alternarDiaSemana(index),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ativo ? _blue : _dayInactiveBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _letrasDias[index],
                  style: TextStyle(
                    color: ativo ? Colors.white : _textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCampoHorario({
    required String rotulo,
    required String valor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: _timeFieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: _textGray.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    valor,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -8,
              left: 12,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  rotulo,
                  style: const TextStyle(
                    color: _textGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorarioAtendimento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Horário de atendimento',
          style: TextStyle(color: _textGray, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCampoHorario(
              rotulo: 'De',
              valor: _formatarHorario(_horaInicio),
              onTap: () => _selecionarHorario(inicio: true),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '—',
                style: TextStyle(color: _textGray, fontSize: 16),
              ),
            ),
            _buildCampoHorario(
              rotulo: 'Até',
              valor: _formatarHorario(_horaFim),
              onTap: () => _selecionarHorario(inicio: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardRecorrente() {
    return _buildCard(
      icone: Icons.update_rounded,
      titulo: 'Disponibilidade Recorrente',
      conteudo: Column(
        children: [
          _buildSeletorDiasSemana(),
          const SizedBox(height: 20),
          _buildHorarioAtendimento(),
        ],
      ),
    );
  }

  Widget _buildNavegacaoMes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _mesAnterior,
          child: Icon(Icons.chevron_left, color: _textGray.withValues(alpha: 0.7), size: 22),
        ),
        const SizedBox(width: 8),
        Text(
          '${_meses[_mesExibido.month - 1]} ${_mesExibido.year}',
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _proximoMes,
          child: Icon(Icons.chevron_right, color: _textGray.withValues(alpha: 0.7), size: 22),
        ),
      ],
    );
  }

  Widget _buildCelulaDia({
    required int? dia,
    required bool mesAtual,
  }) {
    if (dia == null) {
      return const SizedBox(height: 40);
    }

    final isSelecionado = mesAtual && _diaSelecionado == dia;
    final isBloqueado = mesAtual && _diasBloqueados.contains(dia);
    final temEvento = mesAtual && _diasComEventos.contains(dia);

    final hoje = DateTime.now();
    final isHoje = mesAtual &&
        dia == hoje.day &&
        _mesExibido.year == hoje.year &&
        _mesExibido.month == hoje.month;

    Color? bgColor;
    Color textColor = _textDark;
    Border? border;
    TextDecoration? decoration;

    if (!mesAtual) {
      textColor = _textGray.withValues(alpha: 0.45);
    } else if (isBloqueado) {
      bgColor = _blockedBg;
      textColor = _blockedRed;
      border = Border.all(color: _blockedBorder, width: 1.5);
      decoration = TextDecoration.underline;
    } else if (isHoje) {
      bgColor = _blue;
      textColor = Colors.white;
    } else if (isSelecionado) {
      bgColor = _blue;
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: mesAtual ? () => _selecionarDiaCalendario(dia) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: border,
            ),
            child: Text(
              '$dia',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                decoration: decoration,
                decorationColor: _blockedRed,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isBloqueado
                  ? _blockedRed
                  : (isSelecionado || temEvento)
                      ? (isSelecionado ? Colors.white : _blue)
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendario() {
    final primeiroDia = DateTime(_mesExibido.year, _mesExibido.month, 1);
    final ultimoDia = DateTime(_mesExibido.year, _mesExibido.month + 1, 0);
    final diaInicioSemana = primeiroDia.weekday % 7;
    final totalCelulas = ((diaInicioSemana + ultimoDia.day) / 7).ceil() * 7;

    final mesAnterior = DateTime(_mesExibido.year, _mesExibido.month, 0);
    final diasMesAnterior = mesAnterior.day;

    return Column(
      children: [
        _buildNavegacaoMes(),
        const SizedBox(height: 14),
        Row(
          children: _letrasDias
              .map(
                (letra) => Expanded(
                  child: Text(
                    letra,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textGray.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.85,
          ),
          itemCount: totalCelulas,
          itemBuilder: (context, index) {
            final diaNumero = index - diaInicioSemana + 1;
            final isMesAtual = diaNumero >= 1 && diaNumero <= ultimoDia.day;

            int? diaExibido;
            bool mesAtual = false;

            if (isMesAtual) {
              diaExibido = diaNumero;
              mesAtual = true;
            } else if (index < diaInicioSemana) {
              diaExibido = diasMesAnterior - diaInicioSemana + index + 1;
              mesAtual = false;
            } else {
              diaExibido = diaNumero - ultimoDia.day;
              mesAtual = false;
            }

            return _buildCelulaDia(dia: diaExibido, mesAtual: mesAtual);
          },
        ),
      ],
    );
  }

  Widget _buildListaExcecoes() {
    final prefixo =
        '${_mesExibido.year}-${_mesExibido.month.toString().padLeft(2, '0')}-';
    final excecoesMes = _excecoesLocal.entries
        .where((e) => e.key.startsWith(prefixo))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (excecoesMes.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardBlueBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Nenhuma exceção neste mês.',
          style: TextStyle(color: _textGray, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Exceções do mês',
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ...excecoesMes.map((entry) {
          final dia = int.tryParse(entry.key.substring(8)) ?? 0;
          final excecao = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDAD6).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: _blockedRed, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dia de ${_meses[_mesExibido.month - 1]}',
                  style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _descricaoExcecao(excecao),
                  style: const TextStyle(
                    color: _blockedRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (excecao.observacao != null &&
                    excecao.observacao!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    excecao.observacao!,
                    style: const TextStyle(
                      color: _textGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCardExcecoes() {
    return _buildCard(
      icone: Icons.edit_calendar_outlined,
      titulo: 'Exceções e Férias',
      descricao:
          'Selecione dias no calendário para bloquear ou alterar horários específicos.',
      conteudo: Column(
        children: [
          _buildCalendario(),
          _buildListaExcecoes(),
        ],
      ),
    );
  }

  Widget _buildBotaoSalvar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _salvando ? null : _salvarDisponibilidade,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            disabledBackgroundColor: _blue.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Salvar Disponibilidade',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: _blue),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildIntroducao(),
                          _buildCardRecorrente(),
                          const SizedBox(height: 16),
                          _buildCardExcecoes(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),
            _buildBotaoSalvar(),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet para confirmar exceção de calendário (dia inteiro ou parcial).
class _GerenciarExcecaoBottomSheet extends StatefulWidget {
  const _GerenciarExcecaoBottomSheet({
    required this.dataFormatada,
    required this.excecaoExistente,
    required this.onConfirmar,
    required this.onCancelar,
    this.onRetirar,
  });

  final String dataFormatada;
  final _DadosExcecao? excecaoExistente;
  final Future<void> Function(_DadosExcecao excecao) onConfirmar;
  final VoidCallback onCancelar;
  final VoidCallback? onRetirar;

  @override
  State<_GerenciarExcecaoBottomSheet> createState() =>
      _GerenciarExcecaoBottomSheetState();
}

class _GerenciarExcecaoBottomSheetState
    extends State<_GerenciarExcecaoBottomSheet> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _cardBlueBg = Color(0xFFE8F7FF);
  static const Color _navy = Color(0xFF001A40);
  static const Color _cancelRed = Color(0xFFFF0202);
  static const Color _timeFieldBg = Color(0xFFF5F5F5);
  static const Color _toggleOff = Color(0xFFE0E0E0);

  late bool _diaInteiro;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFim;
  late final TextEditingController _observacaoController;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    final existente = widget.excecaoExistente;
    _observacaoController = TextEditingController(
      text: existente?.observacao ?? '',
    );
    if (existente != null && !existente.diaInteiro) {
      _diaInteiro = false;
      _horaInicio = existente.horaInicio ?? const TimeOfDay(hour: 13, minute: 0);
      _horaFim = existente.horaFim ?? const TimeOfDay(hour: 17, minute: 0);
    } else {
      _diaInteiro = true;
      _horaInicio = const TimeOfDay(hour: 13, minute: 0);
      _horaFim = const TimeOfDay(hour: 17, minute: 0);
    }
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  String _formatarHorario(TimeOfDay time) {
    final hora = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuto = time.minute.toString().padLeft(2, '0');
    final periodo = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hora.toString().padLeft(2, '0')}:$minuto $periodo';
  }

  void _alternarDiaInteiro(bool valor) {
    setState(() {
      _diaInteiro = valor;
    });
  }

  void _alternarHorarioEspecifico(bool valor) {
    setState(() {
      _diaInteiro = !valor;
    });
  }

  Future<void> _selecionarHorario({required bool inicio}) async {
    if (_diaInteiro) return;

    final horario = await showTimePicker(
      context: context,
      initialTime: inicio ? _horaInicio : _horaFim,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _blue),
          ),
          child: child!,
        );
      },
    );

    if (horario == null || !mounted) return;

    setState(() {
      if (inicio) {
        _horaInicio = horario;
      } else {
        _horaFim = horario;
      }
    });
  }

  Future<void> _confirmar() async {
    if (!_diaInteiro) {
      final inicioMinutos = _horaInicio.hour * 60 + _horaInicio.minute;
      final fimMinutos = _horaFim.hour * 60 + _horaFim.minute;
      if (fimMinutos <= inicioMinutos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O horário de fim deve ser posterior ao de início.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _confirmando = true);

    final excecao = _diaInteiro
        ? _DadosExcecao.diaInteiro(
            observacao: _observacaoController.text,
          )
        : _DadosExcecao.parcial(
            horaInicio: _horaInicio,
            horaFim: _horaFim,
            observacao: _observacaoController.text,
          );

    await widget.onConfirmar(excecao);
  }

  Widget _buildToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? activeColor : _toggleOff,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpcao({
    required String titulo,
    required String descricao,
    required bool ativo,
    required bool toggleValue,
    required ValueChanged<bool> onToggle,
  }) {
    final tituloCor = ativo ? _textDark : _textGray.withValues(alpha: 0.6);
    final descCor = ativo ? _textGray : _textGray.withValues(alpha: 0.45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: tituloCor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descricao,
                style: TextStyle(
                  color: descCor,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildToggle(
          value: toggleValue,
          onChanged: onToggle,
          activeColor: _blue,
        ),
      ],
    );
  }

  Widget _buildCampoHorario({
    required String rotulo,
    required String valor,
    required bool habilitado,
    required VoidCallback onTap,
  }) {
    final corTexto =
        habilitado ? _textDark : _textGray.withValues(alpha: 0.45);
    final corRotulo =
        habilitado ? _textGray : _textGray.withValues(alpha: 0.35);
    final corBorda = habilitado
        ? _textGray.withValues(alpha: 0.25)
        : _textGray.withValues(alpha: 0.15);

    return Expanded(
      child: GestureDetector(
        onTap: habilitado ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: TextStyle(
                color: corRotulo,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: habilitado ? Colors.white : _timeFieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: corBorda),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valor,
                      style: TextStyle(
                        color: corTexto,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.access_time,
                    color: corRotulo,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horarioEspecificoAtivo = !_diaInteiro;
    final isEdicao = widget.excecaoExistente != null;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textGray.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Gerenciar Exceção',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _confirmando ? null : widget.onCancelar,
                      icon: Icon(
                        Icons.close,
                        color: _textGray.withValues(alpha: 0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _cardBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: _navy, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Data selecionada: ${widget.dataFormatada}',
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildOpcao(
                  titulo: 'Indisponibilidade total do dia',
                  descricao: 'Bloquear todos os agendamentos para esta data.',
                  ativo: _diaInteiro,
                  toggleValue: _diaInteiro,
                  onToggle: _alternarDiaInteiro,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    height: 1,
                    color: _textGray.withValues(alpha: 0.2),
                  ),
                ),
                _buildOpcao(
                  titulo: 'Definir horário específico de ausência',
                  descricao: 'Bloquear apenas um período do dia.',
                  ativo: horarioEspecificoAtivo,
                  toggleValue: horarioEspecificoAtivo,
                  onToggle: _alternarHorarioEspecifico,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildCampoHorario(
                      rotulo: 'Início',
                      valor: _formatarHorario(_horaInicio),
                      habilitado: horarioEspecificoAtivo,
                      onTap: () => _selecionarHorario(inicio: true),
                    ),
                    const SizedBox(width: 12),
                    _buildCampoHorario(
                      rotulo: 'Fim',
                      valor: _formatarHorario(_horaFim),
                      habilitado: horarioEspecificoAtivo,
                      onTap: () => _selecionarHorario(inicio: false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observacaoController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Observação (opcional)',
                    hintText: 'Ex.: Férias, consulta médica, etc.',
                    labelStyle: const TextStyle(
                      color: _textGray,
                      fontSize: 13,
                    ),
                    hintStyle: TextStyle(
                      color: _textGray.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: _timeFieldBg,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _blue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _confirmando ? null : _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: _blue.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _confirmando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEdicao ? 'Editar Exceção' : 'Confirmar Exceção',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                if (isEdicao && widget.onRetirar != null) ...[
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _confirmando ? null : widget.onRetirar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cancelRed,
                        side: const BorderSide(color: _cancelRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Retirar Exceção',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _confirmando ? null : widget.onCancelar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cancelRed,
                        side: const BorderSide(color: _cancelRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}