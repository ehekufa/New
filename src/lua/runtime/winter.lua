-- Новогодний ивент «Мастерская Деда Мороза».
-- Три подобранных леденца дают часть подарка; две части открывают Деда Мороза
-- и один зимний скин — «Зимний куб» (с гирляндой).
local E = require("runtime.engine")
local M = {}
local candies, parts = 0, 0
local last_count, lifetime = 0, 0
local awarded = false
local SAVE_LAST, SAVE_PROGRESS, SAVE_AWARDED = "winter:last-candy", "winter:gift-parts", "winter:santa-unlocked"

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

function M.enter_scene(_scene)
  load_values()
end

function M.check_frame(_scene)
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
        E.toast("Подарок собран! Открыт Дед Мороз и Зимний куб!")
      end
    end
  elseif candies < last_count then
    -- Потраченные в мастерской леденцы не уменьшают найденные детали.
    last_count = candies
    E.cb.store_set(SAVE_LAST, tostring(last_count))
  end
end

return M
