import 'package:flutter/material.dart';

import '../area_atuacao.dart';
import '../models/servico_profissional.dart';
import '../services/servicos_profissional_service.dart';
import 'imagem_app.dart';

/// Reativa um serviço DESATIVADO (troca de área de atuação). Se a área do
/// serviço não estiver mais na Área de Atuação da conta, explica e oferece
/// abrir a tela de áreas. Devolve true quando reativou.
Future<bool> reativarServico(
  BuildContext context,
  ServicoProfissional servico,
) async {
  const azul = Color(0xFF0FB3FF);
  final naArea = await ServicosProfissionalService.funcaoNaArea(servico);
  if (!context.mounted) return false;

  if (!naArea) {
    final abrir = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work_off_outlined, color: azul, size: 44),
              const SizedBox(height: 12),
              Text(
                'Adicione "${servico.funcao ?? 'a área'}" de volta',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Este serviço foi desativado porque a área dele saiu da sua '
                'Área de Atuação. Para reativá-lo, adicione a área de novo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: CorOriginal(
                  interface: true,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: azul,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Abrir Áreas de Atuação',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
    if (abrir == true && context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AreaAtuacaoPage()));
      if (!context.mounted) return false;
      // Voltou com a área adicionada: reativa direto.
      if (await ServicosProfissionalService.funcaoNaArea(servico) &&
          context.mounted) {
        return _reativar(context, servico);
      }
    }
    return false;
  }
  return _reativar(context, servico);
}

Future<bool> _reativar(BuildContext context, ServicoProfissional s) async {
  final ok = await ServicosProfissionalService.reativarServico(s.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Serviço reativado: os clientes já podem ver e pedir.'
              : 'Não foi possível reativar o serviço. Tente de novo.',
        ),
      ),
    );
  }
  return ok;
}

/// Faixa "Serviço desativado" com o botão Reativar.
class FaixaServicoDesativado extends StatelessWidget {
  const FaixaServicoDesativado({
    super.key,
    required this.aoReativar,
    this.compacta = false,
  });

  final VoidCallback aoReativar;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    const laranja = Color(0xFFB45309);
    return Container(
      margin: compacta ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: laranja, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compacta
                  ? 'Desativado: os clientes não veem'
                  : 'Serviço desativado: os clientes não veem nem podem pedir.',
              style: const TextStyle(
                color: laranja,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CorOriginal(
            interface: true,
            child: FilledButton(
              onPressed: aoReativar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0FB3FF),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Reativar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
