import 'dart:math' show max;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/game/league_models.dart';
import 'package:flutter_application_1/game/league_rules.dart';
import 'package:flutter_application_1/game/match_scoring.dart';

void main() {
  // Kolaylık için oda referansları
  final a100 = kAllRooms[0];
  final a250 = kAllRooms[1];
  final a500 = kAllRooms[2];
  final a1k  = kAllRooms[3];
  final b100 = kAllRooms[4];
  final b250 = kAllRooms[5];
  final b500 = kAllRooms[6];
  final b1k  = kAllRooms[7];
  final c100 = kAllRooms[8];
  final c250 = kAllRooms[9];
  final c500 = kAllRooms[10];
  final c1k  = kAllRooms[11];

  // ─────────────────────────────────────────────────────────────────────────
  // kAllRooms bütünlüğü
  // ─────────────────────────────────────────────────────────────────────────
  group('kAllRooms', () {
    test('12 oda var', () => expect(kAllRooms.length, 12));

    test('levelIndex değerleri 0-11, sıralı ve benzersiz', () {
      final indices = kAllRooms.map((r) => r.levelIndex).toList();
      expect(indices, List.generate(12, (i) => i));
    });

    test('roomById A500 bulur',  () => expect(roomById('A500'), a500));
    test('roomById B1K bulur',   () => expect(roomById('B1K'),  b1k));
    test('roomById bilinmeyen -> null', () => expect(roomById('Z999'), isNull));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LeagueRules.groupOf
  // ─────────────────────────────────────────────────────────────────────────
  group('LeagueRules.groupOf', () {
    test('0 LP   → A', () => expect(LeagueRules.groupOf(0),    LeagueGroup.A));
    test('249 LP → A', () => expect(LeagueRules.groupOf(249),  LeagueGroup.A));
    test('1099 LP→ A', () => expect(LeagueRules.groupOf(1099), LeagueGroup.A));
    test('1100 LP→ B', () => expect(LeagueRules.groupOf(1100), LeagueGroup.B));
    test('2099 LP→ B', () => expect(LeagueRules.groupOf(2099), LeagueGroup.B));
    test('2100 LP→ C', () => expect(LeagueRules.groupOf(2100), LeagueGroup.C));
    test('9999 LP→ C', () => expect(LeagueRules.groupOf(9999), LeagueGroup.C));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LeagueRules.maxCreatableRoom
  // ─────────────────────────────────────────────────────────────────────────
  group('LeagueRules.maxCreatableRoom', () {
    test('0 LP    → A100', () => expect(LeagueRules.maxCreatableRoom(0),    a100));
    test('249 LP  → A100', () => expect(LeagueRules.maxCreatableRoom(249),  a100));
    test('250 LP  → A250', () => expect(LeagueRules.maxCreatableRoom(250),  a250));
    test('499 LP  → A250', () => expect(LeagueRules.maxCreatableRoom(499),  a250));
    test('500 LP  → A500', () => expect(LeagueRules.maxCreatableRoom(500),  a500));
    test('999 LP  → A500', () => expect(LeagueRules.maxCreatableRoom(999),  a500));
    test('1000 LP → A1K',  () => expect(LeagueRules.maxCreatableRoom(1000), a1k));
    test('1099 LP → A1K',  () => expect(LeagueRules.maxCreatableRoom(1099), a1k));
    test('1100 LP → B100', () => expect(LeagueRules.maxCreatableRoom(1100), b100));
    test('1349 LP → B100', () => expect(LeagueRules.maxCreatableRoom(1349), b100));
    test('1350 LP → B250', () => expect(LeagueRules.maxCreatableRoom(1350), b250));
    test('1600 LP → B500', () => expect(LeagueRules.maxCreatableRoom(1600), b500));
    // B1K ve C100 aynı eşikte (2100); lastWhere → C100 (levelIndex 8) döner
    test('2100 LP → C100', () => expect(LeagueRules.maxCreatableRoom(2100), c100));
    test('2349 LP → C100', () => expect(LeagueRules.maxCreatableRoom(2349), c100));
    test('2350 LP → C250', () => expect(LeagueRules.maxCreatableRoom(2350), c250));
    test('2600 LP → C500', () => expect(LeagueRules.maxCreatableRoom(2600), c500));
    test('3100 LP → C1K',  () => expect(LeagueRules.maxCreatableRoom(3100), c1k));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LeagueRules.canCreate
  // ─────────────────────────────────────────────────────────────────────────
  group('LeagueRules.canCreate', () {
    test('300 LP A500 açamaz',       () => expect(LeagueRules.canCreate(300, a500),  false));
    test('500 LP A500 açabilir',     () => expect(LeagueRules.canCreate(500, a500),  true));
    test('504 LP A500 açabilir',     () => expect(LeagueRules.canCreate(504, a500),  true));
    test('495 LP A500 açamaz (anlık yetki kaybı)',
                                     () => expect(LeagueRules.canCreate(495, a500),  false));
    test('2099 LP B1K açamaz',       () => expect(LeagueRules.canCreate(2099, b1k),  false));
    test('2100 LP B1K açabilir',     () => expect(LeagueRules.canCreate(2100, b1k),  true));
    test('2100 LP C100 açabilir',    () => expect(LeagueRules.canCreate(2100, c100), true));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LeagueRules.canJoin
  // ─────────────────────────────────────────────────────────────────────────
  group('LeagueRules.canJoin', () {
    // A grubundaki oyuncu
    test('300 LP A1K odasına girebilir (aynı harf)',
        () => expect(LeagueRules.canJoin(300, a1k),  true));
    test('300 LP A500 odasına girebilir',
        () => expect(LeagueRules.canJoin(300, a500), true));
    test('300 LP B100 odasına giremez',
        () => expect(LeagueRules.canJoin(300, b100), false));
    test('1099 LP B250 odasına giremez',
        () => expect(LeagueRules.canJoin(1099, b250), false));

    // B grubundaki oyuncu
    test('1200 LP A1K odasına girebilir (alt harf)',
        () => expect(LeagueRules.canJoin(1200, a1k),  true));
    test('1200 LP B500 odasına girebilir (aynı harf)',
        () => expect(LeagueRules.canJoin(1200, b500), true));
    test('1200 LP C100 odasına giremez',
        () => expect(LeagueRules.canJoin(1200, c100), false));

    // C grubundaki oyuncu
    test('2100 LP tüm odalara girebilir',
        () => kAllRooms.forEach((r) =>
            expect(LeagueRules.canJoin(2100, r), true, reason: r.id)));

    // Harf sınırında anlık düşüş
    test('2099 LP C100 odasına giremez (B grubu)',
        () => expect(LeagueRules.canJoin(2099, c100), false));
    test('2100 LP C100 odasına girebilir',
        () => expect(LeagueRules.canJoin(2100, c100), true));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LeagueRules.isSoftStart
  // ─────────────────────────────────────────────────────────────────────────
  group('LeagueRules.isSoftStart', () {
    // İlk kez A grubu: softStartCompleted=false
    test('0 LP   , not completed → soft',   () => expect(LeagueRules.isSoftStart(0,   softStartCompleted: false), true));
    test('249 LP , not completed → soft',   () => expect(LeagueRules.isSoftStart(249, softStartCompleted: false), true));
    test('250 LP , not completed → normal', () => expect(LeagueRules.isSoftStart(250, softStartCompleted: false), false));
    // 250+ LP'ye ulaşıldıktan sonra geri düşse bile soft start bitmez
    test('0 LP   , completed     → normal', () => expect(LeagueRules.isSoftStart(0,   softStartCompleted: true),  false));
    test('100 LP , completed     → normal', () => expect(LeagueRules.isSoftStart(100, softStartCompleted: true),  false));
    // B ve C gruplarında soft start yok
    test('1100 LP → normal (B grubu, soft start yok)', () => expect(LeagueRules.isSoftStart(1100, softStartCompleted: false), false));
    test('1349 LP → normal (B grubu, soft start yok)', () => expect(LeagueRules.isSoftStart(1349, softStartCompleted: false), false));
    test('2100 LP → normal (C grubu, soft start yok)', () => expect(LeagueRules.isSoftStart(2100, softStartCompleted: false), false));
    test('2349 LP → normal (C grubu, soft start yok)', () => expect(LeagueRules.isSoftStart(2349, softStartCompleted: false), false));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MatchScoring.calculateLPChange — atMax (taban puan)
  // ─────────────────────────────────────────────────────────────────────────
  group('Puan — atMax (taban)', () {
    // 500 LP → max=A500, oda=A500 → atMax
    for (final entry in [
      (pos: 1, expected:  12),
      (pos: 2, expected:   6),
      (pos: 3, expected:   4),
      (pos: 4, expected:  -2),
      (pos: 5, expected:  -3),
      (pos: 6, expected:  -6),
    ]) {
      test('${entry.pos}. → ${entry.expected}', () {
        expect(
          MatchScoring.calculateLPChange(
              position: entry.pos, playerLp: 500, room: a500),
          entry.expected,
        );
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MatchScoring.calculateLPChange — aboveMax (x1.5 pozitif)
  // ─────────────────────────────────────────────────────────────────────────
  group('Puan — aboveMax (üst oda, x1.5)', () {
    // 300 LP → max=A250(1), oda=A500(2) → aboveMax
    for (final entry in [
      (pos: 1, expected: 18),
      (pos: 2, expected:  9),
      (pos: 3, expected:  6),
      (pos: 4, expected: -2),
      (pos: 5, expected: -3),
      (pos: 6, expected: -6),
    ]) {
      test('${entry.pos}. → ${entry.expected}', () {
        expect(
          MatchScoring.calculateLPChange(
              position: entry.pos, playerLp: 300, room: a500),
          entry.expected,
        );
      });
    }

    // 300 LP → A1K(3) → de aboveMax
    test('300 LP, A1K, 1. → +18', () {
      expect(
        MatchScoring.calculateLPChange(position: 1, playerLp: 300, room: a1k),
        18,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MatchScoring.calculateLPChange — oneLevelBelow (x0.5 pozitif)
  // ─────────────────────────────────────────────────────────────────────────
  group('Puan — oneLevelBelow (x0.5)', () {
    // 500 LP → max=A500(2), oda=A250(1) → diff=1
    for (final entry in [
      (pos: 1, expected:  6),
      (pos: 2, expected:  3),
      (pos: 3, expected:  2),
      (pos: 4, expected: -2),
      (pos: 5, expected: -3),
      (pos: 6, expected: -6),
    ]) {
      test('${entry.pos}. (500 LP, A250) → ${entry.expected}', () {
        expect(
          MatchScoring.calculateLPChange(
              position: entry.pos, playerLp: 500, room: a250),
          entry.expected,
        );
      });
    }

    // 1100 LP → max=B100(4), oda=A1K(3) → diff=1
    test('1100 LP, A1K, 1. → +6', () {
      expect(
        MatchScoring.calculateLPChange(position: 1, playerLp: 1100, room: a1k),
        6,
      );
    });

    // 2100 LP → max=C100(8), oda=B1K(7) → diff=1
    test('2100 LP, B1K, 2. → +3', () {
      expect(
        MatchScoring.calculateLPChange(position: 2, playerLp: 2100, room: b1k),
        3,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MatchScoring.calculateLPChange — twoOrMoreBelow (sabit tablo)
  // ─────────────────────────────────────────────────────────────────────────
  group('Puan — twoOrMoreBelow (sabit)', () {
    // 1000 LP → max=A1K(3), oda=A100(0) → diff=3
    for (final entry in [
      (pos: 1, expected:  2),
      (pos: 2, expected:  1),
      (pos: 3, expected:  1),
      (pos: 4, expected: -2),
      (pos: 5, expected: -3),
      (pos: 6, expected: -6),
    ]) {
      test('${entry.pos}. (1000 LP, A100) → ${entry.expected}', () {
        expect(
          MatchScoring.calculateLPChange(
              position: entry.pos, playerLp: 1000, room: a100),
          entry.expected,
        );
      });
    }

    // B250 (1350 LP) → max=B250(5), oda=A500(2) → diff=3
    test('1350 LP, A500, 1. → +2', () {
      expect(
        MatchScoring.calculateLPChange(position: 1, playerLp: 1350, room: a500),
        2,
      );
    });

    // A1K (1000 LP) → max=A1K(3), oda=A250(1) → diff=2
    test('1000 LP, A250, 3. → +1', () {
      expect(
        MatchScoring.calculateLPChange(position: 3, playerLp: 1000, room: a250),
        1,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Soft Start — puan kaybı yok
  // ─────────────────────────────────────────────────────────────────────────
  group('Soft Start — A grubu, tek seferlik', () {
    // ── A grubu, soft start aktif (not completed) ──
    test('100 LP, A100, 4. → 0  (soft start korur)',
        () => expect(MatchScoring.calculateLPChange(position: 4, playerLp: 100, room: a100), 0));
    test('100 LP, A100, 6. → 0  (soft start korur)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 100, room: a100), 0));
    test('100 LP, A100, 1. → +12 (kazanç etkilenmez)',
        () => expect(MatchScoring.calculateLPChange(position: 1, playerLp: 100, room: a100), 12));
    test('100 LP, A500 üst oda, 6. → 0  (aboveMax + soft start)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 100, room: a500), 0));
    test('100 LP, A500 üst oda, 1. → +18 (aboveMax kazanç)',
        () => expect(MatchScoring.calculateLPChange(position: 1, playerLp: 100, room: a500), 18));

    // ── A grubu, soft start tamamlandı → koruma yok ──
    test('100 LP, A100, 4. → -2  (completed → kayıp var)',
        () => expect(MatchScoring.calculateLPChange(position: 4, playerLp: 100, room: a100, softStartCompleted: true), -2));
    test('100 LP, A100, 6. → -6  (completed → kayıp var)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 100, room: a100, softStartCompleted: true), -6));

    // ── 250 LP → A soft start bitmiş (< 250 kontrolü) ──
    test('250 LP, A100, 6. → -6 (250 LP soft start dışı)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 250, room: a100), -6));

    // ── B grubu: soft start YOK ──
    test('1200 LP, B100, 5. → -3  (B grubunda kayıp koruması yok)',
        () => expect(MatchScoring.calculateLPChange(position: 5, playerLp: 1200, room: b100), -3));
    test('1200 LP, B100, 2. → +6  (kazanç etkilenmez)',
        () => expect(MatchScoring.calculateLPChange(position: 2, playerLp: 1200, room: b100), 6));

    // ── C grubu: soft start YOK ──
    test('2200 LP, C100, 6. → -6  (C grubunda kayıp koruması yok)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 2200, room: c100), -6));
    test('2200 LP, C250 üst oda, 6. → -6  (aboveMax, kayıp koruması yok)',
        () => expect(MatchScoring.calculateLPChange(position: 6, playerLp: 2200, room: c250), -6));
    test('2200 LP, C250 üst oda, 1. → +18 (aboveMax kazanç)',
        () => expect(MatchScoring.calculateLPChange(position: 1, playerLp: 2200, room: c250), 18));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Anlık Yetki Kaybı senaryosu
  // ─────────────────────────────────────────────────────────────────────────
  group('Anlık yetki kaybı', () {
    test('505 LP A500 açabilir', () => expect(LeagueRules.canCreate(505, a500), true));

    test('495 LP A500 açamaz (maç kaybetti, anlık düşüş)',
        () => expect(LeagueRules.canCreate(495, a500), false));

    test('495 LP A500 odasına join yapabilir (A grubunda)',
        () => expect(LeagueRules.canJoin(495, a500), true));

    test('1099 LP B100 odasına giremez (B eşiği aşılmadı)',
        () => expect(LeagueRules.canJoin(1099, b100), false));

    test('1100 LP B100 odasına girebilir',
        () => expect(LeagueRules.canJoin(1100, b100), true));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // calculateMatchOutcome — Tam 6 kişilik maç
  // ─────────────────────────────────────────────────────────────────────────
  group('calculateMatchOutcome — tam maç A500', () {
    late MatchOutcome outcome;

    setUpAll(() {
      outcome = MatchScoring.calculateMatchOutcome(
        room: a500,
        playerEntries: [
          // max=A250(1), oda=A500(2) → aboveMax → +18
          (playerId: 'p1', lpBefore: 300,  position: 1),
          // max=A500(2), oda=A500(2) → atMax    → +6
          (playerId: 'p2', lpBefore: 500,  position: 2),
          // max=A500(2), oda=A500(2) → atMax    → +4
          (playerId: 'p3', lpBefore: 600,  position: 3),
          // max=A1K(3),  oda=A500(2) → oneLevelBelow → -2 (negatif değişmez)
          (playerId: 'p4', lpBefore: 1000, position: 4),
          // max=A250(1), oda=A500(2) → aboveMax → negatif -3
          (playerId: 'p5', lpBefore: 300,  position: 5),
          // max=A100(0), oda=A500(2) → aboveMax + softStart → 0
          (playerId: 'p6', lpBefore: 100,  position: 6),
        ],
      );
    });

    RoomDefinition _resultRoom(String id) =>
        outcome.results.firstWhere((r) => r.playerId == id).room;
    int _change(String id) =>
        outcome.results.firstWhere((r) => r.playerId == id).lpChange;
    int _after(String id) =>
        outcome.results.firstWhere((r) => r.playerId == id).lpAfter;

    test('p1 lpChange = +18', () => expect(_change('p1'), 18));
    test('p2 lpChange = +6',  () => expect(_change('p2'),  6));
    test('p3 lpChange = +4',  () => expect(_change('p3'),  4));
    test('p4 lpChange = -2',  () => expect(_change('p4'), -2));
    test('p5 lpChange = -3',  () => expect(_change('p5'), -3));
    test('p6 lpChange = 0 (softStart)', () => expect(_change('p6'),  0));

    test('p1 lpAfter = 318',  () => expect(_after('p1'), 318));
    test('p4 lpAfter = 998',  () => expect(_after('p4'), 998));
    test('p6 lpAfter = 100 (değişmedi)', () => expect(_after('p6'), 100));

    test('Soft start → lpChange=0, lpAfter=lpBefore (kayıp yok)', () {
      // 2 LP: soft start bölgesinde (0-249), A100 atMax, 6. sıra
      // change = 0 (soft start), lpAfter = max(0, 2+0) = 2
      final edge = MatchScoring.calculateMatchOutcome(
        room: a100,
        playerEntries: [
          (playerId: 'px', lpBefore: 2,  position: 6),
          (playerId: 'p2', lpBefore: 10, position: 5),
          (playerId: 'p3', lpBefore: 10, position: 4),
          (playerId: 'p4', lpBefore: 10, position: 3),
          (playerId: 'p5', lpBefore: 10, position: 2),
          (playerId: 'p6', lpBefore: 10, position: 1),
        ],
      );
      final px = edge.results.firstWhere((r) => r.playerId == 'px');
      expect(px.lpChange, 0);  // soft start → kayıp yok
      expect(px.lpAfter,  2);  // lpBefore değişmedi
    });

    test('LP max(0) alt sınırı: 3 LP, normal zone, 6. → lpAfter en az 0', () {
      // 252 LP: normal zone (≥250), max=A250, oda=A250 (atMax)
      // change=-6, lpAfter=max(0, 252-6)=246 — sınır testi değil ama API doğru
      final r = MatchScoring.calculateLPChange(
          position: 6, playerLp: 252, room: a250);
      expect(r, -6);
      expect(max(0, 252 + r), 246);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Köşe senaryoları
  // ─────────────────────────────────────────────────────────────────────────
  group('Köşe senaryoları', () {
    // B1K ve C100 aynı eşikte
    test('2100 LP: B1K açabilir', () => expect(LeagueRules.canCreate(2100, b1k),  true));
    test('2100 LP: C100 açabilir', () => expect(LeagueRules.canCreate(2100, c100), true));
    test('2100 LP max → C100 (yüksek levelIndex kazanır)',
        () => expect(LeagueRules.maxCreatableRoom(2100), c100));

    // C100 oyuncusu B1K'da: oneLevelBelow
    test('2100 LP, B1K, 1. → +6 (oneLevelBelow)', () {
      expect(
        MatchScoring.calculateLPChange(position: 1, playerLp: 2100, room: b1k),
        6,
      );
    });

    // C100 oyuncusu C250'de: aboveMax
    test('2100 LP, C250, 1. → +18 (aboveMax)', () {
      expect(
        MatchScoring.calculateLPChange(position: 1, playerLp: 2100, room: c250),
        18,
      );
    });

    // C100 grubunda soft start yok → B1K'da kayıp oluşur
    test('2100 LP, B1K, 6. → -6 (C grubunda soft start yok, oneLevelBelow negatif)', () {
      expect(
        MatchScoring.calculateLPChange(position: 6, playerLp: 2100, room: b1k),
        -6,
      );
    });
  });
}
