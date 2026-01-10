import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _foundApiKey;
  Timer? _pollingTimer;

  static const String _apiKeyUrl = 'https://steamcommunity.com/dev/apikey';

  @override
  void initState() {
    super.initState();
    if (widget.initialApiKey != null && widget.initialApiKey!.length == 32) {
      _foundApiKey = widget.initialApiKey;
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
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
    if (_controller == null) return;

    try {
      final result = await _controller!.evaluateJavascript(source: '''
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

      String apiKey = result?.toString() ?? '';
      apiKey = apiKey.replaceAll('"', '').replaceAll("'", '');

      if (apiKey.isNotEmpty && apiKey.length == 32) {
        setState(() {
          _foundApiKey = apiKey;
        });
        widget.onApiKeyFound?.call(apiKey);
      }
    } catch (e) {
      debugPrint('Failed to extract API Key: $e');
    }
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _foundApiKey != null
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _foundApiKey != null ? Icons.check_circle : Icons.info_outline,
                  color: _foundApiKey != null
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _foundApiKey != null
                        ? '已获取 API Key: $_foundApiKey'
                        : '请登录并注册 API Key，系统会自动获取',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _foundApiKey != null
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_apiKeyUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                _tryExtractApiKey();
                _startPolling();
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                if (url != null &&
                    url.toString().contains('steamcommunity.com/dev/apikey')) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _tryExtractApiKey();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
