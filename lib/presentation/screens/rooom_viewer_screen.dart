import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'rooom_viewer_platform/stub.dart'
    if (dart.library.html) 'rooom_viewer_platform/web.dart';

class RooomViewerScreen extends StatefulWidget {
  final String modelUrl;
  final String? usdzUrl;
  final String? annotationsUrl;

  const RooomViewerScreen({
    super.key,
    required this.modelUrl,
    this.usdzUrl,
    this.annotationsUrl,
  });

  @override
  State<RooomViewerScreen> createState() => _RooomViewerScreenState();
}

class _RooomViewerScreenState extends State<RooomViewerScreen> {
  late final WebViewController controller;

  Uri _buildViewerUrl() {
    final buffer = StringBuffer(
      'https://$rooomViewerHost$rooomViewerPath'
      '?middleware=dlf/embedded3dviewer'
      '&model=${Uri.encodeQueryComponent(widget.modelUrl)}',
    );
    if (widget.usdzUrl != null) {
      buffer.write('&usdz=${Uri.encodeQueryComponent(widget.usdzUrl!)}');
    }
    if (widget.annotationsUrl != null) {
      buffer.write(
        '&annotations=${Uri.encodeQueryComponent(widget.annotationsUrl!)}',
      );
    }
    buffer.write('&viewer');
    return Uri.parse(buffer.toString());
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[RooomViewer] kIsWeb=$kIsWeb url=${_buildViewerUrl()}');
    if (!kIsWeb) {
      controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onWebResourceError: (error) {
                  debugPrint(
                    '[RooomViewer] Error ${error.errorCode}: ${error.description} — url: ${error.url}',
                  );
                },
                onNavigationRequest: (request) {
                  final url = request.url;
                  if (url.startsWith('intent://') || url.endsWith('.usdz')) {
                    _launchExternalUrl(url);
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            )
            ..loadRequest(_buildViewerUrl());

      if (controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(true);
      }
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visor 3D'), centerTitle: true),
        body: buildWebViewer(_buildViewerUrl().toString()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Visor 3D'), centerTitle: true),
      body: WebViewWidget(controller: controller),
    );
  }
}
