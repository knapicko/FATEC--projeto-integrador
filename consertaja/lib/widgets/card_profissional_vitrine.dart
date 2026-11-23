import 'package:flutter/material.dart';

import '../perfil_loja.dart';
import '../perfil_profissional.dart';
import '../tela_chat_profissional.dart';
import '../utils/cor_oficio.dart';
import '../utils/iniciais.dart';
import 'avisos_bottom_sheet.dart';
import 'tag_oficio.dart';
import 'imagem_app.dart';

/// Profissional independente ou loja, como aparece nos cards da home e de
/// "Todos os profissionais".
class ProfissionalVitrine {
  const ProfissionalVitrine({
    required this.ehEmpresa,
    required this.nome,
    this.idProfissional,
    this.idGrupoEmpresa,
    this.foto,
    this.nota,
    this.totalAvaliacoes = 0,
    this.funcoes = const [],
    this.disponivelHoje = false,
    this.criadoEm,
    this.tagEmpresa,
    this.corTagEmpresa,
    this.distanciaKm,
  });

  final bool ehEmpresa;
  final String nome;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final String? foto;
  final double? nota;
  final int totalAvaliacoes;
  final List<OficioInfo> funcoes;
  final bool disponivelHoje;
  final DateTime? criadoEm;

  /// Tag da loja (grupo_empresa) quando é loja, funcionário de uma loja ou
  /// dono de CNPJ com perfil "Loja".
  final String? tagEmpresa;
  final String? corTagEmpresa;
  final double? distanciaKm;

  /// Conta criada há menos de 3 dias.
  bool get novo =>
      criadoEm != null && DateTime.now().difference(criadoEm!).inDays < 3;

  String? get tagFormatada {
    final t = tagEmpresa?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.startsWith('#') ? t.toUpperCase() : '#${t.toUpperCase()}';
  }

  String get chave => ehEmpresa ? 'e$idGrupoEmpresa' : 'p$idProfissional';
}

void abrirPerfilVitrine(BuildContext context, ProfissionalVitrine p) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => p.ehEmpresa
          ? PerfilLoja(
              idGrupoEmpresa: p.idGrupoEmpresa,
              nomeEmpresa: p.nome,
              fotoUrlEmpresa: p.foto,
              tagEmpresa: p.tagEmpresa,
              corTagEmpresa: p.corTagEmpresa,
            )
          : PerfilProfissionalPage(
              nomeInicial: p.nome,
              imagemInicial: p.foto ?? '',
              profissao: p.funcoes.isNotEmpty
                  ? p.funcoes.first.funcao
                  : 'Profissional independente',
              avaliacao: p.nota,
              totalAvaliacoes: p.totalAvaliacoes,
              idProfissional: p.idProfissional,
            ),
    ),
  );
}

void conversarComVitrine(BuildContext context, ProfissionalVitrine p) {
  if (!SessaoVisitante.permitir(context)) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaChatProfissional(
        nomeProfissional: p.nome,
        fotoProfissional: p.foto ?? '',
        oficioPrincipal: p.funcoes.isNotEmpty ? p.funcoes.first.funcao : '',
        idProfissional: p.ehEmpresa ? null : p.idProfissional,
        idGrupoEmpresa: p.ehEmpresa ? p.idGrupoEmpresa : null,
      ),
    ),
  );
}

/// Card: foto + nome; abaixo do nome a avaliação (sem avaliação = 5.0),
/// "Novo" (conta com menos de 3 dias) e a tag da loja; distância e
/// disponibilidade de hoje; funções; Conversar + perfil.
class CardProfissionalVitrine extends StatelessWidget {
  const CardProfissionalVitrine({
    super.key,
    required this.p,
    this.largura = 300,
  });

  final ProfissionalVitrine p;
  final double? largura;

  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF0F172A);
  static const _sec = Color(0xFF64748B);

  Widget _iniciais() => CorOriginal(interface: true, child: Container(
    color: _azul,
    alignment: Alignment.center,
    child: Text(
      obterIniciais(p.nome),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
  ));

  Widget _pill(Widget filho, Color fundo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(8),
    ),
    child: filho,
  );

  @override
  Widget build(BuildContext context) {
    final foto = p.foto ?? '';
    final km = p.distanciaKm;
    final distancia = km == null
        ? null
        : km < 1
        ? '${(km * 1000).round()} m de você'
        : '${km.toStringAsFixed(1).replaceAll('.', ',')} km de você';
    final tag = p.tagFormatada;
    final corTag = CorOficio.parse(p.corTagEmpresa);

    return Container(
      width: largura,
      height: 236,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => abrirPerfilVitrine(context, p),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: foto.startsWith('http')
                            ? ImagemApp(child: Image.network(
                                foto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _iniciais(),
                              ))
                            : _iniciais(),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.ehEmpresa
                              ? Icons.storefront_rounded
                              : Icons.verified_rounded,
                          color: _azul,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _pill(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    (p.nota ?? 5).toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (p.totalAvaliacoes > 0)
                                    Text(
                                      ' (${p.totalAvaliacoes})',
                                      style: const TextStyle(
                                        color: _sec,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const Color(0xFFFFF7E0),
                            ),
                            if (p.novo) ...[
                              const SizedBox(width: 6),
                              _pill(
                                const Text(
                                  'Novo',
                                  style: TextStyle(
                                    color: Color(0xFF0369A1),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const Color(0xFFE0F2FE),
                              ),
                            ],
                            if (tag != null) ...[
                              const SizedBox(width: 6),
                              _pill(
                                Text(
                                  tag,
                                  style: TextStyle(
                                    color: CorOficio.corTextoContraste(corTag),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                                corTag,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  distancia == null
                      ? (p.ehEmpresa
                            ? Icons.storefront_outlined
                            : Icons.person_outline_rounded)
                      : Icons.near_me_outlined,
                  color: _azul,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    distancia ?? (p.ehEmpresa ? 'Loja' : 'Independente'),
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  p.disponivelHoje ? 'Disponível hoje' : 'Não disponível',
                  style: TextStyle(
                    color: p.disponivelHoje
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 26,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.funcoes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => TagOficio(
                oficio: p.funcoes[i],
                fontSize: 11.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
            ),
          ),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFEDEFF2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: CorOriginal(interface: true, child: FilledButton(
                    onPressed: () => conversarComVitrine(context, p),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Conversar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFE8EDF3),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => abrirPerfilVitrine(context, p),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.badge_outlined, color: Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
