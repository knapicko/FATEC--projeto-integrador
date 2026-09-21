import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BottomNavigationBarProfissional extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Quando informado, tem prioridade sobre o cache interno.
  /// Quando null (padrão), a barra resolve sozinha se a conta ativa é
  /// empresa ou profissional independente — sem "piscar" o Perfil.
  final bool? isContaEmpresa;

  /// Chamado quando o usuário toca na aba em que já está
  /// (ex: tocar em "Home" estando na Home). As telas usam para
  /// recarregar os dados em vez de ignorar o toque.
  /// Se null, o toque na aba atual apenas re-executa [onTap].
  final ValueChanged<int>? onReselecionarAbaAtual;

  const BottomNavigationBarProfissional({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isContaEmpresa,
    this.onReselecionarAbaAtual,
  });

  /// Mesma chave usada na home/mensagens:
  /// `consertaja_conta_empresa_ativa_<authUid>`.
  static const String prefContaAtivaKey = 'consertaja_conta_empresa_ativa';

  /// Cache em memória por usuário: evita ler SharedPreferences a cada build
  /// e elimina o "piscar" do Perfil ao abrir telas como empresa.
  static final Map<String, bool> _cacheContaEmpresa = {};

  /// Último valor conhecido (qualquer usuário) — palpite inicial no
  /// primeiríssimo frame, antes de qualquer leitura assíncrona.
  static bool? _ultimoValorConhecido;

  /// Pré-carrega o cache (chame ao trocar de conta / entrar nas telas).
  static Future<bool> precarregarContaEmpresa() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return _ultimoValorConhecido ?? false;
      final cached = _cacheContaEmpresa[user.id];
      if (cached != null) {
        _ultimoValorConhecido = cached;
        return cached;
      }
      final prefs = await SharedPreferences.getInstance();
      final ativa = prefs.getBool('${prefContaAtivaKey}_${user.id}') ?? false;
      _cacheContaEmpresa[user.id] = ativa;
      _ultimoValorConhecido = ativa;
      return ativa;
    } catch (_) {
      return _ultimoValorConhecido ?? false;
    }
  }

  /// Atualiza o cache na hora da troca (a UI reage sem esperar disco).
  static void notificarTrocaConta(bool isEmpresa) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) _cacheContaEmpresa[user.id] = isEmpresa;
    } catch (_) {}
    _ultimoValorConhecido = isEmpresa;
  }

  /// Leitura síncrona para o primeiro frame (sem piscar).
  static bool leituraSincronaContaEmpresa() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final cached = _cacheContaEmpresa[user.id];
        if (cached != null) return cached;
      }
    } catch (_) {}
    return _ultimoValorConhecido ?? false;
  }

  @override
  State<BottomNavigationBarProfissional> createState() =>
      _BottomNavigationBarProfissionalState();
}

class _BottomNavigationBarProfissionalState
    extends State<BottomNavigationBarProfissional> {
  late bool _isEmpresa;

  @override
  void initState() {
    super.initState();
    // Valor inicial síncrono: nunca mostra "Perfil" piscando quando já se
    // sabe (cache/prop) que a conta é empresa.
    _isEmpresa =
        widget.isContaEmpresa ??
        BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
    if (widget.isContaEmpresa == null) {
      // Confirma em background e só dá setState se realmente mudou.
      BottomNavigationBarProfissional.precarregarContaEmpresa().then((ativa) {
        if (mounted && ativa != _isEmpresa) {
          setState(() => _isEmpresa = ativa);
        }
      });
    }
  }

  @override
  void didUpdateWidget(BottomNavigationBarProfissional oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isContaEmpresa != null && widget.isContaEmpresa != _isEmpresa) {
      _isEmpresa = widget.isContaEmpresa!;
    } else if (widget.isContaEmpresa == null &&
        oldWidget.isContaEmpresa != null) {
      _isEmpresa =
          BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
      BottomNavigationBarProfissional.precarregarContaEmpresa().then((ativa) {
        if (mounted && ativa != _isEmpresa) {
          setState(() => _isEmpresa = ativa);
        }
      });
    }
  }

  List<BottomNavigationBarItem> get _items => [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    const BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Radar'),
    const BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      label: 'Mensagens',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.archive_outlined),
      label: 'Serviços',
    ),
    if (_isEmpresa)
      const BottomNavigationBarItem(
        icon: Icon(Icons.storefront_outlined),
        label: 'Empresa',
      )
    else
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Perfil',  
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0FB3FF),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      currentIndex: widget.currentIndex,
      // Tocar na aba atual recarrega a página em vez de ser ignorado.
      onTap: (index) {
        if (index == widget.currentIndex) {
          if (widget.onReselecionarAbaAtual != null) {
            widget.onReselecionarAbaAtual!(index);
          } else {
            widget.onTap(index);
          }
          return;
        }
        widget.onTap(index);
      },
      items: _items,
    );
  }
}
