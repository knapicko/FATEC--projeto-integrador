import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaServicosService extends ChangeNotifier {
  static final ListaServicosService instance = ListaServicosService._internal();

  ListaServicosService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  int _quantidade = 0;
  double _valorTotal = 0.0;
  int? _idLista;

  int get quantidade => _quantidade;
  double get valorTotal => _valorTotal;
  int? get idLista => _idLista;
  bool get temServicos => _quantidade > 0;

  /// Atualiza os dados da lista de serviços do usuário conectado
  Future<void> atualizar() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _quantidade = 0;
        _valorTotal = 0.0;
        _idLista = null;
        notifyListeners();
        return;
      }

      final usuarioRow = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final idUsuario = (usuarioRow?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) {
        _quantidade = 0;
        _valorTotal = 0.0;
        _idLista = null;
        notifyListeners();
        return;
      }

      final listaRow = await _supabase
          .from('lista_servicos')
          .select('id_lista, valor_total')
          .eq('fk_usuario', idUsuario)
          .order('id_lista', ascending: false)
          .limit(1)
          .maybeSingle();

      if (listaRow == null) {
        _quantidade = 0;
        _valorTotal = 0.0;
        _idLista = null;
        notifyListeners();
        return;
      }

      _idLista = (listaRow['id_lista'] as num).toInt();

      final assRows = await _supabase
          .from('ass_servicos_lista')
          .select('valor_final')
          .eq('fk_lista', _idLista!);

      _quantidade = assRows.length;
      double soma = 0.0;
      for (final r in assRows) {
        soma += double.tryParse(r['valor_final']?.toString() ?? '0') ?? 0.0;
      }
      _valorTotal = soma;

      // Sincroniza a coluna valor_total na tabela lista_servicos por segurança
      try {
        await _supabase
            .from('lista_servicos')
            .update({'valor_total': _valorTotal})
            .eq('id_lista', _idLista!);
      } catch (_) {}

      notifyListeners();
    } catch (e) {
      debugPrint('Erro no ListaServicosService.atualizar: $e');
    }
  }

  void limpar() {
    _quantidade = 0;
    _valorTotal = 0.0;
    _idLista = null;
    notifyListeners();
  }
}
