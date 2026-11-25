-- engine.lua — рантайм блоков Pocket Code (то, во что компилируются scripts.txt).
--
-- Все игровые данные (позиции, картинки, слои) живут в C++-движке; здесь —
-- переменные, арифметика Pocket Code, тайминги и обёртки над C-API `cb`.
-- Имена функций повторяют имена блоков: E.set_pos -> SetPositionBrick и т.д.

local E = {}

local cb = assert(_G.cb, "движок не инициализирован: нет таблицы cb")

E.cb = cb

-- планировщик подключается из boot.lua
local scheduler
function E.set_scheduler(s) scheduler = s end

---------------------------------------------------------------- переменные

local gvars = {}          -- [id] = значение
local gnames = {}         -- [id] = имя (для диагностики)
local lvars = {}          -- [handle][id] = значение
local arrays = {}         -- [id] = {значения}

function E.define_variables(list)
  for _, v in ipairs(list) do
    gnames[v.id] = v.name
    if gvars[v.id] == nil then
      gvars[v.id] = v.value or ""
    end
  end
end

function E.var_name(id)
  return gnames[id] or ("var" .. tostring(id))
end

local function num(value)
  if type(value) == "number" then return value end
  if type(value) == "boolean" then return value and 1 or 0 end
  local n = tonumber(value)
  return n or 0
end
E.num = num

local function str(value)
  if value == nil then return "" end
  if type(value) == "number" then
    if value == math.floor(value) and math.abs(value) < 1e15 then
      return string.format("%d", value)
    end
    return string.format("%.14g", value)
  end
  if type(value) == "boolean" then return value and "true" or "false" end
  return tostring(value)
end
E.str = str

function E.truthy(value)
  if type(value) == "boolean" then return value end
  if type(value) == "number" then return value ~= 0 end
  if value == nil then return false end
  local s = tostring(value)
  return s ~= "" and s ~= "false" and s ~= "0"
end

-- переменные
function E.gv(id) return gvars[id] end

-- Аккаунт игрока (как в старой версии): 61 «Имя», 62 «Пароль». Логин и пароль
-- вводились на экране «Регистрация» (сцена 77), админ — тот, чья пара совпала.
E.account = {
  login_var = 61,
  password_var = 62,
  scene = 77,
  shown = false,          -- экран регистрации уже показан в этом запуске
  -- логин и пароль админа (те же, что в правилах Firebase, см. README)
  admin = { login = "admin", password = "Kenta2026" },
  -- пара автора из оригинала: пусть продолжает работать
  legacy = { { "1111", "1111" }, { "Dimasi4ek229", "5252" } },
  frozen = {},            -- [id] = true: значение пришло из --profile, не запоминаем
  announced = false,      -- игрок уже вошёл в меню с админским аккаунтом
}

