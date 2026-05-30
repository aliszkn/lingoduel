import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:nakama/nakama.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

// ── OpCode tablosu (match_handler.lua ile senkron) ───────────────────────────
/// C→S: Oyuncu hazır durumu değişti.  Data: {userId, isim, hazir}
const int kOpHazirDegisti      = 1;
/// C→S (Faz 2 compat): Host oyunu başlatıyor. Data: {seed}
const int kOpOyunBasliyor      = 2;
/// C→S: Oyuncu cevap gönderdi.  Data: {qi, correct}
const int kOpCevapGonder       = 5;
/// S→C: Sunucu yeni soru indeksini yayınladı. Data: {qi}
const int kOpSoruGeldi         = 10;
/// S→C: Sayaç güncellemesi. Data: {sn}
const int kOpSayacGuncellendi  = 11;
/// S→C: Reveal sonuçları. Data: {qi, sonuclar:[{userId,puan,totalPuan,dogru}]}
const int kOpReveal            = 12;
/// S→C: Güncel leaderboard. Data: {leaderboard:[{userId,isim,puan}]}
const int kOpSkorGuncellendi   = 13;
/// S→C: Maç bitti, final sıralama. Data: {sirali:[{userId,isim,puan,sira}]}
const int kOpMacBitti          = 14;
/// S→C: Yeniden bağlanan oyuncuya durum. Data: {phase, qi, sn, leaderboard}
const int kOpResync            = 15;

class NakamaService {
  NakamaService._();
  static final NakamaService instance = NakamaService._();

  // ── Geliştirme sunucu ayarları ────────────────────────────────────────────
  static const String _serverKey      = 'defaultkey';
  static const int    _httpPort       = 7350;
  static const bool   _ssl            = false;
  // Fiziksel Android cihaz → bilgisayarın WiFi IP'si (ipconfig'den al)
  static const String _kAndroidDevHost = '192.168.1.103';
  static const String _kDeviceIdKey    = 'nakama_device_id';

  NakamaBaseClient?       _client;
  Session?                _session;
  NakamaWebsocketClient?  _socket;

  /// Soket beklenmedik şekilde kapandığında çağrılır (yeniden bağlanma için).
  /// Maç ekranı bunu dinleyip rejoin dener.
  void Function()? onSoketKapandi;

  /// Oturum açıldıysa sunucudaki kullanıcı kimliği.
  String? get userId => _session?.userId;

  bool get yeniHesap    => _session?.created ?? false;
  bool get girisYapildi => _session != null && !_session!.isExpired;
  bool get soketAcik    => _socket != null;

  /// Gerçek zamanlı lobi olayları — maça kim katıldı/ayrıldı.
  Stream<MatchPresenceEvent>? get onMatchPresence => _socket?.onMatchPresence;
  /// Lobi mesajları (hazır durumu, oyun başlatma sinyali).
  Stream<MatchData>? get onMatchData => _socket?.onMatchData;

  static String get _host {
    if (kIsWeb) return '127.0.0.1';
    try {
      if (Platform.isAndroid) return _kAndroidDevHost;
    } catch (_) {}
    return '127.0.0.1';
  }

  // ── Faz 0: Kimlik ────────────────────────────────────────────────────────

  Future<bool> baglanVeGiris() async {
    try {
      _client = NakamaRestApiClient.init(
        host: _host, port: _httpPort, serverKey: _serverKey, ssl: _ssl,
      );
      final deviceId = await _cihazKimligiAlVeyaUret();
      _session = await _client!
          .authenticateDevice(deviceId: deviceId, create: true)
          .timeout(const Duration(seconds: 5));
      debugPrint('[Nakama] giriş OK — userId=${_session!.userId} '
          'yeniHesap=${_session!.created}');
      return true;
    } catch (e) {
      debugPrint('[Nakama] giriş BAŞARISIZ: $e');
      _session = null;
      return false;
    }
  }

  // ── Faz 1: Profil sync ───────────────────────────────────────────────────

  static const _kProfCol  = 'player_profile';
  static const _kProfKey  = 'stats';

