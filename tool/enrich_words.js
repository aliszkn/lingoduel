/**
 * LingoDuel — Kelime Zenginleştirici (Gemini 2.0 Flash, billing'li)
 * Kurulum : npm install axios
 * Kullanım : node enrich_words.js
 *
 * Not: Bu makinenin ağında SSL araya giriyor; ortamda zaten
 * NODE_TLS_REJECT_UNAUTHORIZED=0 ayarlı olduğu için axios sorunsuz çalışır.
 */

const axios = require('axios');
const fs    = require('fs');
const path  = require('path');

// ── Ayarlar ───────────────────────────────────────────────────────────────────
const API_KEY    = process.env.GEMINI_API_KEY || 'BURAYA_API_KEY_YAZ'; // ASLA repoya gerçek key yazma
const MODEL      = 'gemini-2.0-flash';
const API_URL    = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;
const CHUNK_SIZE = 30;       // çıktı token taşmasını önlemek için ölçülü
const SLEEP_MS   = 2_000;    // billing'de limit yüksek; yine de nazik ol
const MAX_RETRY  = 4;
const MAX_WAIT_S = 60;       // tek beklemede üst sınır (saniye)

const WORDS_FILE    = path.join(__dirname, 'words.txt');
const OUTPUT_FILE   = path.join(__dirname, 'database.json');
const PROGRESS_FILE = path.join(__dirname, 'enrich_progress.json');

// ── Yardımcılar ───────────────────────────────────────────────────────────────
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function readProgress() {
  try   { return JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf8')); }
  catch { return { lastChunk: -1 }; }
}
function saveProgress(i) {
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify({ lastChunk: i }));
}
function loadDatabase() {
  try   { return JSON.parse(fs.readFileSync(OUTPUT_FILE, 'utf8')); }
  catch { return []; }
}
function writeDatabase(db) {
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(db, null, 2));
}
function extractJSON(text) {
  const cleaned = text.replace(/```json\s*/gi, '').replace(/```\s*/g, '').trim();
  const match   = cleaned.match(/\[[\s\S]*\]/);
  if (!match) throw new Error('Yanıtta JSON array bulunamadı:\n' + text.slice(0, 200));
  return JSON.parse(match[0]);
}

// Sadece 6 alanı tut, tipini doğrula (ekstra alan eklenmesin)
function temizle(obj) {
  return {
    en:      String(obj.en      ?? '').trim(),
    tr:      String(obj.tr      ?? '').trim(),
    desc:    String(obj.desc    ?? '').trim(),
    desc_tr: String(obj.desc_tr ?? '').trim(),
    others:  String(obj.others  ?? '').trim(),
    ex:      String(obj.ex      ?? '').trim(),
  };
}

// ── Gemini API çağrısı ──────────────────────────────────────────────────────
async function enrichChunk(words) {
  const prompt =
`You are a professional dictionary builder for a language-learning app.

LEMMA RULE:
- Find the base form (lemma) of each word.
  Examples: running→run, cats→cat, was→be, better→good, 'll→will, 've→have
- If multiple words share the SAME lemma, include only ONE entry for that lemma.

OUTPUT RULE:
- Return ONLY a raw JSON array. No markdown. No code block. No extra text.
- Every object must contain EXACTLY these 6 keys — nothing more, nothing less:
  "en"      : base form (lemma) in English
  "tr"      : concise, accurate Turkish translation (1-3 words)
  "desc"    : 1-2 sentence English definition
  "desc_tr" : the same definition translated into natural Turkish
  "others"  : other common forms comma-separated (e.g. "runs, ran, running")
  "ex"      : one natural English example sentence

WORDS: ${JSON.stringify(words)}`;

  const res = await axios.post(
    API_URL,
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 8192 },
    },
    {
      timeout: 90_000,
      headers: { 'x-goog-api-key': API_KEY, 'Content-Type': 'application/json' },
    }
  );

  const text = res.data.candidates[0].content.parts[0].text;
  return extractJSON(text).map(temizle).filter((e) => e.en && e.tr);
}

// ── Ana akış ──────────────────────────────────────────────────────────────────
async function main() {
  if (!fs.existsSync(WORDS_FILE)) {
    console.error(`❌ Dosya bulunamadı: ${WORDS_FILE}`);
    process.exit(1);
  }

  const allWords = fs.readFileSync(WORDS_FILE, 'utf8')
    .split('\n').map((w) => w.trim()).filter(Boolean);

  const chunks = [];
  for (let i = 0; i < allWords.length; i += CHUNK_SIZE)
    chunks.push(allWords.slice(i, i + CHUNK_SIZE));

  // Global dedup: DB'de zaten olan lemma'ları tekrar ekleme
  const db   = loadDatabase();
  const seen = new Set(db.map((e) => e.en.toLowerCase()));

  const { lastChunk } = readProgress();
  const startFrom = lastChunk + 1;

  console.log(`\n📚 Toplam kelime : ${allWords.length}`);
  console.log(`📦 Chunk sayısı  : ${chunks.length}`);
  console.log(`💾 Mevcut DB     : ${db.length} kayıt`);
  console.log(`⏩ Başlangıç     : chunk ${startFrom + 1}/${chunks.length}\n`);

  for (let i = startFrom; i < chunks.length; i++) {
    const from = i * CHUNK_SIZE + 1;
    const to   = Math.min((i + 1) * CHUNK_SIZE, allWords.length);
    process.stdout.write(`🔄 Chunk ${String(i + 1).padStart(3)}/${chunks.length} [${from}-${to}]  ... `);

    let entries = null;

    for (let attempt = 1; attempt <= MAX_RETRY; attempt++) {
      try {
        entries = await enrichChunk(chunks[i]);
        break;
      } catch (err) {
        const apiMsg  = err.response?.data?.error?.message ?? err.message ?? String(err);
        const retryRe = apiMsg.match(/retry.*?(\d+(?:\.\d+)?)\s*s/i);
        const rawSec  = retryRe ? Math.ceil(parseFloat(retryRe[1])) + 2 : 8 * attempt;
        const waitSec = Math.min(rawSec, MAX_WAIT_S);   // 973M-saniye bug'ına karşı tavan
        console.error(`\n  ❌ Deneme ${attempt}/${MAX_RETRY}: ${apiMsg.slice(0, 130)}`);
        if (attempt < MAX_RETRY) {
          process.stdout.write(`  ⏳ ${waitSec}sn bekleniyor... `);
          await sleep(waitSec * 1000);
        }
      }
    }

    if (!entries) {
      console.log('⛔ Atlandı');
    } else {
      // Global lemma dedup → flawless: aynı kök iki kez girmez
      let eklenen = 0;
      for (const e of entries) {
        const key = e.en.toLowerCase();
        if (seen.has(key)) continue;
        seen.add(key);
        db.push(e);
        eklenen++;
      }
      writeDatabase(db);   // her chunk sonrası diske yaz (kesinti güvenli)
      console.log(`✅ ${entries.length} dönen, ${eklenen} yeni (toplam ${db.length})`);
    }
    saveProgress(i);

    if (i < chunks.length - 1) await sleep(SLEEP_MS);
  }

  console.log(`\n🎉 Tamamlandı! database.json: ${db.length} benzersiz kayıt`);
}

main().catch((err) => {
  console.error('💥 Kritik hata:', err.message);
  process.exit(1);
});
