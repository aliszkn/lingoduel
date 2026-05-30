-- LingoDuel -- Authoritative Mac Handler (Faz 3 + Faz 4)
-- Faz 4: sunucu-tarafi botlar + yeniden baglanma (resync).
-- Kayit: nk.match_create("match_handler", {seed, kapasite, totalQuestions})

-- OpCode tablosu
local OP_HAZIR      = 1   -- C->S: {hazir}
local OP_CEVAP      = 5   -- C->S: {qi, correct}
local OP_SORU       = 10  -- S->C: {qi}
local OP_SAYAC      = 11  -- S->C: {sn}
local OP_REVEAL     = 12  -- S->C: {qi, sonuclar}
local OP_SKOR       = 13  -- S->C: {leaderboard}
local OP_MAC_BITTI  = 14  -- S->C: {sirali}
local OP_RESYNC     = 15  -- S->C: {phase, qi, sn, leaderboard}  (yeniden baglanan oyuncuya)

-- Bot davranis sabitleri (client _botlariniPlanla ile ayni)
local BOT_ANSWER_CHANCE  = 0.85   -- bot cevap verme olasiligi
local BOT_CORRECT_CHANCE = 0.70   -- cevap verenler arasinda dogru bilme olasiligi

-- Faz 5: rate limit — bir oyuncudan tek tick'te (1sn) kabul edilen max mesaj.
-- Normal client tick basina 1-2 mesaj yollar; ustu flood sayilir, yoksayilir.
local MAX_MSG_PER_TICK = 8

-- ── Yardimcilar ────────────────────────────────────────────────────────────

-- Leaderboard tablosu kur
local function build_board(state)
    local board = {}
    for uid, p in pairs(state.players) do
        table.insert(board, {userId = uid, isim = p.isim, puan = p.puan})
    end
    table.sort(board, function(a, b) return a.puan > b.puan end)
    return board
end

local function skor_yayinla(dispatcher, nk, state)
    dispatcher.broadcast_message(OP_SKOR,
        nk.json_encode({leaderboard = build_board(state)}), nil, nil, true)
end

-- Bagli gercek oyuncu sayisi (bot ve kopuk haricinde)
local function bagli_gercek_sayisi(state)
    local n = 0
    for _, p in pairs(state.players) do
        if not p.is_bot and p.connected ~= false then n = n + 1 end
    end
    return n
end

-- Bos slotlari botlarla doldur (lobby -> countdown gecisinde 1 kez)
local function botlari_doldur(state)
    local count = 0
    for _ in pairs(state.players) do count = count + 1 end
    local n = 1
    while count < state.kapasite do
        local id = "bot_" .. n
        if not state.players[id] then
            state.players[id] = {
                isim = "Bot " .. n, puan = 0, hazir = true,
                is_bot = true, connected = true,
            }
            count = count + 1
        end
        n = n + 1
    end
end

-- Her soru basinda botlarin cevap planini kur
local function bot_planlari_kur(state)
    state.bot_plans = {}
    for uid, p in pairs(state.players) do
        if p.is_bot and math.random() < BOT_ANSWER_CHANCE then
            state.bot_plans[uid] = {
                answer_sn = math.random(1, 9),
                correct   = math.random() < BOT_CORRECT_CHANCE,
            }
        end
    end
end

-- Bu tick'te planli botlarin cevabini enjekte et
local function bot_cevaplarini_enjekte(state)
    for uid, plan in pairs(state.bot_plans or {}) do
        if not state.answers[uid] and plan.answer_sn == state.sn then
            state.answers[uid] = {correct = plan.correct, sn = state.sn}
        end
    end
end

-- Herkes cevapladi mi? (kopuk = atla, plansiz bot = "bitti" sayilir)
local function hepsi_cevapladi(state)
    for uid, p in pairs(state.players) do
        if p.connected == false then
            -- kopuk oyuncu: bekletme
        elseif p.is_bot then
            local plan = (state.bot_plans or {})[uid]
            if plan and not state.answers[uid] then return false end
        else
            if not state.answers[uid] then return false end
        end
    end
    return true
end