  Future<void> profilYukle() async {
    await oturumuTazele();
    final c = _client, s = _session;
    if (c == null || s == null) return;
    try {
      final objs = await c.readStorageObjects(
        session: s,
        objectIds: [StorageObjectId(collection: _kProfCol, key: _kProfKey)],
      );
      if (objs.isEmpty) { await profilKaydet(); return; }
      final data     = jsonDecode(objs.first.value) as Map<String, dynamic>;
      final serverLp = (data['lp'] as num?)?.toInt() ?? 0;
      if (serverLp > AppSettings.playerLP) await AppSettings.setPlayerLP(serverLp);
      final ser = (data['kazanmaSer']   as num?)?.toInt();
      if (ser  != null) AppSettings.kazanmaSerisi = ser;
      final top = (data['toplamMac']    as num?)?.toInt();
      if (top  != null) AppSettings.toplamMac     = top;
      final kaz = (data['kazanilanMac'] as num?)?.toInt();
      if (kaz  != null) AppSettings.kazanilanMac  = kaz;
      final ad  = data['kullaniciAdi'] as String?;
      if (ad != null && ad.isNotEmpty) await AppSettings.setKullaniciAdi(ad);
      debugPrint('[Nakama] profil yüklendi lp=$serverLp ad=${AppSettings.kullaniciAdi}');
    } catch (e) { debugPrint('[Nakama] profil yükleme hatası: $e'); }
  }

  Future<void> profilKaydet() async {
    await oturumuTazele();
    final c = _client, s = _session;
    if (c == null || s == null) return;
    try {
      await c.writeStorageObjects(session: s, objects: [
        StorageObjectWrite(
          collection: _kProfCol,
          key:        _kProfKey,
          value: jsonEncode({
            'kullaniciAdi': AppSettings.kullaniciAdi,
            'lp':           AppSettings.playerLP,
            'kazanmaSer':   AppSettings.kazanmaSerisi,
            'toplamMac':    AppSettings.toplamMac,
            'kazanilanMac': AppSettings.kazanilanMac,
          }),
        ),
      ]);
    } catch (e) { debugPrint('[Nakama] profil kaydetme hatası: $e'); }
  }

  // ── Faz 2: WebSocket soket ────────────────────────────────────────────────

  /// Maç ekranı kapanırken normal kapanışla beklenmedik kopuşu ayırmak için.
  bool _kasitliKapatma = false;

  /// WebSocket bağlantısı aç (DuelPanel açılınca veya odaya girerken çağrılır).
  Future<void> soketBaglan() async {
    if (_socket != null) return; // zaten açık
    final s = _session;
    if (s == null) return;
    _kasitliKapatma = false;
    try {
      _socket = NakamaWebsocketClient.init(
        host:  _host,
        port:  _httpPort,
        ssl:   _ssl,
        token: s.token,
        onDone: () {
          debugPrint('[Nakama] soket kapandı');
          _socket = null;
          // Beklenmedik kopuş → maç ekranını uyar (yeniden bağlanma denesin)
          if (!_kasitliKapatma) onSoketKapandi?.call();
        },
        onError: (e) => debugPrint('[Nakama] soket hatası: $e'),
      );
      debugPrint('[Nakama] soket bağlandı');
    } catch (e) {
      debugPrint('[Nakama] soket bağlantı hatası: $e');
    }
  }

  /// Faz 4: kopan soketi yeniden aç (token yenileyip). Başarılıysa true.
  /// Yeni soket yeni stream'ler demektir → çağıran taraf yeniden subscribe olmalı.
  Future<bool> soketYenidenBaglan() async {
    _socket = null;
    await oturumuTazele();
    await soketBaglan();
    return _socket != null;
  }

  /// WebSocket bağlantısını kapat (kasıtlı — yeniden bağlanma tetiklenmez).
  Future<void> soketKapat() async {
    _kasitliKapatma = true;
    try { await _socket?.close(); } catch (_) {}
    _socket = null;
  }

  // ── Faz 2: Oda yönetimi (Lua RPC) ────────────────────────────────────────

