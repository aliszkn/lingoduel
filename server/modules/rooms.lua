-- LingoDuel — Oda yönetimi (RPC)
-- Odalar system user altında Storage'a yazılır, public read ile listelenir.
-- Aktif odalar: collection="active_rooms", key=roomId

local nk   = require("nakama")
local SYS  = "00000000-0000-0000-0000-000000000000"
local COLL = "active_rooms"
local TTL  = 7200  -- 2 saat (saniye)

-- ── Oda oluştur ───────────────────────────────────────────────────────────────
-- Payload: {isim, setId, tier, kapasite, hostAdi}
-- Dönen : room objesi (roomId, matchId, seed dahil)
local function create_room(context, payload)
    local data     = nk.json_decode(payload)
    local room_id  = nk.uuid_v4()
    local seed     = math.random(0, 2147483647)
    local kapasite = tonumber(data.kapasite) or 6

    -- Faz 3: sunucu-otoriter authoritative maç oluştur
    local match_id = nk.match_create("match_handler", {
        seed           = seed,
        kapasite       = kapasite,
        totalQuestions = 10,
    })

    local room = {
        roomId            = room_id,
        isim              = data.isim  or "Yeni Oda",
        setId             = data.setId or "A",
        tier              = data.tier  or "1K",
        kapasite          = kapasite,
        dolu              = 1,
        hostId            = context.user_id,
        hostAdi           = data.hostAdi or "Oyuncu",
        matchId           = match_id,
        seed              = seed,
        olusturulmaZamani = math.floor(nk.time() / 1000),
    }
    nk.storage_write({{
        collection       = COLL,
        key              = room_id,
        user_id          = SYS,
        value            = room,
        permission_read  = 2,
        permission_write = 0,
    }})
    return nk.json_encode(room)
end

-- ── Odaları listele ───────────────────────────────────────────────────────────
-- Payload: {} (yoksayılır)
-- Dönen : {rooms: [...]}
local function list_rooms(context, payload)
    local objects = nk.storage_list(SYS, COLL, 100, nil)
    local rooms   = {}
    local stale   = {}
    local now     = math.floor(nk.time() / 1000)

    for _, obj in ipairs(objects or {}) do
        local r = obj.value
        if (now - (r.olusturulmaZamani or 0)) > TTL then
            table.insert(stale, {collection = COLL, key = obj.key, user_id = SYS})
        else
            table.insert(rooms, r)
        end
    end
    if #stale > 0 then
        pcall(nk.storage_delete, stale)
    end
    return nk.json_encode({rooms = rooms})
end

-- ── Oda sil ───────────────────────────────────────────────────────────────────
-- Payload: {roomId}
local function delete_room(context, payload)
    local data = nk.json_decode(payload)
    if not data.roomId then return nk.json_encode({ok = false}) end
    pcall(nk.storage_delete, {{collection = COLL, key = data.roomId, user_id = SYS}})
    return nk.json_encode({ok = true})
end

-- ── Oda güncelle (doluluk + matchId) ─────────────────────────────────────────
-- Payload: {roomId, dolu?, matchId?}
local function update_room(context, payload)
    local data    = nk.json_decode(payload)
    if not data.roomId then return nk.json_encode({ok = false}) end
    local objects = nk.storage_read({{collection = COLL, key = data.roomId, user_id = SYS}})
    if not objects or #objects == 0 then return nk.json_encode({ok = false}) end
    local room = objects[1].value
    if data.dolu   ~= nil then room.dolu    = data.dolu   end
    if data.matchId ~= nil then room.matchId = data.matchId end
    nk.storage_write({{
        collection       = COLL,
        key              = data.roomId,
        user_id          = SYS,
        value            = room,
        permission_read  = 2,
        permission_write = 0,
    }})
    return nk.json_encode({ok = true, room = room})
end

nk.register_rpc(create_room,  "create_room")
nk.register_rpc(list_rooms,   "list_rooms")
nk.register_rpc(delete_room,  "delete_room")
nk.register_rpc(update_room,  "update_room")
