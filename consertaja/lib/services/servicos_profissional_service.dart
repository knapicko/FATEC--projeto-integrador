import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_catalogo.dart';
import '../models/servico_profissional.dart';

class ServicosProfissionalService {
  static SupabaseClient get _supabase => Supabase.instance.client;
  static const String _bucketServicos = 'Servicos';

  // ── Identidade ─────────────────────────────────────────────────────────────

  static Future<int?> buscarIdProfissional() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ [ServicosSvc] Usuário não autenticado.');
        return null;
      }

      final usuarioRow = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioRow == null) {
        debugPrint('❌ [ServicosSvc] Usuário não encontrado.');
        return null;
      }

      final idUsuario = (usuarioRow['id_usuario'] as num).toInt();

      final dadosProfRow = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();

      if (dadosProfRow == null) {
        debugPrint('❌ [ServicosSvc] dados_profissionais não encontrado.');
        return null;
      }

      final idProfissional = (dadosProfRow['id_profissional'] as num).toInt();
      debugPrint('✅ [ServicosSvc] id_profissional: $idProfissional');
      return idProfissional;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarIdProfissional ERROR: $e');
      return null;
    }
  }

  // ── Upload de imagem ────────────────────────────────────────────────────────

  /// Faz upload de uma imagem para o bucket 'Servicos' e retorna a URL pública.
  static Future<String?> uploadImagemServico(XFile imagem) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      debugPrint('📤 [ServicosSvc] Upload imagem: $fileName');

      if (kIsWeb) {
        final bytes = await imagem.readAsBytes();
        await _supabase.storage
            .from(_bucketServicos)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      } else {
        await _supabase.storage
            .from(_bucketServicos)
            .upload(
              fileName,
              File(imagem.path),
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      final url = _supabase.storage
          .from(_bucketServicos)
          .getPublicUrl(fileName);
      debugPrint('✅ [ServicosSvc] URL da imagem: $url');
      return url;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] uploadImagemServico ERROR: $e');
      return null;
    }
  }

  // ── CRUD dos serviços do profissional ──────────────────────────────────────

  /// Lista todos os serviços ativos do profissional logado.
  /// Faz join (left join) com `oficios` para obter funcao e cod_cor.
  static Future<List<ServicoProfissional>> buscarServicos() async {
    try {
      final idProf = await buscarIdProfissional();
      if (idProf == null) return [];

      final rows = await _supabase
          .from('servicos_profissional')
          .select('*, oficios(funcao, cod_cor)')
          .eq('fk_profissional', idProf)
          .eq('ativo', true)
          .order('data_criacao', ascending: false);

      return rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicos ERROR: $e');
      return [];
    }
  }

  /// Cria um novo serviço. Opcionalmente faz upload da imagem antes.
  static Future<({bool sucesso, int? id, String? erro})> criarServico({
    required String titulo,
    required String descricao,
    required double valor,
    required int fkOficio,
    String? imagemUrl,
    XFile? imagemLocal,
  }) async {
    try {
      final idProf = await buscarIdProfissional();
      if (idProf == null) {
        return (
          sucesso: false,
          id: null,
          erro: 'Profissional não encontrado. Verifique o cadastro.',
        );
      }

      // Faz upload da imagem se foi escolhida localmente
      String? urlFinal = imagemUrl;
      if (imagemLocal != null) {
        urlFinal = await uploadImagemServico(imagemLocal);
      }

      final response = await _supabase
          .from('servicos_profissional')
          .insert({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'imagem_url': urlFinal,
            'ativo': true,
            'fk_profissional': idProf,
          })
          .select('id_servico_prof')
          .single();

      final id = (response['id_servico_prof'] as num).toInt();
      debugPrint('✅ [ServicosSvc] Serviço criado! id=$id');
      return (sucesso: true, id: id, erro: null);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] criarServico ERROR: $e');
      return (sucesso: false, id: null, erro: 'Erro ao salvar serviço: $e');
    }
  }

  /// Atualiza um serviço existente. Opcionalmente faz upload de nova imagem.
  static Future<({bool sucesso, String? erro})> atualizarServico({
    required int id,
    required String titulo,
    required String descricao,
    required double valor,
    required int fkOficio,
    String? imagemUrl,
    XFile? imagemLocal,
  }) async {
    try {
      // Faz upload da nova imagem se foi escolhida
      String? urlFinal = imagemUrl;
      if (imagemLocal != null) {
        urlFinal = await uploadImagemServico(imagemLocal);
      }

      await _supabase
          .from('servicos_profissional')
          .update({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'imagem_url': urlFinal,
            'data_alteracao': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_servico_prof', id);

      debugPrint('✅ [ServicosSvc] Serviço atualizado! id=$id');
      return (sucesso: true, erro: null);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] atualizarServico ERROR: $e');
      return (sucesso: false, erro: 'Erro ao atualizar serviço: $e');
    }
  }

  /// Remove (soft delete) um serviço.
  static Future<bool> desativarServico(int id) async {
    try {
      await _supabase
          .from('servicos_profissional')
          .update({
            'ativo': false,
            'data_alteracao': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_servico_prof', id);
      debugPrint('✅ [ServicosSvc] Serviço desativado id=$id');
      return true;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] desativarServico ERROR: $e');
      return false;
    }
  }

  /// Remove permanentemente um serviço.
  static Future<bool> deletarServico(int id) async {
    try {
      await _supabase
          .from('servicos_profissional')
          .delete()
          .eq('id_servico_prof', id);
      debugPrint('✅ [ServicosSvc] Serviço deletado id=$id');
      return true;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] deletarServico ERROR: $e');
      return false;
    }
  }

  // ── Ofícios (categorias) ──────────────────────────────────────────────────

  /// Busca todos os ofícios (categorias/funções) disponíveis.
  static Future<List<({String nome, String cor})>> buscarOficios() async {
    try {
      final rows = await _supabase.from('oficios').select('funcao, cod_cor');
      return rows.map((row) {
        final nome = row['funcao']?.toString().trim() ?? 'GERAL';
        final cor = row['cod_cor']?.toString().trim() ?? '#1D2430';
        return (nome: nome, cor: cor);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarOficios ERROR: $e');
      // Fallback para uma lista básica
      return [
        (nome: 'GERAL', cor: '#1D2430'),
        (nome: 'ELÉTRICA', cor: '#F59E0B'),
        (nome: 'HIDRÁULICA', cor: '#1F8BFF'),
      ];
    }
  }

  // ── Catálogo de serviços padrão ────────────────────────────────────────────

  /// Busca todos os serviços do catálogo (sugestões disponíveis para o profissional).
  /// Faz join com a tabela `oficios` para obter a função (categoria) e cor.
  static Future<List<ServicoCatalogo>> buscarCatalogo() async {
    try {
      final rows = await _supabase
          .from('servicos_catalogo')
          .select('*, oficios(funcao, cod_cor)') // join para pegar funcao/cor
          .eq('ativo', true)
          .order('titulo', ascending: true);

      return rows.map<ServicoCatalogo>(ServicoCatalogo.fromMap).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarCatalogo ERROR: $e');
      return [];
    }
  }
}
