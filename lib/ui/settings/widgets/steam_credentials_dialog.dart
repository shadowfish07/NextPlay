import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SteamCredentialsDialog extends StatefulWidget {
  final String currentApiKey;
  final String currentSteamId;
  final Function(String apiKey, String steamId) onSave;

  const SteamCredentialsDialog({
    super.key,
    required this.currentApiKey,
    required this.currentSteamId,
    required this.onSave,
  });

  @override
  State<SteamCredentialsDialog> createState() => _SteamCredentialsDialogState();
}

class _SteamCredentialsDialogState extends State<SteamCredentialsDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _steamIdController;
  bool _isApiKeyVisible = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.currentApiKey);
    _steamIdController = TextEditingController(text: widget.currentSteamId);
    _checkValid();
    
    _apiKeyController.addListener(_checkValid);
    _steamIdController.addListener(_checkValid);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _steamIdController.dispose();
    super.dispose();
  }

  void _checkValid() {
    setState(() {
      _isValid = _apiKeyController.text.trim().isNotEmpty && 
                 _steamIdController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('更新 Steam 凭据'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入您的 Steam API Key 和 Steam ID',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            
            // API Key Field
            TextField(
              controller: _apiKeyController,
              obscureText: !_isApiKeyVisible,
              decoration: InputDecoration(
                labelText: 'Steam API Key',
                hintText: '输入您的 Steam API Key',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isApiKeyVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isApiKeyVisible = !_isApiKeyVisible;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: _showApiKeyHelp,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Steam ID Field
            TextField(
              controller: _steamIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Steam ID',
                hintText: '输入您的 Steam ID（纯数字）',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showSteamIdHelp,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isValid ? _handleSave : null,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _handleSave() {
    final apiKey = _apiKeyController.text.trim();
    final steamId = _steamIdController.text.trim();
    
    widget.onSave(apiKey, steamId);
    Navigator.of(context).pop();
  }

  void _showApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('如何获取 Steam API Key'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 访问 Steam Web API 页面：'),
            SelectableText('https://steamcommunity.com/dev/apikey'),
            SizedBox(height: 8),
            Text('2. 使用您的 Steam 账户登录'),
            SizedBox(height: 8),
            Text('3. 填写域名（可以填写 localhost）'),
            SizedBox(height: 8),
            Text('4. 同意条款并获取您的 API Key'),
            SizedBox(height: 8),
            Text('5. 复制 API Key 并粘贴到上方输入框'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showSteamIdHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('如何获取 Steam ID'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('方法一：从个人资料页面获取'),
            SizedBox(height: 8),
            Text('1. 打开您的 Steam 个人资料页面'),
            Text('2. 查看浏览器地址栏中的数字ID'),
            Text('3. 例如：steamcommunity.com/profiles/76561198000000000'),
            SizedBox(height: 16),
            Text('方法二：使用在线工具'),
            SizedBox(height: 8),
            Text('1. 访问 steamid.io 或类似网站'),
            Text('2. 输入您的 Steam 用户名'),
            Text('3. 获取 SteamID64 (17位数字)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}