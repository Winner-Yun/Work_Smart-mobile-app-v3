class AppConfigModel {
  final String cdnApiKey;
  final String cdnApiSecret;
  final String cdnCloudName;
  final String googleMapsApiKey;

  AppConfigModel({
    required this.cdnApiKey,
    required this.cdnApiSecret,
    required this.cdnCloudName,
    required this.googleMapsApiKey,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      cdnApiKey: json['cdn_api_key']?.toString() ?? '',
      cdnApiSecret: json['cdn_api_secret']?.toString() ?? '',
      cdnCloudName: json['cdn_cloud_name']?.toString() ?? '',
      googleMapsApiKey: json['google_maps_api_key']?.toString() ?? '',
    );
  }
}
