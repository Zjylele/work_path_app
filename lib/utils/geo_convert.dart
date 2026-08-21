import 'dart:math';

/// WGS-84（GPS 原始坐标）→ GCJ-02（国内地图加密坐标）转换
///
/// 高德/腾讯等国内地图使用 GCJ-02 坐标系，
/// geolocator 采集到的是 WGS-84，直接绘制会产生偏移（约几百米），
/// 绘制前必须经过本工具转换。
class GeoConvert {
  GeoConvert._();

  /// 地球长半轴（米）
  static const double _a = 6378245.0;

  /// 偏心率平方
  static const double _ee = 0.00669342162296594323;

  static bool _outOfChina(double lat, double lng) {
    if (lng < 72.004 || lng > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  static double _transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret +=
        (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    var ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret +=
        (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return ret;
  }

  /// WGS-84 → GCJ-02，返回 (lat, lng)
  static ({double lat, double lng}) wgs84ToGcj02(double lat, double lng) {
    // 超出中国范围不偏移
    if (_outOfChina(lat, lng)) return (lat: lat, lng: lng);

    var dLat = _transformLat(lng - 105.0, lat - 35.0);
    var dLng = _transformLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * pi;
    var magic = sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * cos(radLat) * pi);
    return (lat: lat + dLat, lng: lng + dLng);
  }
}
