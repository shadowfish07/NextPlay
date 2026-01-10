import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _foundSteamId;
  bool _hasNotifiedUser = false;

  static const String _accountUrl = 'https://store.steampowered.com/account/';

  @override
  void initState() {
    super.initState();
    _foundSteamId = widget.initialSteamId;
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
            // 页面加载完成后尝试提取 Steam ID
            _tryExtractSteamId();
          },
          onUrlChange: (UrlChange change) {
            // 监听 URL 变化，处理登录后跳转的情况
            if (change.url != null && change.url!.contains('store.steampowered.com/account')) {
              // 用户可能刚登录完成，延迟一下再提取
              Future.delayed(const Duration(milliseconds: 500), () {
                _tryExtractSteamId();
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_accountUrl));
  }

  Future<void> _tryExtractSteamId() async {
    try {
      // 使用 JavaScript 提取 Steam ID
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          var element = document.querySelector('.youraccount_steamid');
          if (element) {
            var text = element.textContent || element.innerText;
            // 提取数字部分 (Steam ID 是 17 位数字)
            var match = text.match(/\\d{17}/);
            if (match) {
              return match[0];
            }
          }
          return '';
        })();
      ''');

      // 处理返回结果
      String steamId = result.toString();
      // 移除引号（JavaScript 返回的字符串可能带引号）
      steamId = steamId.replaceAll('"', '').replaceAll("'", '');

      if (steamId.isNotEmpty && steamId.length == 17) {
        setState(() {
          _foundSteamId = steamId;
        });

        // 通知回调
        widget.onSteamIdFound?.call(steamId);

        // 显示提示
        if (!_hasNotifiedUser && mounted) {
          _hasNotifiedUser = true;
          _showSteamIdFoundSnackBar(steamId);
        }
      }
    } catch (e) {
      // 提取失败，可能是页面还没完全加载或用户未登录
      debugPrint('Failed to extract Steam ID: $e');
    }
  }

  void _showSteamIdFoundSnackBar(String steamId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已找到 Steam ID: $steamId'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '使用此 ID',
          onPressed: () {
            Navigator.of(context).pop(steamId);
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
          // Steam ID 状态提示条
          if (_foundSteamId != null)
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
                      '已获取 Steam ID: $_foundSteamId',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
