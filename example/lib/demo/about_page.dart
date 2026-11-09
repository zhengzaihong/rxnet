import 'package:flutter/material.dart';

import '../enhanced_example.dart';
import 'demo_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.swap_horiz,
      title: '双适配器',
      description: 'DioAdapter 与轻量 HttpAdapter 行为一致，可随时替换。',
    ),
    _Feature(
      icon: Icons.devices,
      title: '全平台',
      description: 'Android / iOS / Windows / macOS / Linux / Web / HarmonyOS。',
    ),
    _Feature(
      icon: Icons.savings_outlined,
      title: '持久化缓存',
      description: 'sembast IO / Web 双实现，支持 TTL、容量上限与 LRU/LFU/FIFO。',
    ),
    _Feature(
      icon: Icons.layers_outlined,
      title: '拦截器体系',
      description: '日志、Token 刷新、去重、节流；支持同步与异步拦截器。',
    ),
    _Feature(
      icon: Icons.timer_outlined,
      title: '超时/重试/取消',
      description: '连接、发送、接收独立超时；可重试过滤与 CancelToken。',
    ),
    _Feature(
      icon: Icons.speed,
      title: '并发与多实例',
      description: 'zipRequest 并发聚合，多实例隔离配置与缓存。',
    ),
    _Feature(
      icon: Icons.shield_outlined,
      title: '安全默认值',
      description: '日志默认关闭并脱敏 Authorization/Cookie/PII/URL token。',
    ),
    _Feature(
      icon: Icons.cloud_download_outlined,
      title: '上传与下载',
      description: '支持 FormData、文件上传下载、断点续传（平台能力不同）。',
    ),
  ];

  static const _methods = <_MethodRow>[
    _MethodRow('GET', '查询资源', '幂等', '无 Body'),
    _MethodRow('POST', '创建资源', '非幂等', 'JSON / Form'),
    _MethodRow('PUT', '全量更新', '幂等', 'JSON / Form'),
    _MethodRow('PATCH', '局部更新', '非幂等', 'JSON'),
    _MethodRow('DELETE', '删除资源', '幂等', '无 Body'),
    _MethodRow('HEAD', '读取响应头', '幂等', '无 Body'),
    _MethodRow('OPTIONS', '探测能力', '幂等', '无 Body'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final featureWidth =
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
                title: '关于 RxNet',
                subtitle: '一个全平台、双适配器、可插拔拦截器的 Flutter 网络请求框架。',
                icon: Icons.info_outline,
              ),
              DemoSectionCard(
                title: '平台与版本',
                subtitle: 'RxNet Plus 0.7.2 · Flutter 3.24+ / Dart 3.5+',
                icon: Icons.devices_other,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    InfoPill(
                      label: 'Android',
                      color: Color(0xFF16A34A),
                      icon: Icons.android,
                    ),
                    InfoPill(
                      label: 'iOS',
                      color: Color(0xFF2563EB),
                      icon: Icons.phone_iphone,
                    ),
                    InfoPill(
                      label: 'Windows',
                      color: Color(0xFF0F766E),
                      icon: Icons.desktop_windows_outlined,
                    ),
                    InfoPill(
                      label: 'macOS',
                      color: Color(0xFF475569),
                      icon: Icons.laptop_mac,
                    ),
                    InfoPill(
                      label: 'Linux',
                      color: Color(0xFFEA580C),
                      icon: Icons.terminal,
                    ),
                    InfoPill(
                      label: 'Web',
                      color: Color(0xFF7C3AED),
                      icon: Icons.public,
                    ),
                    InfoPill(
                      label: 'HarmonyOS',
                      color: Color(0xFFDC2626),
                      icon: Icons.devices_other,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _features
                    .map(
                      (feature) => SizedBox(
                        width: featureWidth,
                        child: _FeatureCard(feature: feature),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              DemoSectionCard(
                title: '请求方法速查',
                subtitle: '幂等性影响库的自动重试策略',
                icon: Icons.table_chart_outlined,
                child: Column(
                  children: [
                    for (final row in _methods)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 82,
                              child: Text(
                                row.method,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Expanded(child: Text(row.description)),
                            InfoPill(
                              label: row.idempotent,
                              color: row.idempotent == '幂等'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 8),
                            InfoPill(
                              label: row.body,
                              color: const Color(0xFF2563EB),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DemoSectionCard(
                title: '更多示例',
                subtitle: '旧版增强示例包含更多 API、多实例、文件与表单场景',
                icon: Icons.history_edu_outlined,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EnhancedExample(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('打开 Legacy 示例'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Built with Flutter · RxNet Plus',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface.withAlpha(238),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(160),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(feature.icon, size: 19, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodRow {
  const _MethodRow(this.method, this.description, this.idempotent, this.body);

  final String method;
  final String description;
  final String idempotent;
  final String body;
}