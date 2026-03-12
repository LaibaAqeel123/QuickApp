// lib/core/widgets/auth_image.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:food_delivery_app/core/services/auth_service.dart';

class AuthImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AuthImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error   = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AuthImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      setState(() { _bytes = null; _loading = true; _error = false; _errorMsg = null; });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  AUTH IMAGE FETCH');
      debugPrint('║  URL: ${widget.url}');

      final token = await AuthService.instance.getAccessToken();
      debugPrint('║  TOKEN: ${token != null ? "present (${token.length} chars)" : "NULL — no auth header"}');

      final response = await http.get(
        Uri.parse(widget.url),
        headers: {
          'Accept': 'image/*,*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      debugPrint('║  STATUS: ${response.statusCode}');
      debugPrint('║  CONTENT-TYPE: ${response.headers['content-type']}');
      debugPrint('║  BYTES: ${response.bodyBytes.length}');
      debugPrint('╚══════════════════════════════════════╝');

      if (!mounted) return;

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() { _bytes = response.bodyBytes; _loading = false; });
      } else {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = 'HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('║  AUTH IMAGE ERROR: $e');
      debugPrint('╚══════════════════════════════════════╝');
      if (mounted) setState(() { _loading = false; _error = true; _errorMsg = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ??
            const Center(child: SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_error || _bytes == null) {
      debugPrint('AUTH IMAGE: showing error widget — $_errorMsg');
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? const SizedBox.shrink(),
      );
    }
    return Image.memory(
      _bytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}