import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Carrega os dias e horários já salvos na agenda_profissional.
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

      if (response == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

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
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade: $e');
      if (mounted) setState(() => _carregando = false);
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

  void _mesAnterior() {
    setState(() {
      _mesExibido = DateTime(_mesExibido.year, _mesExibido.month - 1);
      _diaSelecionado = null;
    });
  }

  void _proximoMes() {
    setState(() {
      _mesExibido = DateTime(_mesExibido.year, _mesExibido.month + 1);
      _diaSelecionado = null;
    });
  }

  void _selecionarDiaCalendario(int dia) {
    setState(() => _diaSelecionado = dia);
  }

  void _alternarBloqueioDia(int dia) {
    setState(() {
      if (_diasBloqueados.contains(dia)) {
        _diasBloqueados.remove(dia);
      } else {
        _diasBloqueados.add(dia);
        _diasComEventos.remove(dia);
      }
      _diaSelecionado = dia;
    });
  }

  void _restaurarDiaSelecionado() {
    if (_diaSelecionado == null) return;
    setState(() {
      _diasBloqueados.remove(_diaSelecionado);
    });
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

  String _nomeDiaSelecionado() {
    if (_diaSelecionado == null) return '';
    return '$_diaSelecionado de ${_meses[_mesExibido.month - 1]}';
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
    } else if (isSelecionado) {
      bgColor = _blue;
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: mesAtual ? () => _selecionarDiaCalendario(dia) : null,
      onLongPress: mesAtual ? () => _alternarBloqueioDia(dia) : null,
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

  Widget _buildBannerDiaSelecionado() {
    if (_diaSelecionado == null ||
        !_diasBloqueados.contains(_diaSelecionado)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _blockedBg,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: _blockedRed, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeDiaSelecionado(),
                  style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Bloqueado (Indisponível)',
                  style: TextStyle(
                    color: _blockedRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _restaurarDiaSelecionado,
            style: TextButton.styleFrom(
              foregroundColor: _blockedRed,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Restaurar',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
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
          _buildBannerDiaSelecionado(),
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