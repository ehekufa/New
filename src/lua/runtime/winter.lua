-- Новогодний ивент «Мастерская Деда Мороза».
-- Игровая валюта — леденцы (var:80). За каждые три подобранных леденца
-- игрок собирает одну часть подарка; две части открывают класс Деда Мороза.
local E = require("runtime.engine")
local M = {}
local LABEL = "hud:зимний фестиваль"
local COUNT = "hud:леденцы"
local MISSION = "hud:задание дед мороза"
local COLOR = "#fff4cf"
local candies, parts = 0, 0
local last_count, lifetime = 0, 0
local awarded = false
local SAVE_LAST, SAVE_PROGRESS, SAVE_AWARDED = "winter:last-candy", "winter:gift-parts", "winter:santa-unlocked"

local function draw(name, text, x, y, size)
  E.cb.text_create(name, x, y, 0, 0, COLOR, "center", 0)
  E.cb.text_set(name, "pos", x, y)
  E.cb.text_set(name, "size", size)
  E.cb.text_set(name, "color", COLOR)
  E.cb.text_set(name, "align", "center")
  E.cb.text_set(name, "value", text)
  E.cb.text_set(name, "visible", 1)
end

local function paint(scene)
  if scene ~= 1 and scene ~= 26 then
    E.cb.text_set(LABEL, "visible", 0)
    E.cb.text_set(COUNT, "visible", 0)
    E.cb.text_set(MISSION, "visible", 0)
    return
  end
  local _, h = E.cb.stage()
  local y = h / 2 - 155
  draw(LABEL, "МАСТЕРСКАЯ ДЕДА МОРОЗА", 0, y, 46)
  draw(COUNT, "Леденцы: " .. tostring(candies), 0, y - 48, 38)
  draw(MISSION, "Собери части подарка: " .. tostring(parts) .. "/2", 0, y - 88, 27)
end

local function load_values()
  candies = math.max(0, math.floor(tonumber(E.gv(80)) or 0))
  local saved_last = E.cb.store_get(SAVE_LAST)
  if saved_last == nil or saved_last == "" then
    last_count, lifetime = candies, 0
    E.cb.store_set(SAVE_LAST, tostring(last_count))
  else
    last_count = tonumber(saved_last) or candies
    lifetime = tonumber(E.cb.store_get(SAVE_PROGRESS)) or 0
  end
  parts = math.min(2, math.floor(lifetime / 3))
  awarded = E.cb.store_get(SAVE_AWARDED) == "1"
end

function M.enter_scene(scene)
  load_values()
  paint(scene)
end

function M.check_frame(scene)
  candies = math.max(0, math.floor(tonumber(E.gv(80)) or 0))
  if candies > last_count then
    lifetime = lifetime + (candies - last_count)
    last_count = candies
    E.cb.store_set(SAVE_LAST, tostring(last_count))
    E.cb.store_set(SAVE_PROGRESS, tostring(lifetime))
    local new_parts = math.min(2, math.floor(lifetime / 3))
    if new_parts > parts then
      parts = new_parts
      E.toast("Часть подарка " .. tostring(parts) .. "/2 найдена!")
      if parts == 2 and not awarded then
        E.array_add(1, "WinterClass")
        E.array_add(1, "WinterCubeSkin")
        E.cb.store_set(SAVE_AWARDED, "1")
        awarded = true
        E.toast("Подарок собран! Открыт кубик Деда Мороза!")
      end
    end
  elseif candies < last_count then
    -- Потраченные в мастерской леденцы не уменьшают уже найденные детали.
    last_count = candies
    E.cb.store_set(SAVE_LAST, tostring(last_count))
  end
  paint(scene)
end

return M