  /// Nakama RPC çağrısı — oturum yoksa null döner.
  Future<Map<String, dynamic>?> _rpc(String id, [Map<String, dynamic>? payload]) async {
    await oturumuTazele(); // token süresi dolmuşsa yenile (Prensip 2 / stabilite)
    final c = _client, s = _session;
    if (c == null || s == null) return null;
    try {
      final result = await c.rpc(
        session: s,
        id:      id,
        payload: payload != null ? jsonEncode(payload) : '{}',
      );
      if (result == null) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Nakama] RPC $id hatası: $e');
      return null;
    }
  }

  /// Yeni oda oluştur. Dönen map'te `roomId` var.
  Future<Map<String, dynamic>?> odaOlustur({
    required String isim,
    required String setId,
    required String tier,
    required int    kapasite,
  }) => _rpc('create_room', {
    'isim':    isim,
    'setId':   setId,
    'tier':    tier,
    'kapasite': kapasite,
    'hostAdi': AppSettings.kullaniciAdi,
  });

  /// Sunucudaki aktif odaları döner.
  Future<List<Map<String, dynamic>>> aktifOdalariGetir() async {
    final result = await _rpc('list_rooms');
    final raw = result?['rooms'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Odayı sunucudan sil (host oyun bitince veya odadan ayrılınca).
  Future<void> odaSil(String roomId) => _rpc('delete_room', {'roomId': roomId})
      .then((_) {});

  /// Odanın doluluk/matchId bilgisini güncelle.
  Future<void> odaGuncelle({
    required String roomId,
    required int    dolu,
    String?         matchId,
  }) => _rpc('update_room', {
    'roomId':  roomId,
    'dolu':    dolu,
    if (matchId != null) 'matchId': matchId,
  }).then((_) {});

  // ── Faz 2: Maç (WebSocket match) ─────────────────────────────────────────

  /// Yeni relayed maç oluştur — match ID'sini döner.
  Future<String?> macOlustur() async {
    try {
      final match = await _socket?.createMatch();
      return match?.matchId;
    } catch (e) {
      debugPrint('[Nakama] maç oluşturma hatası: $e');
      return null;
    }
  }

  /// Var olan maça katıl — match ID'sini doğrular.
  Future<String?> macaKatil(String matchId) async {
    try {
      final match = await _socket?.joinMatch(matchId);
      return match?.matchId;
    } catch (e) {
      debugPrint('[Nakama] maça katılma hatası: $e');
      return null;
    }
  }

  /// Maçtan ayrıl.
  Future<void> macBirak(String matchId) async {
    try { await _socket?.leaveMatch(matchId); } catch (_) {}
  }

  /// Hazır durumu mesajı gönder (opCode 1).
  void hazirMesajiGonder(String matchId, bool hazir) {
    _socket?.sendMatchData(
      matchId: matchId,
      opCode:  kOpHazirDegisti,
      data:    utf8.encode(jsonEncode({
        'userId': userId,
        'isim':   AppSettings.kullaniciAdi,
        'hazir':  hazir,
      })),
    );
  }

  /// Oyun başlatma mesajı gönder — tüm oyunculara seed iletilir (opCode 2).
  void oyunBaslatMesajiGonder(String matchId, int seed) {
    _socket?.sendMatchData(
      matchId: matchId,
      opCode:  kOpOyunBasliyor,
      data:    utf8.encode(jsonEncode({'seed': seed})),
    );
  }

  /// Cevap gönder — sunucu skoru hesaplar (opCode 5).
  /// [qi] = sorunun server-side indeksi, [correct] = doğru mu?
  void cevapGonder(String matchId, int qi, bool correct) {
    _socket?.sendMatchData(
      matchId: matchId,
      opCode:  kOpCevapGonder,
      data:    utf8.encode(jsonEncode({'qi': qi, 'correct': correct})),
    );
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  Future<void> oturumuTazele() async {
    final c = _client, s = _session;
    if (c == null || s == null) return;
    if (s.isExpired) {
      try { _session = await c.sessionRefresh(session: s); }
      catch (_) { await baglanVeGiris(); }
    }
  }

  Future<String> _cihazKimligiAlVeyaUret() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.length < 10) {
      id = _uuidV4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }

  static String _uuidV4() {
    final r    = DateTime.now().microsecondsSinceEpoch;
    final rand = (r * 1103515245 + 12345) & 0x7fffffff;
    String hex(int v, int len) =>
        v.toRadixString(16).padLeft(len, '0').substring(0, len);
    return '${hex(r & 0xffffffff, 8)}-${hex(rand & 0xffff, 4)}-'
        '4${hex((rand >> 4) & 0xfff, 3)}-'
        '${hex(8 + (rand & 0x3), 1)}${hex((r >> 16) & 0xfff, 3)}-'
        '${hex(r & 0xffffffffffff, 12)}';
  }
}
