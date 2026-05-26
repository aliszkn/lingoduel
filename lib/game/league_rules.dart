import 'league_models.dart';

/// LP ve oda erişim kurallarını uygulayan sınıf.
///
/// Tüm metodlar statik — durum tutmaz, bağımsız test edilebilir.
class LeagueRules {
  LeagueRules._();

  // ─── Harf Grubu ──────────────────────────────────────────────────────────

  /// Oyuncunun güncel LP'sine göre ait olduğu harf grubunu döner.
  ///
  /// Harf sınırının altına düşüldüğü an grup geriye döner (anlık etki).
  static LeagueGroup groupOf(int lp) {
    if (lp >= 2100) return LeagueGroup.C;
    if (lp >= 1100) return LeagueGroup.B;
    return LeagueGroup.A;
  }

  // ─── Oda Açma (Create) ───────────────────────────────────────────────────

  /// Oyuncunun AÇABİLECEĞİ en yüksek seviyeli odayı döner.
  ///
  /// LP düştüğünde yetki anında geriye döner; kalıcı mezuniyet yoktur.
  static RoomDefinition maxCreatableRoom(int lp) {
    // kAllRooms levelIndex'e göre artan sırada → son uygun eleman en yüksek
    return kAllRooms.lastWhere(
      (r) => r.createThreshold <= lp,
      orElse: () => kAllRooms.first,
    );
  }

  /// Oyuncunun belirtilen odayı açıp açamayacağını döner.
  static bool canCreate(int lp, RoomDefinition room) =>
      lp >= room.createThreshold;

  /// Oyuncunun açabileceği tüm oda listesi.
  static List<RoomDefinition> creatableRooms(int lp) =>
      kAllRooms.where((r) => canCreate(lp, r)).toList();

  // ─── Oda Girişi (Join) ───────────────────────────────────────────────────

  /// Oyuncunun belirtilen odaya girip giremeyeceğini döner.
  ///
  /// Kural:
  /// - Kendi harf grubundaki ve altındaki TÜM odalara LP bağımsız girilebilir.
  /// - Üst harf grubuna eşiği geçmeden girilemez.
  static bool canJoin(int lp, RoomDefinition room) {
    // Oda, oyuncunun grubuna eşit veya daha alt bir grupta → serbest
    return room.league.index <= groupOf(lp).index;
  }

  /// Oyuncunun girebileceği tüm oda listesi.
  static List<RoomDefinition> joinableRooms(int lp) =>
      kAllRooms.where((r) => canJoin(lp, r)).toList();

  // ─── Soft Start (Puan Kaybı İstisnası) ───────────────────────────────────

  /// Oyuncunun soft start koruması altında olup olmadığını döner.
  ///
  /// Kurallar:
  /// - Yalnızca A grubu giriş aralığında (0–249 LP) geçerlidir.
  /// - Oyuncu daha önce 250 LP'ye ulaştıysa ([softStartCompleted] = true)
  ///   LP tekrar 0–249'a düşse bile soft start aktifleşmez (tek seferlik).
  /// - B ve C gruplarında soft start yoktur.
  static bool isSoftStart(int lp, {required bool softStartCompleted}) =>
      !softStartCompleted && lp < 250;
}