-- клавиатура телефона любит приписать пробел и сделать первую букву заглавной,
-- поэтому логин сравниваем без пробелов и регистра, а пароль — без пробелов
local function trim(text)
  return (str(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

function E.login_entered()
  return trim(gvars[E.account.login_var])
end

function E.is_admin()
  local login = trim(gvars[E.account.login_var]):lower()
  local password = trim(gvars[E.account.password_var])
  local admin = E.account.admin
  if login == admin.login:lower() and password:lower() == admin.password:lower() then
    return true
  end
  for _, pair in ipairs(E.account.legacy) do
    if login == pair[1]:lower() and password:lower() == pair[2]:lower() then
      return true
    end
  end
  return false
end

function E.set_gv(id, value)
  -- админский режим (71) включается только с аккаунтом админа: кнопка
  -- «Админ панель» на экране «Онлайн» раньше открывала его любому
  if id == 71 and E.truthy(value) and E.is_admin() then
    E.admin_signin()        -- админ включил панель: входим в базу, чтобы правила пустили
  end
  if id == 71 and E.truthy(value) and not E.is_admin() then
    -- показываем, что именно игра прочитала в поле «Имя»: так видно, если
    -- логин набран с опечаткой или в него попал пробел
    local entered = E.login_entered()
    if entered == "" then
      E.toast("Нужен аккаунт админа: войдите на экране «Регистрация»")
    else
      E.toast("Нужен аккаунт админа (вход: «" .. entered .. "»)")
    end
    gvars[71] = 0
    return
  end
  gvars[id] = value
  -- Вход нигде не сохраняется: и ник, и пароль живут только до конца сессии.
end

-- Экран «Регистрация» каждый раз открывается с пустыми полями (просьба автора:
-- «при каждом перезаходе ник и пароль сбрасываются»). Значения из --profile —
-- это тесты, их не трогаем.
function E.clear_account()
  for _, var in ipairs({ E.account.login_var, E.account.password_var }) do
    if not E.account.frozen[var] then
      gvars[var] = ""
    end
  end
end
function E.add_gv(id, delta) gvars[id] = num(gvars[id]) + num(delta) end

function E.lv(o, id)
  local t = lvars[o]
  return t and t[id]
end
function E.set_lv(o, id, value)
  lvars[o] = lvars[o] or {}
  lvars[o][id] = value
end
function E.add_lv(o, id, delta)
  lvars[o] = lvars[o] or {}
  lvars[o][id] = num(lvars[o][id]) + num(delta)
end

function E.array(id)
  arrays[id] = arrays[id] or {}
  return arrays[id]
end
function E.array_add(id, value)
  local a = E.array(id)
  a[#a + 1] = value
  -- сразу сохраняем сезонные классы (Дед Мороз, Снежок-куб), чтобы они
  -- не пропадали после перезапуска
  E.array_save(id)
end
-- Конвертер зовёт это из выражения как E.array_contains(E.array(1), "..."),
-- то есть первым аргументом приходит уже сама таблица (а не id). Раньше это
-- создавало пустой массив по ключу-таблице и всегда возвращало false —
-- из-за чего сезонные классы не засчитывались.
function E.array_contains(id, value)
  local list = type(id) == "table" and id or E.array(id)
  for _, item in ipairs(list) do
    if str(item) == str(value) then return true end
  end
  return false
end

-- сохранение/чтение «на диск» (блоки saveVariable / readVariable)
function E.store_var(o, value, key)
  cb.store_set("var:" .. tostring(key), str(value))
end
function E.load_var(o, id)
  local stored = cb.store_get("var:" .. tostring(id))
  if stored ~= nil then
    gvars[id] = stored
  end
  return gvars[id]
end

---------------------------------------------------------------- операторы

-- Pocket Code сравнивает числа как числа, строки — как строки.
local function both_numbers(a, b)
  local na = tonumber(a)
  local nb = tonumber(b)
  if na ~= nil and nb ~= nil then
    return na, nb
  end
  return nil
end

function E.op_eq(a, b)
  local na, nb = both_numbers(a, b)
  if na then return na == nb end
  return str(a) == str(b)
end

function E.op_ne(a, b) return not E.op_eq(a, b) end

local function cmp(a, b)
  local na, nb = both_numbers(a, b)
  if na then return na, nb end
  return str(a), str(b)
end

function E.op_lt(a, b) local x, y = cmp(a, b); return x < y end
function E.op_gt(a, b) local x, y = cmp(a, b); return x > y end
function E.op_le(a, b) local x, y = cmp(a, b); return x <= y end
function E.op_ge(a, b) local x, y = cmp(a, b); return x >= y end

function E.op_add(a, b)
  local na, nb = both_numbers(a, b)
  if na then return na + nb end
  return str(a) .. str(b)                    -- «+» у Pocket Code клеит строки
end
function E.op_sub(a, b) return num(a) - num(b) end
function E.op_mul(a, b) return num(a) * num(b) end
function E.op_div(a, b)
  local d = num(b)
  if d == 0 then return 0 end
  return num(a) / d
end
function E.op_neg(a) return -num(a) end
function E.op_join(...)
  local out = {}
  for i = 1, select("#", ...) do
    out[i] = str((select(i, ...)))
  end
  return table.concat(out)
end

function E.round(v) return math.floor(num(v) + 0.5) end
function E.mod(a, b)
  local d = num(b)
  if d == 0 then return 0 end
  return num(a) % d
end
function E.log10(v) return math.log(num(v), 10) end
function E.truncate(v) return (num(v) >= 0) and math.floor(num(v)) or math.ceil(num(v)) end
function E.atan2deg(y, x) return math.deg(math.atan(y, x)) end
-- «random(1, 2)» в этом проекте значит «целое от 1 до 2»: им выбирают скин
-- врага и редкость яйца, а результат сравнивают через «=» (random(1,2) = 1).
-- Дробное значение не совпадало ни с одним целым, и, например, яйцо не давало
-- ничего. Поэтому для целых границ берём целое включительно, для остальных —
-- как в Pocket Code, дробное.
function E.random(a, b)
  a, b = num(a), num(b)
  if a > b then a, b = b, a end
  if a == b then return a end
  if a == math.floor(a) and b == math.floor(b) then
    return math.random(math.floor(a), math.floor(b))
  end
  return a + math.random() * (b - a)
end

function E.str_letter(index, text)
  local i = math.floor(num(index))
  return string.sub(str(text), i, i)
end
function E.str_length(text) return #str(text) end
function E.str_contains(text, part)
  return string.find(str(text), str(part), 1, true) ~= nil
end
function E.str_sub(text, start, length)
  local i = math.floor(num(start))
  local n = math.floor(num(length))
  return string.sub(str(text), i, i + n - 1)
end

---------------------------------------------------------------- тайминги

-- «Повторять всегда» из Pocket Code: отдельный поток, который крутится,
-- пока жива сцена. Раньше такой цикл застревал в теле скрипта и блокировал
-- всё, что стоит после него (джойстик, движение игрока).
function E.forever(fn)
  if not scheduler then
    while true do
      fn()
      E.frame()
    end
    return
  end
  scheduler:spawn(function()
    while true do
      fn()
      E.frame()
    end
  end, nil, "forever")
end

function E.wait(seconds)
  seconds = num(seconds)
  if seconds <= 0 then seconds = 0 end
  coroutine.yield(seconds)
end

function E.frame()
  coroutine.yield(0)
end

function E.wait_until(predicate, o)
  while not E.truthy(predicate()) do
    E.frame()
  end
end

function E.time_ms()
  return cb.time() * 1000
end

function E.mark(tag)
  cb.log("script " .. tostring(tag))
end

---------------------------------------------------------------- объекты

local function obj(o)
  return o
end

function E.pos_x(o) return cb.get(o, "x") end
function E.pos_y(o) return cb.get(o, "y") end
function E.rot(o) return cb.get(o, "rotation") end
function E.size(o) return cb.get(o, "size") end
function E.alpha(o) return cb.get(o, "alpha") end
function E.bright(o) return cb.get(o, "brightness") end
function E.layer(o) return cb.get(o, "layer") end
function E.visible(o) return cb.get(o, "visible") == 1 end
function E.obj_name(o) return cb.get(o, "name") end
-- Номер образа в Pocket Code считается с единицы («Враг (1)» = 1) — движок
-- уже отдаёт его так, поэтому здесь ничего не прибавляем.
function E.image_number(o) return cb.get(o, "image_index") end
function E.image_name(o) return cb.get(o, "image_name") end
function E.sound_count(o) return cb.get(o, "sound_count") end
function E.body_type(o) return "dynamic" end
function E.blend(name) return name end

function E.set_pos(o, x, y)
  cb.set(o, "x", num(x))
  cb.set(o, "y", num(y))
end
function E.set_x(o, x) cb.set(o, "x", num(x)) end
function E.set_y(o, y) cb.set(o, "y", num(y)) end
function E.add_x(o, dx) cb.set(o, "x", num(E.pos_x(o)) + num(dx)) end
function E.add_y(o, dy) cb.set(o, "y", num(E.pos_y(o)) + num(dy)) end
function E.set_rot(o, r) cb.set(o, "rotation", num(r)) end
function E.add_rot(o, d) cb.set(o, "rotation", num(E.rot(o)) + num(d)) end
function E.set_size(o, s) cb.set(o, "size", num(s)) end
function E.add_size(o, d) cb.set(o, "size", num(E.size(o)) + num(d)) end
function E.set_alpha(o, a) cb.set(o, "alpha", num(a)) end
function E.add_alpha(o, d) cb.set(o, "alpha", num(E.alpha(o)) + num(d)) end
function E.set_bright(o, b) cb.set(o, "brightness", num(b)) end
function E.set_layer(o, l) cb.set(o, "layer", num(l)) end
function E.show(o) cb.set(o, "visible", 1) end
function E.hide(o) cb.set(o, "visible", 0) end
function E.go_steps(o, steps) cb.go_steps(o, num(steps)) end

function E.set_image_by_id(o, id) cb.set_image_id(o, math.floor(num(id))) end
function E.next_image(o) cb.next_image(o) end

function E.go_to(o, object_id)
  local target = cb.obj_by_id(math.floor(num(object_id)))
  if target ~= 0 then
    E.set_pos(o, E.pos_x(target), E.pos_y(target))
  end
end
function E.go_to_self(o) return o end
function E.go_to_touch(o)
  E.set_pos(o, cb.touch_x(), cb.touch_y())
end
function E.face(o, object_id)
  local target = cb.obj_by_id(math.floor(num(object_id)))
  if target == 0 then return end
  local dx = E.pos_x(target) - E.pos_x(o)
  local dy = E.pos_y(target) - E.pos_y(o)
  E.set_rot(o, math.deg(math.atan(dx, dy)))
end
function E.obj_pos_x(object_id)
  local target = cb.obj_by_id(math.floor(num(object_id)))
  return target ~= 0 and E.pos_x(target) or 0
end

-- клоны
function E.clone(object_id)
  local target = cb.obj_by_id(math.floor(num(object_id)))
  if target ~= 0 then
    local handle = cb.clone(target)
    if handle ~= 0 and clone_handler then
      clone_handler(handle, cb.get(handle, "object_id"))
    end
    return handle
  end
  return 0
end
function E.clone_self(o)
  local handle = cb.clone(o)
  if handle ~= 0 and clone_handler then
    clone_handler(handle, cb.get(handle, "object_id"))
  end
end
function E.delete_clone(o)
  cb.delete(o)
end

---------------------------------------------------------------- события

-- обработчики подставляет boot.lua: клоны и «функции»
local clone_handler, function_handler
function E.on_clone(fn) clone_handler = fn end
function E.on_function(fn) function_handler = fn end

-- текущий объект исполняемого потока (ставит планировщик при возобновлении)
E.current_object = nil

-- «функция N» в модифицированном Pocket Code — точка входа, на которую
-- прыгают broadcastFunction / broadcastFun>object. Раньше эти вызовы
-- молча терялись, из-за чего джойстик не запускал движение игрока.
function E.call_function(id)
  if function_handler then
    function_handler(E.current_object, math.floor(num(id)))
  end
end

function E.broadcast_to_object(object_id, id)
  if function_handler then
    function_handler(math.floor(num(object_id)), math.floor(num(id)))
  end
end

function E.broadcast(id)
  if function_handler then
    function_handler(nil, math.floor(num(id)))     -- всем объектам сцены
  end
end

local warned = {}
function E.warn_once(key, message)
  if not warned[key] then
    warned[key] = true
    cb.log(message)
  end
end

---------------------------------------------------------------- ввод, касания

function E.touch_x() return cb.touch_x() end
function E.touch_y() return cb.touch_y() end
function E.touch_active() return cb.touch_down() == 1 end
function E.touch_count() return cb.touch_count() end
function E.touch_id() return cb.touch_id() end
function E.touch_x_by_id(i) return cb.touch_x_by_index(math.floor(num(i))) end
function E.touch_y_by_id(i) return cb.touch_y_by_index(math.floor(num(i))) end
function E.touch_id_by_index(i) return cb.touch_id_by_index(math.floor(num(i))) end

function E.touching_object(o, object_id)
  local target = cb.obj_by_id(math.floor(num(object_id)))
  if target == 0 then return false end
  return cb.hit_o(o, target) == 1
end

---------------------------------------------------------------- сцена, звук, система

-- Переключение сцены откладывается до конца кадра: сейчас мы внутри корутины
-- скрипта, и пересоздавать планировщик «на ходу» нельзя.
local pending_scene = nil
function E.run_scene(id)
  id = math.floor(num(id))
  -- После заставки старая версия показывала «Регистрацию» (сцена 77), и уже
  -- оттуда шла в меню. Возвращаем этот шаг: первый переход «загрузка -> меню»
  -- ведёт на регистрацию (кнопка «Не хочу» пропускает её сразу в меню).
  if id == 1 and not E.account.shown and E.has_scene and E.has_scene(E.account.scene) then
    E.account.shown = true
    id = E.account.scene
  end
  -- Сцена 99 («Онлайн (1)») — админский экран старой версии, в новой версии её
  -- нет. Скрытая кнопка «Онлайн (1)» на экране «Режимы» осталась от автора и
  -- вела в пустоту; ведём её на новый экран «Онлайн», где админ-панель.
  if id == 99 and E.has_scene and not E.has_scene(99) then
    id = 95
  end
  if id == 1 and E.is_admin() and not E.account.announced then
    E.account.announced = true
    E.toast("Аккаунт админа: " .. E.login_entered())
    E.admin_signin()          -- тихо входим в Firebase, чтобы правила пустили
  end
  if id == E.account.scene then
    E.clear_account()
  end
  pending_scene = id
  cb.log("runScene(" .. tostring(pending_scene) .. ") <- " ..
    string.gsub(debug.traceback("", 2), "\n", " | "))
end
function E.take_pending_scene()
  local value = pending_scene
  pending_scene = nil
  return value
end
function E.scene_name() return cb.scene_name() end
function E.stage_w() return cb.stage()[1] end
function E.stage_h() return cb.stage()[2] end

function E.play_sound(o, id) cb.play_sound(o, math.floor(num(id))) end
function E.play_sound_wait(o, id)
  cb.play_sound(o, math.floor(num(id)))
  E.wait(0.4)
end

function E.toast(text) cb.toast(str(text)) end
function E.open_link(url) cb.log("openLink: " .. str(url)) end
function E.exit_game() cb.exit() end
function E.set_bg_color(hex) cb.bg_color(str(hex)) end
function E.adaptive_off() end
-- Камера (блоки focusCameraToObject / removeObjectCamera).
-- focusCameraToObject делает объект точкой, на которую смотрит камера: всё, что
-- не помечено camera_off, рисуется со сдвигом. На этом в оригинале построена
-- прокрутка списка кубов (стрелки вверх/вниз двигают объект «Камера»).
-- camera_off помечает объект как «неподвижный»: кнопки «Назад», стрелки и фон
-- интерфейса остаются на месте, пока список едет.
function E.camera_off(o)
  if o ~= nil then
    cb.camera_off(o)
  end
end
function E.camera_focus(o, x, y)
  if o ~= nil then
    cb.camera_focus(o, num(x), num(y))
  end
end
function E.set_gravity(x, y) cb.log("gravity: " .. str(x) .. "," .. str(y)) end
function E.add_body(o, kind) cb.log("addBody(" .. str(kind) .. ")") end
function E.set_sensor(o, mode) cb.log("isSensor(" .. str(mode) .. ")") end
-- Размер экрана устройства (в оригинале — displayActualWidth/Height).
function E.display_width()
  local w = cb.stage()
  return w
end

function E.display_height()
  local _, h = cb.stage()
  return h
end

function E.set_hitbox(o, w, h) cb.log("hitbox " .. str(w) .. "x" .. str(h)) end
function E.noop() end
function E.unsupported(name)
  cb.unsupported(str(name))
end
function E.unknown_expr(name)
  cb.unsupported("expr:" .. str(name))
  return 0
end

-- Видео-интро: блоки createVideo/deleteVideo из новой версии. Сами ролики —
-- MP4 (их движок не декодирует), поэтому tools/extract_videos.py заранее режет
-- их на кадры в assets/videos/, а здесь мы просто листаем кадры по таймеру.
E.videos = {}                 -- id видео -> { prefix, frames, fps }
local video_token = 0         -- защита от двух роликов одновременно
local video_current = nil

function E.video_play(id)
  id = math.floor(num(id))
  local meta = E.videos and E.videos[id]
  if not meta then
    return
  end
  video_token = video_token + 1
  local token = video_token
  video_current = id
  local fps = tonumber(meta.fps) or 12
  local step = 1 / (fps > 0 and fps or 12)
  local frames = tonumber(meta.frames) or 0
  if frames < 1 then
    return
  end
  cb.log(string.format("видео: ролик %d «%s», %d кадров", id, tostring(meta.title or ""),
                       frames))
  local play = function()
    local i = 1
    while video_token == token do
      cb.video_frame(string.format(meta.prefix .. "f_%04d.png", i))
      i = i + 1
      if i > frames then
        i = frames                    -- ролик кончился — держим последний кадр
      end
      E.wait(step)
    end
  end
  if scheduler then
    scheduler:spawn(play, nil, "video")
  end
end

function E.video_stop(id)
  video_token = video_token + 1     -- останавливает листание кадров
  video_current = nil
  cb.video_stop()
end

function E.video_playing()
  return video_current ~= nil
end

-- Вход в Firebase по email/паролю (необязательный шаг). Пока Web API key не
-- задан, игра работает как раньше: пишет в базу без входа, и правила должны
-- пускать запись без auth. Как только ключ задан и админ вошёл, каждый запрос
-- уходит с ?auth=<idToken>, и правила могут требовать auth для админских узлов.
-- Web API key проекта circlebattle1 (не секрет: он публичный, лежит во всех
-- веб-приложениях Firebase; доступ ограничивают правилами базы).
E.FB_API_KEY = "AIzaSyAfOrOfz6om8ploshrkGIwDmlG7gF1-1-Y"
-- ключ можно подставить и переменной окружения (так делают тесты)
if cb.env then
  local env_key = cb.env("CB_FB_API_KEY")
  if env_key and env_key ~= "" then
    E.FB_API_KEY = env_key
  end
end
E.account.admin.email = "admin@cbclassic.local"
local auth_state = 0       -- 0 не входили, 1 ждём, 2 вошли, 3 ошибка

function E.admin_signin()
  -- Готовый токен (например, секрет базы) — входит без email/пароля.
  -- Задаётся переменной окружения CB_FB_DB_SECRET, в репозиторий не попадает:
  -- это настоящий секрет, из APK его достанет любой.
  if cb.env and cb.fb_set_token then
    local secret = cb.env("CB_FB_DB_SECRET")
    if secret and secret ~= "" and not E.db_secret_used then
      E.db_secret_used = true
      cb.fb_set_token(secret)
      return true
    end
  end
  if not cb.fb_auth then
    cb.log("firebase: вход недоступен (нет сети в сборке)")
    return false
  end
  if E.FB_API_KEY == "" then
    cb.log("firebase: вход не настроен — нет Web API key")
    return false
  end
  if auth_state == 1 or auth_state == 2 then
    return true
  end
  cb.fb_auth(E.FB_API_KEY, E.account.admin.email, trim(gvars[E.account.password_var]))
  auth_state = 1
  return true
end

function E.auth_poll()
  if not cb.fb_auth_state then
    return
  end
  if auth_state == 1 then
    local state = cb.fb_auth_state()
    if state == 2 then
      auth_state = 2
      E.auth_at = cb.time and cb.time() or 0
      cb.log("firebase: вход админа выполнен")
      E.toast("База: вход админа выполнен")
    elseif state == 3 then
      auth_state = 3
      cb.log("firebase: вход не удался: " .. tostring(cb.fb_auth_error and cb.fb_auth_error() or ""))
    end
    return
  end
  -- токен Firebase живёт час: за пять минут до конца входим заново, иначе
  -- посреди игры запись начнёт отваливаться с «Permission denied»
  if auth_state == 2 and E.auth_at and cb.time and E.is_admin() then
    if cb.time() - E.auth_at > 55 * 60 then
      auth_state = 0
      E.admin_signin()
    end
  end
end

-- «Firebase» эмулируется локальным хранилищем (см. engine.cpp: fb_*).
-- Адрес базы: в оригинале он был разбросан по десятку скриптов (три разных проекта
-- Firebase) — теперь один, здесь.
E.FB_URL = "https://circlebattle1-default-rtdb.firebaseio.com/"
-- сообщаем адрес движку: он ходит в базу сам (src/cpp/fbnet.cpp)
if cb.firebase_url then
  cb.firebase_url(E.FB_URL)
end
function E.fb_key(a, b, c)
  return str(a) .. "/" .. str(b) .. "/" .. str(c)
end
function E.fb_set(key, value, url)
  cb.firebase_set(str(key), str(value), E.FB_URL)
end
function E.fb_get(key, url, callback)
  local value = cb.firebase_get(str(key))
  if callback then callback(value) end
  return value
end

-- текстовые поля / показ переменных
-- Текстовые поля: EditText из Pocket Code. Если поле редактируемое и ему
-- передана переменная, подтверждённый ввод пишется в эту переменную.
E.text_vars = {}          -- [label] = id переменной
E.text_handlers = {}      -- [label] = function(value) — обработчик E.ask

function E.text_create(label, editable, w, h, varid)
  local name = str(label)
  -- В порте любое текстовое поле вводится с клавиатуры: флаг «off» из
  -- оригинала («Промокод» на сцене «Больше») означал не «только чтение»,
  -- а поле без подсказки — без него промокод ввести было некуда.
  local is_edit = true
  -- В Pocket Code EditText — тёмный текст в светлой рамке, размер подогнан
  -- под высоту поля (80 px -> примерно 35 px по высоте буквы).
  local height = num(h)
  local size = height > 0 and height * 1.5 or 40
  cb.text_create(name, 0, 0, num(w), height, "#000000", "left", is_edit and 1 or 0)
  cb.text_set(name, "value", str(E.gv(varid)))
  cb.text_set(name, "size", size)
  if is_edit and varid ~= nil then
    E.text_vars[name] = num(varid)
  end
end

-- Массивы проекта (достижения, введённые промокоды): saveArray кладёт
-- массив в локальное хранилище, readArray забирает обратно.
local function array_values(id)
  local list = E.array(id)
  local parts = {}
  for i = 1, #list do
    parts[#parts + 1] = tostring(list[i])
  end
  return list, parts
end

function E.array_save(id)
  local _, parts = array_values(id)
  cb.store_set("arr:" .. str(id), table.concat(parts, "\n"))
end

function E.array_load(id)
  local list = E.array(id)
  for i = #list, 1, -1 do
    list[i] = nil
  end
  local raw = cb.store_get("arr:" .. str(id)) or ""
  for line in string.gmatch(raw, "[^\n]+") do
    list[#list + 1] = line
  end
end

function E.array_clear(id)
  local list = E.array(id)
  for i = #list, 1, -1 do
    list[i] = nil
  end
  E.array_save(id)      -- очистка прогресса тоже должна остаться на диске
end

-- Вызывается из boot.lua, когда пользователь закончил ввод (Enter или
-- нажатие мимо поля).
function E.on_text_commit(label, value)
  local varid = E.text_vars[label]
  if varid then
    E.set_gv(varid, value)
  end
  local handler = E.text_handlers[label]
  if handler then
    E.text_handlers[label] = nil
    E.text_vars[label] = nil
    handler(value)
  end
end

function E.text_pending(label)
  return E.text_handlers[label] ~= nil
end

-- Блок AskBrick: показывает поле ввода и ждёт ответа, не блокируя остальные
-- скрипты (ждём через E.frame()).
-- Блок AskBrick: настоящий диалог, как в Pocket Code — вопрос крупным текстом,
-- поле ввода и кнопки «Отмена»/«Принять» (их рисует и обрабатывает движок).
-- Скрипт ждёт ответа, но кадры продолжают идти.
local ask_counter = 0
local ASK_FIELD_W = 520
local ASK_FIELD_H = 96
local ASK_FIELD_Y = 20
function E.ask(o, prompt, callback)
  ask_counter = ask_counter + 1
  local label = "Вопрос:" .. tostring(prompt) .. ":" .. tostring(ask_counter)
  cb.text_create(label, 0, ASK_FIELD_Y, ASK_FIELD_W, ASK_FIELD_H, "#ffffff", "center", 1)
  cb.text_set(label, "size", 96)         -- крупный ответ в белом поле
  cb.text_set(label, "placeholder", "ответ")
  cb.text_set(label, "value", "")
  cb.ask_open(str(prompt), label, ASK_FIELD_W, ASK_FIELD_H)
  cb.text_focus(label)
  local result = 0
  while result == 0 do
    E.frame()
    result = cb.ask_state()
  end
  local value = cb.text_value(label) or ""
  cb.ask_close()
  cb.text_delete(label)
  E.text_vars[label] = nil
  E.text_handlers[label] = nil
  if result > 0 then
    cb.log("ответ: " .. str(prompt) .. " = [" .. str(value) .. "]")
    if callback then
      callback(value)        -- «Принять»: ответ уходит в переменную
    end
  else
    cb.log("вопрос отменён: " .. str(prompt))
  end
end
function E.text_delete(label) cb.text_delete(str(label)) end
function E.text_set(label, field, a, b)
  cb.text_set(str(label), str(field), a, b)
end
E.var_texts = {}          -- ярлык -> id переменной (обновляется каждый кадр)
function E.text_show_var(varid, x, y, size, color, align)
  local label = "var:" .. tostring(varid)
  cb.text_create(label, num(x), num(y), 0, 0, str(color), str(align), 0)
  cb.text_set(label, "pos", num(x), num(y))     -- подпись «едет» за объектом
  cb.text_set(label, "value", str(E.gv(varid)))
  cb.text_set(label, "size", num(size))
  E.var_texts[label] = varid
end

-- анимации
function E.transition(o, duration, x, y)
  local steps = math.max(1, math.floor(num(duration) * 30))
  local sx, sy = num(E.pos_x(o)), num(E.pos_y(o))
  local dx = (num(x) - sx) / steps
  local dy = (num(y) - sy) / steps
  for _ = 1, steps do
    E.add_x(o, dx)
    E.add_y(o, dy)
    E.frame()
  end
  E.set_pos(o, x, y)
end

-- частицы (createRadialParticle / setPositionParticle): эффект рисует движок
function E.particles_create(o, label, image_id)
  cb.particles_create(o, str(label), math.floor(num(image_id)))
end
function E.particles_move(o, label, x, y)
  cb.particles_move(o, str(label), num(x), num(y))
end
function E.particles_stop(o, label)
  cb.particles_stop(o, str(label))
end

---------------------------------------------------------------- часы

function E.clock_second() return tonumber(os.date("%S")) end
function E.clock_minute() return tonumber(os.date("%M")) end
function E.clock_hour() return tonumber(os.date("%H")) end
function E.clock_day() return tonumber(os.date("%d")) end
function E.clock_month() return tonumber(os.date("%m")) end
function E.clock_year() return tonumber(os.date("%Y")) end
function E.loudness() return 0 end
function E.volume() return 100 end

return E
