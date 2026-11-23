// Verificação facial e validação de documentos do cadastro do profissional.
// Usadas pelo onboarding (e pelo "completar cadastro"); antes ficavam junto
// das telas antigas de cadastro, que foram removidas.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:image_picker/image_picker.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'widgets/check_animado.dart';
import 'widgets/dialogo_sheet.dart';
import 'services/ocr_documento.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

class CadastroFacialInstrucoesPage extends StatelessWidget {
  const CadastroFacialInstrucoesPage({super.key});

  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      appBar: BarraCorOriginal(child: AppBar(
        backgroundColor: _blue,
        surfaceTintColor: _blue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cadastro Facial',
          style: TextStyle(
            color: _white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      )),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: _white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.face_rounded, color: _white, size: 70),
                ),
              ),

              const SizedBox(height: 32),

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Seu rosto será utilizado exclusivamente para autenticação de identidade dentro da plataforma. Para mais informações consulte nossa ',
                    ),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Instruções',
                  style: TextStyle(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const _InstructionItem(
                text:
                    'Segure o celular na altura do rosto e mantenha os braços firmes.',
              ),
              const _InstructionItem(
                text:
                    'Posicione seu rosto completamente dentro do círculo de enquadramento.',
              ),
              const _InstructionItem(
                text:
                    'Remova chapéus, bonés, máscaras e óculos que possam cobrir seu rosto.',
              ),
              const _InstructionItem(
                text:
                    'Utilize um ambiente bem iluminado e prefira fundos neutros.',
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _white,
                    foregroundColor: _blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () async {
                    final resultado = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CadastroFacialPage(),
                      ),
                    );

                    if (resultado != null && context.mounted) {
                      Navigator.pop(context, resultado);
                    }
                  },
                  child: const Text(
                    'Iniciar Cadastro Facial',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String text;
  static const Color _white = Color(0xFFFFFFFF);

  const _InstructionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _white, fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class CadastroFacialPage extends StatefulWidget {
  const CadastroFacialPage({super.key});

  @override
  State<CadastroFacialPage> createState() => _CadastroFacialPageState();
}

class _CadastroFacialPageState extends State<CadastroFacialPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _red = Color(0xFFFF0000);

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  FaceDetector? _faceDetector;

  bool _usandoFrontal = true;
  bool _carregandoCamera = true;
  bool _processando = false;
  bool _finalizado = false;

  String _status = 'Nenhum rosto detectado';
  double _progresso = 0.0;
  Timer? _timer;
  int _semRostoCount = 0;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
        ),
      );
    }

    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de câmera negada.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    _cameras = await availableCameras();
    await _startSelectedCamera();
  }

  Future<void> _startSelectedCamera() async {
    _timer?.cancel();
    await _controller?.dispose();

    if (_cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma câmera encontrada.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final CameraDescription camera = _cameras.firstWhere(
      (c) => _usandoFrontal
          ? c.lensDirection == CameraLensDirection.front
          : c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _carregandoCamera = false;
        _processando = false;
      });

      if (!kIsWeb) {
        _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
          _avaliarRosto();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoCamera = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao iniciar a câmera: $e')),
        );
      }
    }
  }

  Future<void> _trocarCamera() async {
    if (_cameras.isEmpty) return;
    setState(() => _usandoFrontal = !_usandoFrontal);
    await _startSelectedCamera();
  }

  Future<void> _avaliarRosto() async {
    if (kIsWeb || _faceDetector == null) {
      return;
    }

    if (_processando ||
        _carregandoCamera ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    if (_controller!.value.isTakingPicture) {
      return;
    }

    _processando = true;

    try {
      final picture = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _semRostoCount++;

        setState(() {
          _status = _semRostoCount >= 3
              ? 'Vá para um lugar com mais iluminação'
              : 'Nenhum rosto detectado';
          _progresso = 0.0;
        });

        return;
      }

      _semRostoCount = 0;

      if (faces.length > 1) {
        setState(() {
          _status = 'Apenas um rosto por vez';
          _progresso = 0.15;
        });
        return;
      }

      final face = faces.first;
      final preview = _controller!.value.previewSize;
      final w = (preview?.height ?? 1).toDouble();
      final h = (preview?.width ?? 1).toDouble();
      final box = face.boundingBox;

      final faceW = box.width / w;
      final faceH = box.height / h;
      final faceRatio = math.max(faceW, faceH);

      final yaw = (face.headEulerAngleY ?? 0).abs();
      final roll = (face.headEulerAngleZ ?? 0).abs();

      if (yaw > 15 || roll > 15) {
        setState(() {
          _status = 'Centralize o rosto';
          _progresso = 0.45;
        });
        return;
      }

      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;

      if ((leftEye != null && leftEye < 0.25) ||
          (rightEye != null && rightEye < 0.25)) {
        setState(() {
          _status = 'Mantenha os olhos abertos';
          _progresso = 0.6;
        });
        return;
      }

      if (faceRatio < 0.18) {
        setState(() {
          _status = 'Afaste mais a câmera';
          _progresso = 0.35;
        });
        return;
      }

      if (faceRatio > 0.65) {
        setState(() {
          _status = 'Afaste o rosto da câmera';
          _progresso = 0.5;
        });
        return;
      }

      setState(() {
        _status = 'Rosto validado com sucesso';
        _progresso = 1.0;
      });

      final idFacial = await _gerarIdFacial(File(picture.path));

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));

      _finalizado = true;
      _timer?.cancel();

      await _controller?.dispose();
      _controller = null;

      if (!mounted) return;

      final resultado = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => CadastroFacialSucessoPage(idFacial: idFacial),
        ),
      );

      if (resultado != null && mounted) {
        Navigator.pop(context, resultado);
      }
    } catch (e, stackTrace) {
      debugPrint('====================');
      debugPrint('ERRO FACIAL: $e');
      debugPrint('$stackTrace');
      debugPrint('====================');

      if (mounted) {
        setState(() {
          _status = 'Não foi possível processar agora';
          _progresso = 0.0;
        });
      }
    } finally {
      _processando = false;
    }
  }

  Future<String> _gerarIdFacial(File file) async {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    if (await file.exists()) {
      await file.delete();
    }

    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(_red, _blue, _progresso) ?? _red;
    final double circleSize = MediaQuery.sizeOf(context).width * 0.82;

    return Scaffold(
      backgroundColor: _blue,
      appBar: BarraCorOriginal(child: AppBar(
        backgroundColor: _blue,
        surfaceTintColor: _blue,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
        title: const Text(
          'Tire sua foto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
        ),
      )),
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              if (_status.startsWith('Falha:'))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 42),

              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'A validação facial automática funciona apenas em Android/iOS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: circleSize,
                        height: circleSize,
                        child:
                            _carregandoCamera ||
                                _controller == null ||
                                !_controller!.value.isInitialized ||
                                _controller!.value.previewSize == null
                            ? const Center(child: CircularProgressIndicator())
                            : FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _controller!.value.previewSize!.height,
                                  height: _controller!.value.previewSize!.width,
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                      ),
                    ),
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 3),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _trocarCamera,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.switch_camera, color: Colors.white, size: 40),
                    const SizedBox(height: 6),
                    const Text(
                      'Virar câmera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class CadastroFacialSucessoPage extends StatefulWidget {
  final String idFacial;

  const CadastroFacialSucessoPage({super.key, required this.idFacial});

  @override
  State<CadastroFacialSucessoPage> createState() =>
      _CadastroFacialSucessoPageState();
}

