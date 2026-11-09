import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo_models.dart';
import 'demo_widgets.dart';

class ScenariosPage extends StatefulWidget {
  const ScenariosPage({super.key});

  @override
  State<ScenariosPage> createState() => _ScenariosPageState();
}

class _ScenariosPageState extends State<ScenariosPage> {
  DemoResult? _result;
  bool _loading = false;
  String? _runningTitle;

  List<_Recipe> get _recipes => [
        _Recipe(
          title: '缓存优先',
          subtitle: '第一次请求网络并写入缓存，第二次通常直接命中本地缓存。',
          icon: Icons.savings_outlined,
          accent: const Color(0xFFEA580C),
          code: '''final result = await RxNet.get()
    .setPath('/posts/1')
    .setCacheMode(
      CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
    )
    .request();

// result.model == SourcesType.cache
// 表示本次结果来自缓存''',
          run: runCacheSample,
        ),
        _Recipe(
          title: '并发请求',
          subtitle: '同时发起 3 个请求，用 Future.wait 聚合，适合首屏多接口并行加载。',
          icon: Icons.speed,
          accent: const Color(0xFF2563EB),
          code: '''final results = await Future.wait([
  RxNet.get().setPath('/posts/1').request(),
  RxNet.get().setPath('/posts/2').request(),
  RxNet.get().setPath('/posts/3').request(),
]);

final first = results[0].value;''',
          run: runConcurrentSample,
        ),
        _Recipe(
          title: '自定义 Header',
          subtitle: '为单个请求追加追踪 ID、客户端标识等 Header，不影响全局配置。',
          icon: Icons.tune,
          accent: const Color(0xFF7C3AED),
          code: '''final result = await RxNet.get()
    .setPath('/posts/1')
    .setHeader('X-Client', 'rxnet-playground')
    .setHeader('X-Trace-Id', 'demo-001')
    .request();''',
          run: () => runSampleRequest(
            HttpMethod.GET,
            path: '/posts/1',
            query: const {},
            headers: const {
              'X-Client': 'rxnet-playground',
              'X-Trace-Id': 'demo-001',
            },
          ),
        ),
        _Recipe(
          title: 'Multipart 上传',
          subtitle: '使用内存字节构造 MultipartFile，Web 与 IO 平台都可运行。',
          icon: Icons.upload_file_outlined,
          accent: const Color(0xFF16A34A),
          code: '''final file = MultipartFile.fromBytes(
  utf8.encode('Hello RxNet'),
  filename: 'demo.txt',
);

final result = await RxNet.post()
    .setPath('/posts')
    .setBodyParams({'title': 'Upload'})
    .setBodyParam('file', file)
    .asFormData()
    .request();''',
          run: runMultipartSample,
        ),
        _Recipe(
          title: '错误与重试策略',
          subtitle: '默认只重试超时/连接错误、5xx、408、429；4xx 与取消不会重试。',
          icon: Icons.replay_circle_filled_outlined,
          accent: const Color(0xFFDC2626),
          code: '''final result = await RxNet.get()
    .setPath('/posts/999999')
    .setRetryCount(
      2,
      interval: const Duration(milliseconds: 300),
    )
    .request();

// 404 不会触发重试，直接返回错误结果''',
        ),
        _Recipe(
          title: '取消与超时',
          subtitle: 'UI 离开或用户点击取消时，取消 CancelToken 可终止请求等待。',
          icon: Icons.timer_off_outlined,
          accent: const Color(0xFF0F766E),
          code: '''final cancelToken = CancelToken();

final future = RxNet.get()
    .setPath('/posts/1')
    .setConnectTimeout(const Duration(seconds: 5))
    .setReceiveTimeout(const Duration(seconds: 10))
    .setCancelToken(cancelToken)
    .request();

// 取消
cancelToken.cancel('用户取消');''',
        ),
        _Recipe(
          title: 'Token 刷新后重试',
          subtitle: '401 时刷新 Token，并通过 ErrorInterceptorHandler.retry 真正重发原请求。',
          icon: Icons.vpn_key_outlined,
          accent: const Color(0xFF4F46E5),
          code: '''TokenRefreshInterceptor(
  tokenProvider: () async {
    final response = await refreshTokenApi.request();
    return response.value!;
  },
  onRequestUpdated: (request, token) {
    return request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer \$token',
      },
    );
  },
)''',
        ),
      ];

  Future<void> _run(_Recipe recipe) async {
    final runner = recipe.run;
    if (runner == null || _loading) return;

    setState(() {
      _loading = true;
      _runningTitle = recipe.title;
      _result = null;
    });

    final result = await runner();
    if (!mounted) return;

    setState(() {
      _result = result;
      _loading = false;
      _runningTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final cardWidth =
            wide ? (constraints.maxWidth - 36) / 2 : constraints.maxWidth;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 28 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemoPageHeader(
                title: '场景配方',
                subtitle: '缓存、并发、上传、重试、取消与 Token 刷新等常见场景，'
                    '可直接运行或复制代码。',
                icon: Icons.auto_awesome_outlined,
              ),
              if (_loading || _result != null) ...[
                ResultPanel(
                  result: _result,
                  loading: _loading,
                  emptyHint: _runningTitle == null
                      ? '运行场景后展示结果。'
                      : '正在运行：$_runningTitle',
                ),
                const SizedBox(height: 18),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _recipes
                    .map(
                      (recipe) => SizedBox(
                        width: cardWidth,
                        child: _buildRecipeCard(context, recipe),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(BuildContext context, _Recipe recipe) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = _loading && _runningTitle == recipe.title;

    return Card(
      elevation: 0,
      color: scheme.surface.withAlpha(238),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: recipe.accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(recipe.icon, color: recipe.accent, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InfoPill(
                  label: recipe.run == null ? '代码示例' : '可运行',
                  color: recipe.run == null ? scheme.outline : recipe.accent,
                  icon: recipe.run == null ? Icons.code : Icons.play_arrow,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              recipe.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            CodeBlock(code: recipe.code, label: 'Recipe'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: recipe.run == null
                  ? Text(
                      '复制代码即可使用',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: running ? null : () => _run(recipe),
                      icon: running
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(running ? '运行中…' : '运行场景'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recipe {
  const _Recipe({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.code,
    this.run,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String code;
  final Future<DemoResult> Function()? run;
}