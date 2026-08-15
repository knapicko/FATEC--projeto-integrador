import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Widget que exibe a foto do Google com cache local e tratamento de erro.
/// Evita requisições excessivas (erro 429) armazenando a imagem localmente.
///
/// Na web, usa [NetworkImage] diretamente (cache de arquivos não é suportado).
class FotoPerfilGoogle extends StatefulWidget {
  final String? fotoUrl;
  final double radius;
  final Widget? placeholder;

  const FotoPerfilGoogle({
    super.key,
    this.fotoUrl,
    this.radius = 40,
    this.placeholder,
  });

  @override
  State<FotoPerfilGoogle> createState() => _FotoPerfilGoogleState();
}

class _FotoPerfilGoogleState extends State<FotoPerfilGoogle> {
  File? _imagemCache;
  bool _carregando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    if (widget.fotoUrl != null) {
      _carregarImagemComCache();
    } else {
      _carregando = false;
      _erro = true;
    }
  }

  @override
  void didUpdateWidget(FotoPerfilGoogle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoUrl != widget.fotoUrl) {
      _carregando = true;
      _erro = false;
      _imagemCache = null;
      if (widget.fotoUrl != null) {
        _carregarImagemComCache();
      } else {
        _carregando = false;
        _erro = true;
      }
    }
  }

  Future<void> _carregarImagemComCache() async {
    // Na web, não há dart:io File nem path_provider.
    // Usamos Image.network diretamente, que carrega com seus próprios headers.
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = false;
        });
      }
      return;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      final nomeArquivo = widget.fotoUrl!.hashCode.toString();
      final arquivoCache = File('${cacheDir.path}/$nomeArquivo.jpg');

      // Verifica se já existe em cache
      if (await arquivoCache.exists()) {
        // Verifica se o cache é recente (menos de 7 dias)
        final stat = await arquivoCache.stat();
        final idadeCache = DateTime.now().difference(stat.modified);
        if (idadeCache.inDays < 7) {
          setState(() {
            _imagemCache = arquivoCache;
            _carregando = false;
            _erro = false;
          });
          return;
        }
      }

      // Baixa a imagem com timeout e headers adequados
      final response = await http.get(
        Uri.parse(widget.fotoUrl!),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout ao carregar imagem');
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Salva no cache
        await arquivoCache.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() {
            _imagemCache = arquivoCache;
            _carregando = false;
            _erro = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } on SocketException catch (_) {
      _tratarErro();
    } on TimeoutException catch (_) {
      _tratarErro();
    } catch (_) {
      _tratarErro();
    }
  }

  void _tratarErro() {
    if (mounted) {
      setState(() {
        _carregando = false;
        _erro = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Na web, usa NetworkImage diretamente
    if (kIsWeb) {
      if (widget.fotoUrl == null || widget.fotoUrl!.isEmpty) {
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.grey.shade300,
          child: Icon(
            Icons.person,
            size: widget.radius,
            color: Colors.grey.shade600,
          ),
        );
      }

      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(widget.fotoUrl!),
        onBackgroundImageError: (_, __) {},
        child: widget.placeholder,
      );
    }

    if (_carregando) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade200,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00A2FF),
          ),
        ),
      );
    }

    if (_erro || _imagemCache == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(
          Icons.person,
          size: widget.radius,
          color: Colors.grey.shade600,
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: FileImage(_imagemCache!),
    );
  }
}