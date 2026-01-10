import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SteamApiKeyWebViewPage extends StatefulWidget {
  final String? initialApiKey;
  final void Function(String apiKey)? onApiKeyFound;

  const SteamApiKeyWebViewPage({
    super.key,
    this.initialApiKey,
    this.onApiKeyFound,
  });

  @override
  State<SteamApiKeyWebViewPage> createState() => _SteamApiKeyWebViewPageState();
}

class _SteamApiKeyWebViewPageState extends State<SteamApiKeyWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _foundApiKey;
  bool _hasNotifiedUser = false;
  Timer? _pollingTimer;

  static const String _apiKeyUrl = 'https://steamcommunity.com/dev/apikey';

  @override
  void initState() {
    super.initState();
    _foundApiKey = widget.initialApiKey;
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _tryExtractApiKey();
            _startPolling();
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null &&
                change.url!.contains('steamcommunity.com/dev/apikey')) {
              Future.delayed(const Duration(milliseconds: 500), () {
                _tryExtractApiKey();
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_apiKeyUrl));
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // 每2秒检测一次，直到找到 API Key
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_foundApiKey != null) {
        timer.cancel();
        return;
      }
      _tryExtractApiKey();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryExtractApiKey() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          var container = document.getElementById('bodyContents_ex');
          if (container) {
            var paragraphs = container.getElementsByTagName('p');
            for (var i = 0; i < paragraphs.length; i++) {
              var text = paragraphs[i].textContent || paragraphs[i].innerText;
              if (text.indexOf('密钥') !== -1 || text.indexOf('Key') !== -1) {
                var match = text.match(/[A-F0-9]{32}/i);
                if (match) {
                  return match[0];
                }
              }
            }
          }
          return '';
        })();
      ''');

      String apiKey = result.toString();
      apiKey = apiKey.replaceAll('"', '').replaceAll("'", '');

      if (apiKey.isNotEmpty && apiKey.length == 32) {
        setState(() {
          _foundApiKey = apiKey;
        });

        widget.onApiKeyFound?.call(apiKey);

        if (!_hasNotifiedUser && mounted) {
          _hasNotifiedUser = true;
          _showApiKeyFoundSnackBar(apiKey);
        }
      }
    } catch (e) {
      debugPrint('Failed to extract API Key: $e');
    }
  }

  void _showApiKeyFoundSnackBar(String apiKey) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已找到 API Key: ${apiKey.substring(0, 8)}...'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '使用此 Key',
          onPressed: () {
            Navigator.of(context).pop(apiKey);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam API Key'),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
        actions: [
          if (_foundApiKey != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(_foundApiKey);
              },
              icon: const Icon(Icons.check),
              label: const Text('使用'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_foundApiKey != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已获取 API Key: ${_foundApiKey!.substring(0, 8)}...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
