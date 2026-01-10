import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class SteamAccountWebViewPage extends StatefulWidget {
  final String? initialSteamId;
  final void Function(String steamId)? onSteamIdFound;

  const SteamAccountWebViewPage({
    super.key,
    this.initialSteamId,
    this.onSteamIdFound,
  });

  @override
  State<SteamAccountWebViewPage> createState() => _SteamAccountWebViewPageState();
}

class _SteamAccountWebViewPageState extends State<SteamAccountWebViewPage> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _foundSteamId;

  static const String _accountUrl = 'https://store.steampowered.com/account/';

  @override
  void initState() {
    super.initState();
    _foundSteamId = widget.initialSteamId;
  }

  Future<void> _tryExtractSteamId() async {
    if (_controller == null) return;

    try {
      final result = await _controller!.evaluateJavascript(source: '''
        (function() {
          var element = document.querySelector('.youraccount_steamid');
          if (element) {
            var text = element.textContent || element.innerText;
            var match = text.match(/\\d{17}/);
            if (match) {
              return match[0];
            }
          }
          return '';
        })();
      ''');

      String steamId = result?.toString() ?? '';
      steamId = steamId.replaceAll('"', '').replaceAll("'", '');

      if (steamId.isNotEmpty && steamId.length == 17) {
        setState(() {
          _foundSteamId = steamId;
        });
        widget.onSteamIdFound?.call(steamId);
      }
    } catch (e) {
      debugPrint('Failed to extract Steam ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam 账户'),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
        actions: [
          if (_foundSteamId != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(_foundSteamId);
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
            color: _foundSteamId != null
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _foundSteamId != null ? Icons.check_circle : Icons.info_outline,
                  color: _foundSteamId != null
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _foundSteamId != null
                        ? '已获取 Steam ID: $_foundSteamId'
                        : '请登录 Steam 账户，系统会自动获取 Steam ID',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _foundSteamId != null
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
              initialUrlRequest: URLRequest(url: WebUri(_accountUrl)),
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
                _tryExtractSteamId();
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                if (url != null &&
                    url.toString().contains('store.steampowered.com/account')) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _tryExtractSteamId();
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
