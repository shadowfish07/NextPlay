class Env {
  static const String igdbClientId = String.fromEnvironment('IGDB_CLIENT_ID', defaultValue: '');
  static const String igdbClientSecret = String.fromEnvironment('IGDB_CLIENT_SECRET', defaultValue: '');
  
  static const String steamApiBaseUrl = 'https://api.steampowered.com';
  static const String igdbApiBaseUrl = 'https://api.igdb.com/v4';
  
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
}