/// Fundo azul, check vetorial animado (círculo se traçando e depois o check)
/// e o texto/botão surgindo quando o desenho termina.
class _CadastroFacialSucessoPageState extends State<CadastroFacialSucessoPage>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF0FB3FF);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 2300)),
  );

  // O check ocupa ~65% da animação; o resto revela texto e botão.
  late final Animation<double> _check = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0, 0.68),
  );
  late final Animation<double> _texto = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.62, 0.86, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _botao = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.76, 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _anim.value = 1;
    } else if (!_anim.isAnimating && _anim.value == 0) {
      HapticFeedback.lightImpact();
      _anim.forward().whenComplete(() {
        if (mounted) HapticFeedback.mediumImpact();
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _surgir(Animation<double> a, Widget filho) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - a.value)),
          child: child,
        ),
      ),
      child: filho,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _blue,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, widget.idFacial),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Center(child: CheckAnimado(tamanho: 210, progresso: _check)),
              const SizedBox(height: 32),
              _surgir(
                _texto,
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Cadastro Facial concluído!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Seu rosto foi validado com sucesso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _surgir(
                _botao,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, widget.idFacial),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO =================
class _InputFieldWithAnimation extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? suffixIcon;
  final Color? suffixIconColor;
  final Widget? prefixWidget;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onSuffixIconTap;
  final String? errorText;

  const _InputFieldWithAnimation({
    required this.label,
    required this.hint,
    this.suffixIcon,
    this.suffixIconColor,
    this.prefixWidget,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.onSuffixIconTap,
    this.errorText,
  });

  @override
  State<_InputFieldWithAnimation> createState() =>
      _InputFieldWithAnimationState();
}