-- Yeni soru basalt
local function soru_basalt(dispatcher, nk, state)
    state.phase   = "question"
    state.sn      = 10
    state.answers = {}
    bot_planlari_kur(state)
    dispatcher.broadcast_message(OP_SORU,  nk.json_encode({qi = state.qi}), nil, nil, true)
    dispatcher.broadcast_message(OP_SAYAC, nk.json_encode({sn = state.sn}), nil, nil, true)
end

-- Soruyu yargila ve reveal'e gec
local function yargila(dispatcher, nk, state)
    state.phase       = "reveal"
    state.reveal_left = 2

    local sonuclar = {}
    for uid, p in pairs(state.players) do
        local ans     = state.answers[uid]
        local correct = ans and ans.correct or false
        local sn      = ans and ans.sn or 0
        local q_puan  = correct and (sn > 3 and sn or 3) or 0
        p.puan        = p.puan + q_puan
        table.insert(sonuclar, {
            userId    = uid,
            puan      = q_puan,
            totalPuan = p.puan,
            dogru     = correct,
        })
    end

    dispatcher.broadcast_message(OP_REVEAL,
        nk.json_encode({qi = state.qi, sonuclar = sonuclar}), nil, nil, true)
    skor_yayinla(dispatcher, nk, state)
end

-- Mac bitti
local function mac_bitti(dispatcher, nk, state)
    local sirali = build_board(state)
    for i, s in ipairs(sirali) do s.sira = i end
    dispatcher.broadcast_message(OP_MAC_BITTI,
        nk.json_encode({sirali = sirali}), nil, nil, true)
end

-- ── Match lifecycle ────────────────────────────────────────────────────────

local function match_init(ctx, logger, nk, params)
    params = params or {}
    local seed = params.seed or math.random(0, 2147483647)
    math.randomseed(seed)   -- bot davranisi seed'e bagli (tekrarlanabilir)
    local state = {
        phase        = "lobby",
        seed         = seed,
        kapasite     = tonumber(params.kapasite) or 6,
        total_q      = tonumber(params.totalQuestions) or 10,
        qi           = 0,
        sn           = 10,
        cd_left      = 0,
        reveal_left  = 0,
        players      = {},
        answers      = {},
        bot_plans    = {},
    }
    print(string.format("LingoDuel match_init seed=%d kapasite=%d totalQ=%d",
        state.seed, state.kapasite, state.total_q))
    return state, 1, ""
end

local function match_join_attempt(ctx, logger, nk, dispatcher, tick, state,
                                   presence, metadata)
    -- Yeniden baglanma: daha once katilmis oyuncu her zaman tekrar girebilir
    if state.players[presence.user_id] then
        return state, true, ""
    end
    if state.phase ~= "lobby" then
        return state, false, "Mac zaten basladi"
    end
    local count = 0
    for _ in pairs(state.players) do count = count + 1 end
    if count >= state.kapasite then
        return state, false, "Oda dolu"
    end
    return state, true, ""
end

local function match_join(ctx, logger, nk, dispatcher, tick, state, presences)
    for _, p in ipairs(presences) do
        local existing = state.players[p.user_id]
        if existing then
            -- Yeniden baglandi: skoru koru, kopuk bayragini kaldir, durumu gonder
            existing.connected = true
            dispatcher.broadcast_message(OP_RESYNC, nk.json_encode({
                phase       = state.phase,
                qi          = state.qi,
                sn          = state.sn,
                leaderboard = build_board(state),
            }), { p }, nil, true)
            print("match_rejoin: " .. p.username)
        else
            state.players[p.user_id] = {
                isim = p.username, puan = 0, hazir = false,
                is_bot = false, connected = true,
            }
            print("match_join: " .. p.username)
        end
    end
    skor_yayinla(dispatcher, nk, state)
    return state
end

local function match_leave(ctx, logger, nk, dispatcher, tick, state, presences)
    for _, p in ipairs(presences) do
        local pl = state.players[p.user_id]
        if pl then
            if state.phase == "lobby" or state.phase == "finished" then
                state.players[p.user_id] = nil          -- lobide tamamen cikar
            else
                pl.connected = false                    -- mac ortasi: skoru koru
                print("match_disconnect: " .. p.user_id)
            end
        end
    end
    -- Bagli gercek oyuncu kalmadiysa maci kapat
    if bagli_gercek_sayisi(state) == 0 then return nil end
    skor_yayinla(dispatcher, nk, state)
    return state
