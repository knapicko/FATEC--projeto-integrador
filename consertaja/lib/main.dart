import 'package:flutter/material.dart';
import 'tela_home.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ConsertaJá',
      theme: ThemeData(
        primaryColor: const Color(0xFF00A3FF), 
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), 
      ),
      home: const TelaEscolhaConta(), 
    );
  }
}


// PASSO 2: A Tela de Escolha de Conta

class TelaEscolhaConta extends StatelessWidget {
  const TelaEscolhaConta({super.key});

  @override
  Widget build(BuildContext context) {
    double alturaDaTela = MediaQuery.of(context).size.height;
    double larguraDaTela = MediaQuery.of(context).size.width;


    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(larguraDaTela * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {}, 
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF00A3FF)),
                  label: const Text('Voltar', style: TextStyle(color: Color(0xFF00A3FF))),
                ),
              ),
              SizedBox(height: alturaDaTela * 0.01),
              
              Image.asset(
                'assets/images/Logo.png',
                height: alturaDaTela * 0.12,
              ),
              SizedBox(height: alturaDaTela * 0.02),
              
              const Text(
                'ConsertaJá',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00A3FF)),
              ),
              const Text(
                'Escolha o seu tipo de conta',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: alturaDaTela * 0.03),

              BotaoSelecaoConta(
                titulo: 'Sou um Cliente',
                subtitulo: 'Procuro profissionais para resolverem meus problemas domésticos',
                corBorda: const Color(0xFF00A3FF),
                caminhoImagem: 'assets/images/Icone - Cliente.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TelaCadastroCliente1()),
                  );
                },
              ),
              SizedBox(height: alturaDaTela * 0.015),

              BotaoSelecaoConta(
                titulo: 'Sou um Profissional',
                subtitulo: 'Ofereço meus serviços e quero receber pedidos de cliente',
                corBorda: Colors.orange,
                caminhoImagem: 'assets/images/Icone - Profissional.png',
                onTap: () {},
              ),
              SizedBox(height: alturaDaTela * 0.015),

              BotaoSelecaoConta(
                titulo: 'Quero Visitar',
                subtitulo: 'Quero conhecer o aplicativo antes de criar uma conta',
                corBorda: Colors.grey,
                caminhoImagem: 'assets/images/Icone - Visitante.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TelaHome(isVisitante: true)),
                  );
                },
              ),
              SizedBox(height: alturaDaTela * 0.02),

              BotaoSelecaoConta(
                  titulo: 'Já possuo uma conta',
                  subtitulo: 'Quero entrar em uma conta criada anteriormente',
                  corBorda: const Color(0xFF053145),
                  caminhoImagem: 'assets/images/Icone - Login - Branco.png',
                  fundoPreenchido: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TelaHome(isVisitante: false)),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// PASSO 3: O Componente Reutilizável do Botão

class BotaoSelecaoConta extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color corBorda;
  final String caminhoImagem;
  final VoidCallback onTap;
  final bool fundoPreenchido;

  const BotaoSelecaoConta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.corBorda,
    required this.caminhoImagem,
    required this.onTap,
    this.fundoPreenchido = false,
  });

  @override
  Widget build(BuildContext context) {

    Color corDoFundo = fundoPreenchido ? corBorda : Colors.white;
    Brightness brilhoDoFundo = ThemeData.estimateBrightnessForColor(corDoFundo);
    Color corDoTextoPrincipal;
    Color corDoTextoSubtitulo;

  if (fundoPreenchido) {
    if (brilhoDoFundo == Brightness.dark) {
      corDoTextoPrincipal = Colors.white;
      corDoTextoSubtitulo = Colors.white70;
    } else {
      corDoTextoPrincipal = Colors.black87;
      corDoTextoSubtitulo = Colors.black54;
    }
  } else {
    corDoTextoPrincipal = corBorda;
    corDoTextoSubtitulo = Colors.black54;
  }

    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: corDoFundo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: corBorda, width: 2),
        ),
        child: Row(
          children: [
            Image.asset(
              caminhoImagem,
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corDoTextoPrincipal)),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: TextStyle(fontSize: 13, color: corDoTextoSubtitulo)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// PASSO 4: Tela de Cadastro (Formulário)

class TelaCadastroCliente1 extends StatefulWidget {
  const TelaCadastroCliente1({super.key});

  @override
  State<TelaCadastroCliente1> createState() => _TelaCadastroCliente1State();
}

class _TelaCadastroCliente1State extends State<TelaCadastroCliente1> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Fecha essa tela e volta para a anterior!
                  }, 
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF00A3FF)),
                  label: const Text('Voltar', style: TextStyle(color: Color(0xFF00A3FF))),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Criar conta - Cliente', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A3FF)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite seu nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Digite um e-mail válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3FF),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    print("Nome: ${_nomeController.text}");
                  }
                },
                child: const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}