class _InputFieldWithAnimationState extends State<_InputFieldWithAnimation> {
  FocusNode? _localFocusNode;
  TextEditingController? _localController;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_localFocusNode ??= FocusNode());
  TextEditingController get _effectiveController =>
      widget.controller ?? (_localController ??= TextEditingController());

  bool _isFocused = false;
  late bool _obscureActive;

  @override
  void initState() {
    super.initState();
    _obscureActive = widget.obscureText;
    _effectiveFocusNode.addListener(_handleFocusChange);
    _effectiveController.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _isFocused = _effectiveFocusNode.hasFocus);
  }

  void _handleTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _effectiveController.removeListener(_handleTextChange);
    _localFocusNode?.dispose();
    _localController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || _effectiveController.text.isNotEmpty;

    final bool hasError = widget.errorText != null;

    IconData? dynamicIcon = widget.suffixIcon;
    if (widget.obscureText &&
        (widget.suffixIcon == Icons.visibility_outlined ||
            widget.suffixIcon == Icons.visibility)) {
      dynamicIcon = _obscureActive
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined;
    }

    Color borderColor = Colors.transparent;
    Color labelColor = const Color(0xFF00A2FF).withValues(alpha: 0.5);
    Color backgroundColor = const Color(0xFFFAFAFA);

    if (hasError) {
      borderColor = Colors.red;
      labelColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.02);
    } else if (_isFocused) {
      borderColor = const Color(0xFF00A2FF);
      labelColor = const Color(0xFF00A2FF);
      backgroundColor = Colors.white;
    } else if (shouldFloat) {
      labelColor = Colors.grey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: duracao(const Duration(milliseconds: 250)),
              curve: Curves.easeInOut,
              height: 56,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _isFocused
                        ? const Color(0xFF00A2FF).withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.015),
                    blurRadius: _isFocused ? 8 : 4,
                    offset: _isFocused
                        ? const Offset(0, 4)
                        : const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (widget.prefixWidget != null) ...[
                    widget.prefixWidget!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedPositioned(
                          duration: duracao(const Duration(milliseconds: 200)),
                          curve: Curves.easeInOut,
                          left: 0,
                          right: 0,
                          top: shouldFloat ? 6 : 17,
                          child: IgnorePointer(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: duracao(const Duration(milliseconds: 200)),
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: shouldFloat ? 11 : 16,
                                    fontWeight: shouldFloat
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                  child: Text(widget.label),
                                ),
                                AnimatedOpacity(
                                  duration: duracao(const Duration(milliseconds: 200)),
                                  opacity: shouldFloat ? 1.0 : 0.0,
                                  child: Text(
                                    '*',
                                    style: TextStyle(
                                      color: hasError
                                          ? Colors.red
                                          : const Color(0xFF00A2FF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: duracao(const Duration(milliseconds: 200)),
                          curve: Curves.easeInOut,
                          left: 0,
                          right: 0,
                          bottom: shouldFloat ? 4 : 0,
                          top: shouldFloat ? 22 : 0,
                          child: TextField(
                            controller: _effectiveController,
                            focusNode: _effectiveFocusNode,
                            inputFormatters: widget.inputFormatters,
                            keyboardType: widget.keyboardType,
                            obscureText: _obscureActive,
                            readOnly: widget.readOnly,
                            onTap: widget.onTap,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: shouldFloat ? widget.hint : '',
                              hintStyle: TextStyle(
                                color: hasError
                                    ? Colors.red.withValues(alpha: 0.4)
                                    : const Color(
                                        0xFF00A2FF,
                                      ).withValues(alpha: 0.4),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: shouldFloat
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.only(top: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dynamicIcon != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap:
                          widget.onSuffixIconTap ??
                          (widget.obscureText
                              ? () => setState(
                                  () => _obscureActive = !_obscureActive,
                                )
                              : widget.onTap),
                      child: AnimatedScale(
                        duration: duracao(const Duration(milliseconds: 200)),
                        scale: _isFocused ? 1.05 : 1.0,
                        child: Icon(
                          dynamicIcon,
                          color:
                              widget.suffixIconColor ??
                              (hasError
                                  ? Colors.red
                                  : (_isFocused
                                        ? const Color(0xFF00A2FF)
                                        : Colors.grey.shade400)),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                widget.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= VALIDAÇÃO DE DOCUMENTOS (TELA NOVA) =================
/// Retorna um Map com: 'validado' (bool), 'tiposValidados' (List<String>),
/// 'docsData' (List<Map<String,dynamic>> com tipo, caminho_arquivo)
class ValidacaoDocsPage extends StatefulWidget {
  final String? cpf;
  final String? cnpj;
  final String? dataNascimento;
  final bool isPessoaJuridica;
  final String? tipoDocumentoInicial;

  const ValidacaoDocsPage({
    super.key,
    this.cpf,
    this.cnpj,
    this.dataNascimento,
    this.isPessoaJuridica = false,
    this.tipoDocumentoInicial,
  });

  @override
  State<ValidacaoDocsPage> createState() => _ValidacaoDocsPageState();
}

class _ValidacaoDocsPageState extends State<ValidacaoDocsPage> {
  late final List<_DocType> _docTypes;

  // Tipos de documentos para pessoa física
  static final List<_DocType> _docTypesPF = [
    _DocType(label: 'Registro Geral (RG)', type: 'RG'),
    _DocType(label: 'Carteira de Identidade Nacional (CIN)', type: 'CIN'),
    _DocType(label: 'Carteira Nacional de Habilitação (CNH)', type: 'CNH'),
    _DocType(label: 'Passaporte', type: 'Passaporte'),
  ];

  // Tipos de documentos para pessoa jurídica
  static final List<_DocType> _docTypesPJ = [
    _DocType(label: 'Cartão CNPJ', type: 'Cartão CNPJ'),
    _DocType(
      label: 'Contrato Social / Estatuto Social / Requerimento Empresário',
      type: 'Contrato Social / Estatuto Social/ Requerimento Empresário',
    ),
    _DocType(label: 'Notas Fiscais (DANFE)', type: 'Notas Fiscais (DANFE)'),
    _DocType(label: 'Alvará de Funcionamento', type: 'Alvará de Funcionamento'),
  ];

  bool _carregando = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isPessoaJuridica) {
      _docTypes = _docTypesPJ;
    } else {
      _docTypes = _docTypesPF;
    }

    // Se um tipo de documento foi pré-selecionado (ex: vindo de "Meus Documentos"),
    // inicia automaticamente o fluxo de captura frente/verso sem mostrar a lista.
    if (widget.tipoDocumentoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final doc = _docTypes
            .where((d) => d.type == widget.tipoDocumentoInicial)
            .firstOrNull;
        if (doc != null) {
          _selecionarDocumento(doc);
        }
      });
    }
  }

  // UFs e Órgãos Emissores válidos do Brasil
  static const List<String> _ufsValidas = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  static const List<String> _orgaosValidos = [
    'SSP',
    'SESP',
    'SDS',
    'DETRAN',
    'POLÍCIA CIVIL',
    'PC',
    'SECRETARIA DE SEGURANÇA PÚBLICA',
    'INSTITUTO DE IDENTIFICAÇÃO',
    'IFP',
    'II',
    'DIC',
    'DPC',
    'MTB',
    'CREA',
    'CRC',
    'OAB',
    'CRM',
    'SSP-SP',
    'SSP-RJ',
    'SSP-MG',
    'SSP-BA',
    'SSP-RS',
    'SSP-PR',
    'SSP-PE',
    'SSP-CE',
    'SSP-PA',
    'SSP-MA',
    'SSP-SC',
    'SSP-GO',
    'SSP-DF',
    'SESP-PI',
    'SDS-PE',
  ];

  String _somenteDigitos(String valor) {
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida CPF localmente (mesmo método da classe de cadastro)
  bool _validarCpfLocal(String cpf) {
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    final numeros = cpf.split('').map(int.parse).toList();

    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += numeros[i] * (10 - i);
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;
    if (numeros[9] != digito1) return false;

    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += numeros[i] * (11 - i);
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    return numeros[10] == digito2;
  }

  /// Extrai CPF do texto (formato com ou sem pontuação)
  /// Reconhece: XXX.XXX.XXX-XX, XXXXXXXXXXX, XXXXXXXXX/XX, XXX.XXXXXX/XX, e variações
  String? _extrairCpf(String texto) {
    // Normaliza o texto para melhorar reconhecimento
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    // Tentativa 1: Formato padrão XXX.XXX.XXX-XX ou sem formatação
    final regex1 = RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 2: Formato com barra (9-11 dígitos + barra + 2 dígitos) - CPF/DV comum em RG
    final regex2 = RegExp(r'\d{9,11}/\d{2}');
    match = regex2.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 3: Formato XXX.XXXXXX/XX
    final regex3 = RegExp(r'\d{3}\.\d{6}/\d{2}');
    match = regex3.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 4: Padrão com "CPF:" no texto
    final regex4 = RegExp(
      r'CPF[:\s]*(\d{3}[\s\.]?\d{3}[\s\.]?\d{3}[\s\-]?\d{2})',
    );
    match = regex4.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    // Tentativa 5: Busca por sequências de 11 caracteres que pareçam CPF
    // Captura dígitos e possíveis letras confundidas com números (X, I, L, O)
    final regex5 = RegExp(r'[0-9XIL]{11,14}');
    final matches = regex5.allMatches(textoNormalizado);
    for (final m in matches) {
      final candidato = _somenteDigitos(m.group(0)!);
      if (candidato.length == 11 && _validarCpfLocal(candidato)) {
        return candidato;
      }
    }

    // Tentativa 6: Busca por qualquer sequência de 11 dígitos consecutivos
    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 11) {
      for (int i = 0; i <= apenasDigitos.length - 11; i++) {
        final candidato = apenasDigitos.substring(i, i + 11);
        if (!RegExp(r'^(\d)\1{10}$').hasMatch(candidato)) {
          if (_validarCpfLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    return null;
  }

  /// Extrai datas no formato DD/MM/AAAA ou AAAA-MM-DD
  List<DateTime> _extrairDatas(String texto) {
    final datas = <DateTime>[];
    final regex1 = RegExp(r'\d{2}/\d{2}/\d{4}');
    final regex2 = RegExp(r'\d{4}-\d{2}-\d{2}');

    for (final match in regex1.allMatches(texto)) {
      final partes = match.group(0)!.split('/');
      final dia = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final ano = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 &&
          ano <= 2050 &&
          mes >= 1 &&
          mes <= 12 &&
          dia >= 1 &&
          dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    for (final match in regex2.allMatches(texto)) {
      final partes = match.group(0)!.split('-');
      final ano = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final dia = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 &&
          ano <= 2050 &&
          mes >= 1 &&
          mes <= 12 &&
          dia >= 1 &&
          dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    return datas;
  }

  /// Extrai número de RG tentando encontrar padrões
  String? _extrairRg(String texto) {
    // Padrões comuns: XX.XXX.XXX-X, X.XXX.XXX, XXXXXXXX-X
    final regex = RegExp(r'\d{1,2}\.?\d{3}\.?\d{3}-?[\dxX]');
    final match = regex.firstMatch(texto);
    return match?.group(0);
  }

  /// Extrai a UF do texto (sigla de 2 letras maiúsculas comum em docs)
  String? _extrairUf(String texto) {
    for (final uf in _ufsValidas) {
      if (texto.contains(uf)) return uf;
    }
    return null;
  }

  /// Extrai órgão emissor do texto
  String? _extrairOrgaoEmissor(String texto) {
    for (final orgao in _orgaosValidos) {
      if (texto.toUpperCase().contains(orgao)) return orgao;
    }
    return null;
  }

  /// Verifica se formato de RG é válido para a UF
  bool _validarFormatoRg(String? rg, String? uf) {
    if (rg == null) return false;
    final digitos = _somenteDigitos(rg);
    // RG geralmente tem entre 7 e 11 dígitos
    return digitos.length >= 7 && digitos.length <= 11;
  }

  /// Extrai nacionalidade do texto
  bool _verificarNacionalidadeBrasileira(String texto) {
    final textoUp = texto.toUpperCase();
    return textoUp.contains('BRASILEIRO') ||
        textoUp.contains('BRASILEIRA') ||
        textoUp.contains('BRAZIL') ||
        textoUp.contains('NACIONALIDADE') ||
        textoUp.contains('REPÚBLICA FEDERATIVA DO BRASIL') ||
        textoUp.contains('REPUBLICA FEDERATIVA DO BRASIL');
  }

  /// Processa OCR da imagem usando Google ML Kit
  Future<String> _processarOcr(File file) async {
    // Foto original + versão tratada (cinza, contraste, ampliada).
    return OcrDocumento.lerTexto(file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0FB3FF),
      appBar: BarraCorOriginal(child: AppBar(
        backgroundColor: const Color(0xFF0FB3FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Anexe os Documentos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      )),
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: duracao(const Duration(milliseconds: 1100)),
                      builder: (context, t, child) {
                        final cartao = Curves.easeOutBack.transform(
                          (t / 0.6).clamp(0.0, 1.0),
                        );
                        final selo = Curves.elasticOut.transform(
                          ((t - 0.45) / 0.55).clamp(0.0, 1.0),
                        );
                        return Stack(
                          alignment: Alignment.bottomRight,
                          clipBehavior: Clip.none,
                          children: [
                            Opacity(
                              opacity: cartao.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * cartao,
                                child: child,
                              ),
                            ),
                            Transform.scale(
                              scale: selo,
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF0FB3FF),
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            104,
                            107,
                            109,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.credit_card,
                          size: 50,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'O seu documento de identidade é utilizado exclusivamente para a verificação da sua conta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.4),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Para mais informações confira a Política de Privacidade.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Escolha o tipo documento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Cartão de leitura enquanto o OCR roda.
              AnimatedSwitcher(
                duration: duracao(const Duration(milliseconds: 300)),
                transitionBuilder: (child, anim) => SizeTransition(
                  sizeFactor: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _carregando
                    ? Container(
                        key: const ValueKey('lendo'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.document_scanner_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Analisando documento...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('parado')),
              ),

              // Itens entram em cascata.
              for (final (i, doc) in _docTypes.indexed)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duracao(Duration(milliseconds: 420 + i * 120)),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 26 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: _buildDocButton(doc),
                ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _podeEnviar() ? _enviarDocumentos : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: const Color(0xFF0FB3FF),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    disabledForegroundColor: const Color(0xFF64748B),
                    elevation: _podeEnviar() ? 3 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: Color(0xFF64748B),
                            strokeWidth: 3,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_podeEnviar()) ...[
                              const Icon(Icons.lock_outline_rounded, size: 20),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              'Enviar Documentos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocButton(_DocType doc) {
    final isValid = doc.isValid;
    final isInvalid = doc.isInvalid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _selecionarDocumento(doc),
          child: AnimatedContainer(
            duration: duracao(const Duration(milliseconds: 320)),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(bottom: doc.errorMessage != null ? 2 : 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isValid
                  ? Colors.white
                  : isInvalid
                  ? const Color(0x33DC2626)
                  : Colors.transparent,
              border: Border.all(
                color: isValid
                    ? const Color(0xFFFFFFFF)
                    : isInvalid
                    ? const Color(0xFFFECACA)
                    : Colors.white,
                width: isInvalid ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isValid
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isValid ? const Color(0xFF0FB3FF) : Colors.white,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: duracao(const Duration(milliseconds: 350)),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: isValid
                      ? const Icon(
                          Icons.check_circle,
                          key: ValueKey('valido'),
                          color: Color(0xFF0FB3FF),
                          size: 28,
                        )
                      : isInvalid
                      ? const Icon(
                          Icons.error_outline,
                          key: ValueKey('invalido'),
                          color: Color(0xFFFECACA),
                          size: 28,
                        )
                      : const Icon(
                          Icons.arrow_forward_ios,
                          key: ValueKey('pendente'),
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: duracao(const Duration(milliseconds: 250)),
          curve: Curves.easeOutCubic,
          child: doc.errorMessage == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFFFE4E6),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doc.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFFE4E6),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _selecionarDocumento(_DocType doc) async {
    if (doc.isValid) {
      _mostrarOpcoesDocumentoValido(doc);
      return;
    }

    // Se estiver invalidado, permite anexar novamente sem mensagem extra
    if (doc.isInvalid) {
      setState(() {
        doc.isInvalid = false;
        doc.errorMessage = null;
      });
    }

    // Inicia o fluxo de captura: frente -> verso
    await _capturarFrente(doc);
  }

  Future<void> _capturarFrente(_DocType doc) async {
    final source = await _mostrarOpcoesOrigem('Frente do Documento');
    if (source == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 100, // Máxima qualidade para OCR preciso
    );

    if (file == null) return;

    setState(() {
      _carregando = true;
      doc.errorMessage = null;
      doc.isInvalid = false;
      doc.isValid = false;
    });

    // Armazena a frente
    doc.filePathFrente = file.path;

    // Agora pede o verso
    await _capturarVerso(doc);
  }

  Future<void> _capturarVerso(_DocType doc) async {
    final source = await _mostrarOpcoesOrigem('Verso do Documento');
    if (source == null) {
      // Se cancelou o verso, limpa a frente já capturada
      setState(() {
        _carregando = false;
        doc.filePathFrente = null;
      });
      return;
    }

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (file == null) {
      setState(() {
        _carregando = false;
        doc.filePathFrente = null;
      });
      return;
    }

    // Armazena o verso
    doc.filePathVerso = file.path;

    // Processa OCR da frente (onde estão os dados principais)
    String fullText;
    try {
      fullText = await _processarOcr(File(doc.filePathFrente!));
    } catch (e) {
      fullText = '';
    }

    // Se OCR falhou completamente, tentar ler como texto simples
    if (fullText.isEmpty) {
      fullText = 'OCR_EMPTY';
    }

    debugPrint('=== TEXTO EXTRAÍDO DO DOCUMENTO ${doc.type} ===');
    debugPrint(fullText);
    debugPrint('==============================================');

    // Combina os textos da frente e verso
    String fullTextVerso = '';
    try {
      fullTextVerso = await _processarOcr(File(doc.filePathVerso!));
    } catch (e) {
      fullTextVerso = '';
    }
    fullText = '$fullText\n$fullTextVerso';

    await _validarDocumento(doc, fullText);

    setState(() => _carregando = false);
  }

  Future<ImageSource?> _mostrarOpcoesOrigem(String titulo) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0FB3FF)),
                title: const Text('Tirar Foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF0FB3FF),
                ),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validarCnpjLocal(String cnpj) {
    if (cnpj.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    final numeros = cnpj.split('').map(int.parse).toList();

    const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    int soma = 0;
    for (int i = 0; i < 12; i++) {
      soma += numeros[i] * pesos1[i];
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;
    if (numeros[12] != digito1) return false;

    soma = 0;
    for (int i = 0; i < 13; i++) {
      soma += numeros[i] * pesos2[i];
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    return numeros[13] == digito2;
  }

  /// Extrai CNPJ do texto
  String? _extrairCnpj(String texto) {
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    // Tentativa 1: Formato padrão XX.XXX.XXX/XXXX-XX
    final regex1 = RegExp(r'\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 2: CNPJ puro de 14 dígitos
    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 14) {
      for (int i = 0; i <= apenasDigitos.length - 14; i++) {
        final candidato = apenasDigitos.substring(i, i + 14);
        if (!RegExp(r'^(\d)\1{13}$').hasMatch(candidato)) {
          if (_validarCnpjLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    // Tentativa 3: Padrão com "CNPJ:" no texto
    final regex3 = RegExp(
      r'CNPJ[:\s]*(\d{2}[\s\.]?\d{3}[\s\.]?\d{3}[\s\/]?\d{4}[\s\-]?\d{2})',
    );
    match = regex3.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    return null;
  }

  Future<void> _validarDocumento(_DocType doc, String texto) async {
    final erros = <String>[];
    bool valido = true;

    // Conferência tolerante: se o número informado aparece no texto (com as
    // trocas comuns do OCR ou 1 dígito lido errado), ele é colocado no
    // início do texto para os extratores abaixo o encontrarem primeiro.
    final esperadoCnpj = widget.cnpj == null
        ? ''
        : _somenteDigitos(widget.cnpj!);
    final esperadoCpf = widget.cpf == null ? '' : _somenteDigitos(widget.cpf!);
    if (widget.isPessoaJuridica &&
        esperadoCnpj.length == 14 &&
        OcrDocumento.contemNumero(texto, esperadoCnpj)) {
      texto = 'CNPJ: ${OcrDocumento.formatarCnpj(esperadoCnpj)}\n$texto';
    } else if (!widget.isPessoaJuridica &&
        esperadoCpf.length == 11 &&
        OcrDocumento.contemNumero(texto, esperadoCpf)) {
      texto = 'CPF: ${OcrDocumento.formatarCpf(esperadoCpf)}\n$texto';
    }

    if (widget.isPessoaJuridica) {
      // Validação para documentos de Pessoa Jurídica
      final cnpjDigitado = widget.cnpj != null
          ? _somenteDigitos(widget.cnpj!)
          : null;
      final cnpjEncontrado = _extrairCnpj(texto);

      switch (doc.type) {
        case 'Cartão CNPJ':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no documento.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do documento não corresponde ao CNPJ cadastrado.');
            valido = false;
          }
          break;

        case 'Contrato Social / Estatuto Social/ Requerimento Empresário':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no documento.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do documento não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar palavras-chave de contrato social no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('CONTRATO SOCIAL') &&
              !textoUp.contains('ESTATUTO SOCIAL') &&
              !textoUp.contains('REQUERIMENTO') &&
              !textoUp.contains('EMPRESÁRIO') &&
              !textoUp.contains('EMPRESARIO')) {
            // Não é um erro crítico - apenas informativo
          }
          break;

        case 'Notas Fiscais (DANFE)':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ na DANFE.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ da DANFE não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar se tem "DANFE" ou "NOTA FISCAL" no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('DANFE') && !textoUp.contains('NOTA FISCAL')) {
            erros.add(
              'Não foi possível identificar como uma DANFE/Nota Fiscal.',
            );
            valido = false;
          }
          break;

        case 'Alvará de Funcionamento':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no Alvará.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do Alvará não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar se tem "ALVARÁ" ou "ALVARA" no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('ALVARÁ') &&
              !textoUp.contains('ALVARA') &&
              !textoUp.contains('FUNCIONAMENTO')) {
            erros.add(
              'Não foi possível identificar como um Alvará de Funcionamento.',
            );
            valido = false;
          }
          break;

        default:
          // Caso não reconhecido, validar pelo menos o CNPJ
          if (cnpjDigitado != null &&
              cnpjEncontrado != null &&
              cnpjEncontrado == cnpjDigitado) {
            valido = true;
          } else {
            erros.add(
              'Não foi possível validar os dados da empresa no documento.',
            );
            valido = false;
          }
      }
    } else {
      // Validação original para documentos de Pessoa Física
      final cpfDigitado = widget.cpf != null
          ? _somenteDigitos(widget.cpf!)
          : null;
      final cpfEncontrado = _extrairCpf(texto);
      final datas = _extrairDatas(texto);
      final dataNascimentoStr = widget.dataNascimento;

      switch (doc.type) {
        case 'RG':
          // 1. Validar CPF
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }

          // 2. Validar número do RG
          final rg = _extrairRg(texto);
          final uf = _extrairUf(texto);
          if (!_validarFormatoRg(rg, uf)) {
            erros.add(
              'Número do RG não identificado ou formato inválido para a UF.',
            );
            valido = false;
          }

          // 3. Validar data de validade (RG não pode estar vencido - maior de idade)
          final dataNascimentoDoc = _encontrarDataNascimento(
            datas,
            dataNascimentoStr,
          );
          if (dataNascimentoDoc != null &&
              dataNascimentoStr != null &&
              dataNascimentoStr.isNotEmpty) {
            final hoje = DateTime.now();
            if (dataNascimentoDoc.isAfter(hoje)) {
              erros.add('Data de nascimento inválida (futura).');
              valido = false;
            }
          }

          // 4. Bater data de nascimento
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }

          // 5. Verificar órgão emissor / UF
          final orgao = _extrairOrgaoEmissor(texto);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CIN':
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          final orgao = _extrairOrgaoEmissor(texto);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          final uf = _extrairUf(texto);
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CNH':
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          final hojeCNH = DateTime.now();
          bool temDataValida = false;
          for (final data in datas) {
            if (data.isAfter(hojeCNH) ||
                (data.year == hojeCNH.year &&
                    data.month == hojeCNH.month &&
                    data.day == hojeCNH.day)) {
              temDataValida = true;
              break;
            }
          }
          if (!temDataValida && datas.isNotEmpty) {
            erros.add(
              'Documento parece estar vencido (data de validade expirada).',
            );
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          break;

        case 'Passaporte':
          final hojePass = DateTime.now();
          bool temDataValidaPass = false;
          for (final data in datas) {
            if (data.isAfter(hojePass)) {
              temDataValidaPass = true;
              break;
            }
          }
          if (!temDataValidaPass) {
            erros.add(
              'Passaporte parece estar vencido ou data de validade não identificada.',
            );
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no passaporte.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do passaporte não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          if (!_verificarNacionalidadeBrasileira(texto)) {
            erros.add(
              'Nacionalidade brasileira não identificada no passaporte.',
            );
            valido = false;
          }
          for (final data in datas) {
            final dataFuturaLimite = hojePass.add(
              const Duration(days: 365 * 15),
            );
            if (data.isAfter(dataFuturaLimite)) {
              erros.add('Data de emissão inválida (futura demais).');
              valido = false;
              break;
            }
          }
          break;
      }
    }

    setState(() {
      doc.isValid = valido;
      doc.isInvalid = !valido;
      doc.errorMessage = valido
          ? null
          : erros.isNotEmpty
          ? erros.join('\n')
          : 'Não foi possível identificar seus dados no documento anexado. Tente novamente com outro anexo.';
    });
  }

  /// Tenta encontrar a data de nascimento no documento comparando com a esperada
  DateTime? _encontrarDataNascimento(
    List<DateTime> datas,
    String? dataNascimentoEsperada,
  ) {
    if (datas.isEmpty) return null;

    final dataEsperada = _parseData(dataNascimentoEsperada);
    if (dataEsperada != null) {
      // Tenta encontrar data igual à esperada
      for (final data in datas) {
        if (data.year == dataEsperada.year &&
            data.month == dataEsperada.month &&
            data.day == dataEsperada.day) {
          return data;
        }
      }
    }

    // Se não encontrou pela data exata, retorna a primeira data que parece de nascimento
    // (geralmente a mais antiga)
    if (datas.length == 1) return datas.first;

    datas.sort((a, b) => a.compareTo(b));
    return datas.first;
  }

  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    try {
      // Formato AAAA-MM-DD
      if (dataStr.contains('-')) {
        final partes = dataStr.split('-');
        return DateTime(
          int.parse(partes[0]),
          int.parse(partes[1]),
          int.parse(partes[2]),
        );
      }
      // Formato DD/MM/AAAA
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        return DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  void _mostrarOpcoesDocumentoValido(_DocType doc) {
    mostrarDialogoComoSheet(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          doc.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.filePathFrente != null) ...[
              const Text(
                'Frente:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.filePathFrente!.toLowerCase().endsWith('.pdf')
                    ? const Icon(
                        Icons.picture_as_pdf,
                        size: 100,
                        color: Colors.red,
                      )
                    : Image.file(
                        File(doc.filePathFrente!),
                        height: 150,
                        fit: BoxFit.contain,
                      ),
              ),
            ],
            if (doc.filePathVerso != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Verso:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.filePathVerso!.toLowerCase().endsWith('.pdf')
                    ? const Icon(
                        Icons.picture_as_pdf,
                        size: 100,
                        color: Colors.red,
                      )
                    : Image.file(
                        File(doc.filePathVerso!),
                        height: 150,
                        fit: BoxFit.contain,
                      ),
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Documento validado com sucesso.',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Abrir seleção para trocar
              _selecionarDocumento(doc);
            },
            child: const Text('Trocar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                doc.isValid = false;
                doc.isInvalid = false;
                doc.filePathFrente = null;
                doc.filePathVerso = null;
                doc.errorMessage = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _podeEnviar() => _docTypes.any((d) => d.isValid);

  Future<void> _enviarDocumentos() async {
    if (!_podeEnviar()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'É necessário enviar pelo menos 1 documento anexado e validado.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Coletar tipos dos documentos validados
    final docsData = _docTypes
        .where((d) => d.isValid)
        .map((d) => {'tipo': d.type})
        .toList();

    if (mounted) {
      Navigator.pop(context, {'validado': true, 'docsData': docsData});
    }
  }
}

class _DocType {
  final String label;
  final String type;
  bool isValid = false;
  bool isInvalid = false;
  String? filePathFrente;
  String? filePathVerso;
  String? errorMessage;

  _DocType({required this.label, required this.type});
}

// ================= MASK INPUT FORMATTER =================
class MaskedInputFormatter extends TextInputFormatter {
  final String mask;
  MaskedInputFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    var formatted = '';
    var digitIndex = 0;
    for (var i = 0; i < mask.length; i++) {
      if (digitIndex >= digits.length) break;
      if (mask[i] == '#') {
        formatted += digits[digitIndex];
        digitIndex++;
      } else {
        formatted += mask[i];
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
