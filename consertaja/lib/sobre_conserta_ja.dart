import 'package:flutter/material.dart';
import 'widgets/documento_markdown.dart';

class SobreConsertaJaPage extends StatelessWidget {
  const SobreConsertaJaPage({super.key});

  static const Color _textDark = Color(0xFF1A1A1A);

  static const String _conteudo = '''
# Sobre o Conserta Já

O **Conserta Já** é uma plataforma criada para aproximar clientes de profissionais especializados em serviços de manutenção, reparo e conserto.

Nosso objetivo é dar **mais visibilidade a profissionais que muitas vezes atuam de forma independente e possuem pouca presença no mercado digital**, facilitando o encontro entre quem precisa de um serviço e quem sabe realizá-lo.

Na plataforma, o cliente pode **encontrar profissionais próximos, visualizar seus perfis, consultar avaliações, solicitar serviços, conversar pelo chat, acompanhar o atendimento e realizar pagamentos** de forma integrada.

Para os profissionais, o Conserta Já oferece uma maneira simples de **divulgar seus serviços, apresentar seu portfólio, receber solicitações e conquistar novos clientes**.

A plataforma também conta com recursos de **geolocalização, avaliação de serviços, verificação de profissionais e histórico de atendimentos**, buscando proporcionar uma experiência mais prática e segura para todos os envolvidos.

O Conserta Já foi pensado especialmente para valorizar profissões tradicionais e aproximá-las das novas tecnologias, contribuindo para a **inclusão digital e a geração de novas oportunidades de trabalho**.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: _textDark),
        ),
        title: const Text(
          'Sobre o Conserta Já',
          style: TextStyle(
            color: _textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/Logo.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              DocumentoMarkdown(data: _conteudo),
            ],
          ),
        ),
      ),
    );
  }
}
