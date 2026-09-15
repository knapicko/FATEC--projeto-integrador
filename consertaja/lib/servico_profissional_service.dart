import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_catalogo.dart';
import '../models/servico_profissional.dart';

class ServicosProfissionalService {
  static SupabaseClient get _supabase => Supabase.instance.client;
  static const String _bucketServicos = 'Imagens Servicos';

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

  /// Faz upload de uma imagem para o bucket 'Imagens Servicos' e retorna a URL pública.
  static Future<String?> uploadImagemServico(XFile imagem) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ [ServicosSvc] Upload cancelado: usuário não autenticado.');
        return null;
      }

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      debugPrint(
        '📤 [ServicosSvc] Upload imagem: $fileName (bucket: $_bucketServicos)',
      );

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
      debugPrint('❌ [ServicosSvc] uploadImagemServico STACK: ${StackTrace.current}');
      return null;
    }
  }

  // ── CRUD dos serviços do profissional ──────────────────────────────────────

  /// Lista todos os serviços ativos do profissional.
  /// Se `idProfissional` for informado, busca por ele. Caso contrário, busca do profissional logado.
  /// Lista os serviços diretamente e enriquece a categoria quando disponível.
  static Future<List<ServicoProfissional>> buscarServicos({
    int? idProfissional,
  }) async {
    try {
      debugPrint(
        '🔎 [ServicosSvc] Iniciando busca. id recebido: $idProfissional',
      );
      final idProf = idProfissional ?? await buscarIdProfissional();
      if (idProf == null) {
        debugPrint('❌ [ServicosSvc] Busca cancelada: id_profissional nulo.');
        return [];
      }
      debugPrint('🔎 [ServicosSvc] Consultando servicos_profissional com fk_profissional=$idProf');

      final rows = List<Map<String, dynamic>>.from(
        await _supabase
          .from('servicos_profissional')
          .select(
            'id_servico_prof, titulo, descricao, valor, imagem_url, ativo, '
            'fk_profissional, fk_oficios, data_criacao',
          )
          .eq('fk_profissional', idProf)
          .eq('ativo', true)
          .order('data_criacao', ascending: false),
      );

      debugPrint(
        '✅ [ServicosSvc] Serviços encontrados: ${rows.length} para fk_profissional=$idProf',
      );
      if (rows.isEmpty) return [];

      final idsOficios = rows
          .map((row) => (row['fk_oficios'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();

      if (idsOficios.isNotEmpty) {
        try {
          final oficios = await _supabase
              .from('oficios')
              .select('id_oficio, funcao, cor')
              .inFilter('id_oficio', idsOficios);
          final oficiosPorId = <int, Map<String, dynamic>>{
            for (final oficio in oficios)
              (oficio['id_oficio'] as num).toInt(): Map<String, dynamic>.from(
                oficio,
              ),
          };

          for (final row in rows) {
            final idOficio = (row['fk_oficios'] as num?)?.toInt();
            final oficio = idOficio == null ? null : oficiosPorId[idOficio];
            if (oficio != null) row['oficios'] = oficio;
          }
        } catch (e) {
          debugPrint('⚠️ [ServicosSvc] Não foi possível carregar categorias: $e');
        }
      }

      return rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicos ERROR: $e');
      debugPrint('❌ [ServicosSvc] buscarServicos STACK: ${StackTrace.current}');
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
        if (urlFinal == null || urlFinal.isEmpty) {
          return (
            sucesso: false,
            id: null,
            erro:
                'Não foi possível enviar a imagem. Verifique o bucket "Imagens Servicos" e as políticas de Storage do Supabase.',
          );
        }
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
        if (urlFinal == null || urlFinal.isEmpty) {
          return (
            sucesso: false,
            erro:
                'Não foi possível enviar a imagem. Verifique o bucket "Imagens Servicos" e as políticas de Storage do Supabase.',
          );
        }
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

  /// Busca todos os ofícios (categorias/funções) disponíveis, incluindo id_oficio.
  static Future<List<({int id, String nome, String cor})>> buscarOficios() async {
    try {
      final rows = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, cor')
          .order('funcao', ascending: true);
      return rows.map((row) {
        final id = (row['id_oficio'] as num?)?.toInt() ?? 0;
        final nome = row['funcao']?.toString().trim() ?? 'GERAL';
        final cor = row['cor']?.toString().trim() ?? '#1D2430';
        return (id: id, nome: nome, cor: cor);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarOficios ERROR: $e');
      // Fallback para uma lista básica
      return [
        (id: 1, nome: 'GERAL', cor: '#1D2430'),
        (id: 2, nome: 'ELÉTRICA', cor: '#F59E0B'),
        (id: 3, nome: 'HIDRÁULICA', cor: '#1F8BFF'),
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
          .select('*, oficios(funcao, cor)') // join para pegar funcao/cor
          .eq('ativo', true)
          .order('titulo', ascending: true);

      return rows.map<ServicoCatalogo>(ServicoCatalogo.fromMap).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarCatalogo ERROR: $e');
      return [];
    }
  }
}
