import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfil_profissional.dart';
import 'tela_home.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/iniciais.dart';

class SeguindoClientePage extends StatefulWidget {
  final bool isVisitante;

  const SeguindoClientePage({super.key, this.isVisitante = false});

  @override
  State<SeguindoClientePage> createState() => _SeguindoClientePageState();
}

class _SeguindoClientePageState extends State<SeguindoClientePage> {
  static const _blue = Color(0xFF0A6E9D);
  static const _background = Color(0xFFFAFAFA);
  final _supabase = Supabase.instance.client;
  final _buscaController = TextEditingController();

  late Future<List<_ProfissionalSeguido>> _profissionaisFuture;
  bool _buscaAtiva = false;
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _profissionaisFuture = _carregarProfissionais();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<List<_ProfissionalSeguido>> _carregarProfissionais() async {
    if (widget.isVisitante) return [];
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return [];

    final usuario = await _supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authUser.id)
        .maybeSingle();
    final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
    if (idUsuario == null) return [];

    final vinculos = await _supabase
        .from('seguidores_profissional')
        .select('fk_perfil')
        .eq('fk_usuario', idUsuario);
    final idsPerfil = vinculos
        .map((row) => (row['fk_perfil'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    if (idsPerfil.isEmpty) return [];

    final dados = await _supabase
        .from('dados_profissionais')
        .select('fk_perfil, id_profissional, fk_usuario')
        .inFilter('fk_perfil', idsPerfil);
    final idsUsuario = dados
        .map((row) => (row['fk_usuario'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final usuarios = idsUsuario.isEmpty
        ? <dynamic>[]
        : await _supabase
              .from('usuarios')
              .select('id_usuario, nome, foto_perfil_url')
              .inFilter('id_usuario', idsUsuario);

    final profissionalPorPerfil = <int, Map<String, dynamic>>{
      for (final row in dados)
        if ((row['fk_perfil'] as num?) != null)
          (row['fk_perfil'] as num).toInt(): Map<String, dynamic>.from(row),
    };
    final usuarioPorId = <int, Map<String, dynamic>>{
      for (final row in usuarios)
        if ((row['id_usuario'] as num?) != null)
          (row['id_usuario'] as num).toInt(): Map<String, dynamic>.from(row),
    };

    final profissionais = <_ProfissionalSeguido>[];
    for (final idPerfil in idsPerfil) {
      final profissional = profissionalPorPerfil[idPerfil];
      final idDoUsuario = (profissional?['fk_usuario'] as num?)?.toInt();
      final usuarioDoProfissional = idDoUsuario == null
          ? null
          : usuarioPorId[idDoUsuario];
      if (usuarioDoProfissional == null) continue;

      final oficios = await _supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', profissional?['id_profissional']);
      final idsOficio = oficios
          .map((row) => (row['fk_oficio'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      final nomesOficios = idsOficio.isEmpty
          ? <String>[]
          : (await _supabase
                    .from('oficios')
                    .select('funcao')
                    .inFilter('id_oficio', idsOficio))
                .map((row) => row['funcao']?.toString() ?? '')
                .where((nome) => nome.isNotEmpty)
                .take(2)
                .toList();

      profissionais.add(
        _ProfissionalSeguido(
          idPerfil: idPerfil,
          nome: usuarioDoProfissional['nome']?.toString() ?? 'Profissional',
          fotoUrl: usuarioDoProfissional['foto_perfil_url']?.toString() ?? '',
          oficios: nomesOficios,
        ),
      );
    }
    return profissionais;
  }

  PageRouteBuilder _rotaSemAnimacao(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _navegar(int index) {
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(TelaHome(isVisitante: widget.isVisitante)),
      );
    } else if (index == 4) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9E9F0),
        elevation: 0,
        title: _buscaAtiva
            ? TextField(
                controller: _buscaController,
                autofocus: true,
                onChanged: (valor) => setState(() => _termoBusca = valor),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar profissional',
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Seguindo',
                style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _buscaAtiva ? 'Fechar pesquisa' : 'Pesquisar',
            icon: Icon(_buscaAtiva ? Icons.close : Icons.search, color: _blue),
            onPressed: () {
              setState(() {
                _buscaAtiva = !_buscaAtiva;
                if (!_buscaAtiva) {
                  _termoBusca = '';
                  _buscaController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<_ProfissionalSeguido>>(
        future: _profissionaisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os profissionais.'),
            );
          }
          final termo = _termoBusca.trim().toLowerCase();
          final profissionais = (snapshot.data ?? [])
              .where(
                (profissional) =>
                    termo.isEmpty ||
                    profissional.nome.toLowerCase().contains(termo) ||
                    profissional.oficios.any(
                      (oficio) => oficio.toLowerCase().contains(termo),
                    ),
              )
              .toList();
          if (profissionais.isEmpty) {
            return const Center(child: Text('Nenhum profissional encontrado.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
            itemCount: profissionais.length,
            separatorBuilder: (_, _) => const SizedBox(height: 13),
            itemBuilder: (context, index) => _buildCard(profissionais[index]),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBarCliente(
        currentIndex: 1,
        onTap: _navegar,
      ),
    );
  }

  Widget _buildCard(_ProfissionalSeguido profissional) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PerfilProfissionalPage(
              nomeInicial: profissional.nome,
              imagemInicial: profissional.fotoUrl,
              profissao: profissional.oficios.isNotEmpty
                  ? profissional.oficios.first
                  : 'Profissional independente',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(profissional),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profissional.nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Text(
                        '★ 4.9',
                        style: TextStyle(color: _blue, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (
                        var index = 0;
                        index < profissional.oficios.length;
                        index++
                      )
                        _buildTag(profissional.oficios[index], index == 0),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'A conversa estará disponível em breve.',
                              ),
                            ),
                          ),
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('Conversar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF12AEF0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
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

  Widget _buildTag(String text, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF52636B) : const Color(0xFFE4E4E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary ? Colors.white : const Color(0xFF44444A),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAvatar(_ProfissionalSeguido profissional) {
    if (profissional.fotoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 27,
        backgroundImage: NetworkImage(profissional.fotoUrl),
      );
    }
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFE6EFF2),
      child: Text(
        obterIniciais(profissional.nome),
        style: const TextStyle(color: _blue, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ProfissionalSeguido {
  final int idPerfil;
  final String nome;
  final String fotoUrl;
  final List<String> oficios;

  const _ProfissionalSeguido({
    required this.idPerfil,
    required this.nome,
    required this.fotoUrl,
    required this.oficios,
  });
}
