# work_path_test（工作轨迹记录 App · 测试版）

基于 **Flutter** 开发的移动端轨迹记录应用：登录后通过 GPS 采集轨迹坐标，本地存储轨迹数据，并在地图上回放轨迹路线（蓝色路径 + 起终点标记）。

> 当前为**测试版**：账号体系使用内置账号，数据存储在本地 SQLite，暂未接入后端服务。

---

## 功能特性

- **登录 / 登出**：内置账号校验，登录态本地持久化（`shared_preferences`），退出登录自动返回登录页
- **轨迹录制**：基于 `geolocator` 采集 GPS 坐标，实时显示录制时长与坐标点数
- **地图回放**：集成高德地图（AMap 3D SDK 11.2.100），展示蓝色轨迹路径、绿色起点标记、红色终点标记
- **轨迹管理**：
  - 首页「我的轨迹」展示最近 3 条轨迹
  - 「我的」页面：个人信息、全部轨迹、设置三个入口
  - 轨迹详情页：地图回放 + 坐标点滚动列表
- **数据本地化**：SQLite（`sqflite`）存储轨迹与坐标点

## 内置账号（测试版）

| 用户名 | 密码 |
|---|---|
| `admin` | `123456` |

## 技术栈

| 模块 | 技术 |
|---|---|
| 跨平台框架 | Flutter |
| 本地数据库 | sqflite（`track`、`track_point` 两张表） |
| 定位 | geolocator（GPS 坐标采集） |
| 地图 | 高德地图 SDK 11.2.100（amap_flutter_map 本地插件副本） |
| 登录态 | shared_preferences |

## 环境要求

- Flutter SDK ≥ 3.13（本项目使用 Flutter 3.47，需支持 `hooks` 配置）
- Android SDK（构建 Android 端）
- 高德开放平台账号（用于申请地图 API Key）

## 构建步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 配置高德 API Key（见下文）

# 3. 构建 release APK
flutter build apk --release
# 产物路径：build/app/outputs/flutter-apk/app-release.apk
```

## 高德 API Key 配置

出于安全考虑，API Key **不提交到仓库**，通过本地配置文件注入。

1. 在高德开放平台申请 Key，绑定：
   - PackageName：`com.example.work_path_test`
   - SHA1（调试/发布版）：`46:D2:87:E8:8B:D3:D5:BF:3C:F1:56:EA:2E:C4:AB:B0:C1:82:47:5`
2. 编辑 `android/local.properties`（该文件已被 .gitignore 忽略），添加：

```properties
AMAP_API_KEY=你的高德Key
```

3. 构建时 Gradle 会将该 Key 注入 `AndroidManifest.xml` 的 `com.amap.api.v2.apikey` 占位符。

> 若未配置，构建不会报错，但地图因 Key 无效而无法加载。

### Dart 侧同样需要注入

Flutter 的 `amap_flutter_map` 插件在 Widget 构造时还会读一次 key，所以**除 Gradle 外，运行/构建时还要带 `--dart-define`**：

```bash
flutter run --dart-define=AMAP_KEY=你的高德Key
flutter build apk --release --dart-define=AMAP_KEY=你的高德Key
```

Dart 侧从 `lib/config/api_config.dart` 的 `ApiConfig.amapKey` 读取该值。**不要把 key 写死在源码里**——key 是账号级凭据，一旦进 git 历史就只能去高德控制台重置才能真正止损。未带 `--dart-define` 时，轨迹详情页会明确提示"未配置高德地图 key"，不会静默显示空白地图。

## 注意事项

- **高德 SDK 仅支持 ARM 架构**：x86 模拟器无法显示地图，请使用真机调试
- **release 构建禁用 R8 压缩**：高德 SDK 通过 JNI `FindClass` 引用类，R8 收缩会删除这些类导致崩溃（`java_class == null`），因此 release 的 `isMinifyEnabled` 已设为 `false`，APK 体积较大属正常现象
- **高德 SDK 11.2.100 适配 Android 14/15/16**：旧版（8.x/9.x）在 Android 16 上会因加固壳不兼容而崩溃
- 首次使用需授予定位权限，否则无法采集轨迹

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型（Track、TrackPoint）
├── pages/                    # 页面（登录、首页、录制、详情、我的等）
├── services/                 # 业务服务（AuthService、TrackDatabase）
└── utils/                    # 工具（坐标转换等）
third_party/                  # 高德 Flutter 插件本地副本（修复兼容性问题）
```

## 许可证

本项目代码采用 [MIT License](LICENSE) 开源。

> 注意：项目集成的**高德地图 SDK（含定位）为高德（AMap）商业产品**，归其所有者所有，受高德自身许可条款约束；MIT 许可仅适用于本项目自研代码，不覆盖高德 SDK 及其商标。

## 已知限制（测试版）

- 账号固定为内置 `admin / 123456`，未接入真实用户体系
- 轨迹数据仅保存在本机，删除 App 即丢失
- 坐标采集未做运动状态过滤，静止时也会记录重复点