end

local function match_loop(ctx, logger, nk, dispatcher, tick, state, messages)
    -- 1) Gelen mesajlar (Faz 5: rate limit + dogrulama)
    local tick_msg = {}      -- [user_id] = bu tick'te islenen mesaj sayisi
    local hazir_degisti = false
    for _, msg in ipairs(messages) do
        local sender = msg.sender
        local uid    = sender.user_id

        -- Bilinmeyen gondericiyi yoksay
        local player = state.players[uid]
        if player then
            -- Rate limit: oyuncu basina tick limiti asilirsa kalan mesajlar atilir
            local n = (tick_msg[uid] or 0) + 1
            tick_msg[uid] = n
            if n <= MAX_MSG_PER_TICK then
                local op = msg.op_code
                local ok, data = pcall(nk.json_decode, msg.data or "{}")
                if not ok then data = {} end

                if op == OP_HAZIR then
                    -- Hazir yalnizca lobide anlamli (mac ortasi spam'i engellenir)
                    if state.phase == "lobby" then
                        local yeni = data.hazir == true
                        if player.hazir ~= yeni then
                            player.hazir = yeni
                            hazir_degisti = true
                        end
                    end
                elseif op == OP_CEVAP then
                    -- Yalniz soru fazinda, dogru soru indeksiyle, ilk cevap kabul edilir
                    if state.phase == "question"
                        and not state.answers[uid]
                        and tonumber(data.qi) == state.qi then
                        state.answers[uid] = {
                            correct = data.correct == true,
                            sn      = state.sn,
                        }
                    end
                end
            end
        end
    end
    -- Hazir durumu degistiyse tek seferde yayinla (mesaj basina degil → spam yok)
    if hazir_degisti then skor_yayinla(dispatcher, nk, state) end

    -- 2) Faz gecisleri
    if state.phase == "lobby" then
        local count, all_ready = 0, true
        for _, p in pairs(state.players) do
            count = count + 1
            if not p.hazir then all_ready = false end
        end
        -- En az 1 gercek oyuncu hazirsa basla; bos slotlar bota dolar
        if count >= 1 and all_ready then
            botlari_doldur(state)
            skor_yayinla(dispatcher, nk, state)   -- client botlari ogrensin
            state.phase   = "countdown"
            state.cd_left = 3
            dispatcher.broadcast_message(OP_SAYAC, nk.json_encode({sn = 3}), nil, nil, true)
            print("LingoDuel countdown started")
        end

    elseif state.phase == "countdown" then
        state.cd_left = state.cd_left - 1
        if state.cd_left <= 0 then
            state.qi = 0
            soru_basalt(dispatcher, nk, state)
            print("LingoDuel question 0 started")
        else
            dispatcher.broadcast_message(OP_SAYAC,
                nk.json_encode({sn = state.cd_left}), nil, nil, true)
        end

    elseif state.phase == "question" then
        bot_cevaplarini_enjekte(state)
        if hepsi_cevapladi(state) then
            yargila(dispatcher, nk, state)
        else
            state.sn = state.sn - 1
            if state.sn <= 0 then
                yargila(dispatcher, nk, state)
            else
                dispatcher.broadcast_message(OP_SAYAC,
                    nk.json_encode({sn = state.sn}), nil, nil, true)
            end
        end

    elseif state.phase == "reveal" then
        state.reveal_left = state.reveal_left - 1
        if state.reveal_left <= 0 then
            if state.qi + 1 >= state.total_q then
                mac_bitti(dispatcher, nk, state)
                state.phase = "finished"
                return nil
            else
                state.qi = state.qi + 1
                soru_basalt(dispatcher, nk, state)
            end
        end
    end

    return state
end

local function match_terminate(ctx, logger, nk, dispatcher, tick, state, grace)
    print("LingoDuel match_terminate")
    return nil
end

local function match_signal(ctx, logger, nk, dispatcher, tick, state, data)
    return state, data
end

return {
    match_init         = match_init,
    match_join_attempt = match_join_attempt,
    match_join         = match_join,
    match_leave        = match_leave,
    match_loop         = match_loop,
    match_terminate    = match_terminate,
    match_signal       = match_signal,
}
