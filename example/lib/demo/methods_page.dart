import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo_models.dart';
import 'demo_widgets.dart';

class MethodsPage extends StatefulWidget {
  const MethodsPage({super.key});

  @override
  State<MethodsPage> createState() => _MethodsPageState();
}

class _MethodsPageState extends State<MethodsPage> {
  DemoResult? _result;
  bool _loading = false;
  HttpMethod? _running;

  Future<void> _run(HttpMethod method) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _running = method;
      _result = null;
    });

    final result = await runSampleRequest(method);
    if (!mounted) return;

    setState(() {
      _result = result;
      _loading = false;
      _running = null;
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
                title: '请求方法详解',
                subtitle: 'GET、POST、PUT、PATCH、DELETE、HEAD、OPTIONS 的语义、'
                    '幂等性与示例代码，并可一键运行。',
                icon: Icons.swap_horiz_outlined,
              ),
              if (_loading || _result != null) ...[
                ResultPanel(
                  result: _result,
                  loading: _loading,
                  emptyHint: '选择下方请求方法运行示例。',
                ),
                const SizedBox(height: 18),
              ] else ...[
                DemoSectionCard(
                  title: '选择请求方法',
                  subtitle: '每个卡片都使用 jsonplaceholder.typicode.com 的公开接口',
                  icon: Icons.info_outline,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _methodInfos
                        .map(
                          (info) => InfoPill(
                            label: info.method.name.toUpperCase(),
                            color: methodColor(info.method),
                            icon: info.icon,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _methodInfos
                    .map(
                      (info) => SizedBox(
                        width: cardWidth,
                        child: _buildMethodCard(context, info),
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

  Widget _buildMethodCard(BuildContext context, _MethodInfo info) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = _loading && _running == info.method;

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
                MethodBadge(info.method),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(info.icon, color: methodColor(info.method), size: 22),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              info.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoPill(
                  label: info.idempotent ? '幂等' : '非幂等',
                  color: info.idempotent
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEA580C),
                  icon: info.idempotent ? Icons.repeat : Icons.warning_amber,
                ),
                InfoPill(
                  label: info.supportsBody ? '支持 Body' : '无 Body',
                  color: info.supportsBody
                      ? const Color(0xFF2563EB)
                      : scheme.outline,
                  icon: info.supportsBody
                      ? Icons.data_object
                      : Icons.block_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            CodeBlock(code: info.code, label: '示例'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: running ? null : () => _run(info.method),
                icon: running
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(running ? '运行中…' : '运行示例'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodInfo {
  const _MethodInfo({
    required this.method,
    required this.title,
    required this.description,
    required this.idempotent,
    required this.supportsBody,
    required this.icon,
    required this.code,
  });

  final HttpMethod method;
  final String title;
  final String description;
  final bool idempotent;
  final bool supportsBody;
  final IconData icon;
  final String code;
}

const _methodInfos = <_MethodInfo>[
  _MethodInfo(
    method: HttpMethod.GET,
    title: '查询资源',
    description: '最常用的读取操作。参数放在 Query 中，适合分页、筛选、搜索。',
    idempotent: true,
    supportsBody: false,
    icon: Icons.search,
    code: '''final result = await RxNet.get()
    .setPath('/posts')
    .setQueryParams({'userId': 1})
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.POST,
    title: '创建资源',
    description: '提交 JSON / FormData 创建资源。默认不自动重试，避免重复创建。',
    idempotent: false,
    supportsBody: true,
    icon: Icons.add_circle_outline,
    code: '''final result = await RxNet.post()
    .setPath('/posts')
    .setBodyParams({
      'title': 'RxNet',
      'userId': 1,
    })
    .asJson()
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.PUT,
    title: '全量更新',
    description: '用完整资源替换目标资源，语义上是幂等的，可安全重试。',
    idempotent: true,
    supportsBody: true,
    icon: Icons.edit_outlined,
    code: '''final result = await RxNet.put()
    .setPath('/posts/1')
    .setBodyParams({'title': 'Updated'})
    .asJson()
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.PATCH,
    title: '局部更新',
    description: '只提交需要修改的字段。与 POST 一样默认不自动重试。',
    idempotent: false,
    supportsBody: true,
    icon: Icons.auto_fix_high,
    code: '''final result = await RxNet.patch()
    .setPath('/posts/1')
    .setBodyParams({'title': 'Patched'})
    .asJson()
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.DELETE,
    title: '删除资源',
    description: '删除指定资源，幂等。RxNet 会把 DELETE 的 body 参数转成 Query。',
    idempotent: true,
    supportsBody: false,
    icon: Icons.delete_outline,
    code: '''final result = await RxNet.delete()
    .setPath('/posts/1')
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.HEAD,
    title: '读取响应头',
    description: '与 GET 类似但只返回响应头，常用于探测资源是否存在。',
    idempotent: true,
    supportsBody: false,
    icon: Icons.visibility_outlined,
    code: '''final result = await RxNet.head()
    .setPath('/posts/1')
    .request();''',
  ),
  _MethodInfo(
    method: HttpMethod.OPTIONS,
    title: '探测支持能力',
    description: '了解服务端允许的方法；浏览器跨域预检也会使用 OPTIONS。',
    idempotent: true,
    supportsBody: false,
    icon: Icons.settings_ethernet,
    code: '''final result = await RxNet.options()
    .setPath('/posts/1')
    .request();''',
  ),
];