import 'dart:io';

import 'package:flutter/foundation.dart';

/// 后端 API 地址配置
class ApiConfig {
  ApiConfig._();

  /// 打包时通过 `--dart-define=API_BASE_URL=https://你的域名` 注入的地址。
  /// 不注入则为空，走平台默认判断。
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 手动覆盖后端地址（真机调试临时用，改完记得改回空串 ''）
  static const String overrideBaseUrl = 'http://8.210.87.189';

  /// 当前生效的后端 baseUrl（优先级：overrideBaseUrl > API_BASE_URL > 平台默认）
  static String get baseUrl {
    if (overrideBaseUrl.isNotEmpty) {
      return overrideBaseUrl;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// 高德开放平台 key，打包时通过 `--dart-define=AMAP_KEY=你的key` 注入。
  ///
  /// <p>为什么不让它留一个字面量：key 是账号级凭据，写进源码等于跟着仓库
  /// 一起公开。历史上这里曾硬编码过一个 Android key，该值已进入 git 历史，
  /// 只能去高德控制台重置才能真正止损——源码里改成注入方式是为了不再扩散。</p>
  static const String amapKey = String.fromEnvironment('AMAP_KEY');

  /// 高德 key 是否已配置。未配置时地图页应向用户说明，而不是静默显示空白地图。
  static bool get hasAmapKey => amapKey.isNotEmpty;
}

