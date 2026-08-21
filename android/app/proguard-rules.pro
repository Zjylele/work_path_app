# 高德地图 SDK 混淆保留规则（官方要求）
-keep class com.amap.api.maps.**{*;}
-keep class com.autonavi.amap.mapcore.**{*;}
-keep class com.amap.api.trace.**{*;}
-keep class com.amap.api.maps.model.**{*;}
-keep class com.amap.api.services.**{*;}

# 高德定位 SDK 混淆保留规则（官方要求）
-keep class com.amap.api.location.**{*;}
-keep class com.amap.api.fence.**{*;}
-keep class com.autonavi.aps.amapapi.model.**{*;}

# GNSS 软定位组件不在合包内，忽略缺失警告（非核心定位路径）
-dontwarn com.amap.ams.gnss.GnssSoftLocator
