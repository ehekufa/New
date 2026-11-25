-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 1 "Меню" / объект 593 "Изумруды"
local E = require("runtime.engine")

return {
  scene_id = 1,
  object_id = 593,
  name = "Изумруды",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_pos(o, 205, 210)
        E.text_show_var(93, E.pos_x(o), E.op_sub(E.pos_y(o), 105), 110, "#FFFFFF", "center")
        E.set_size(o, 110)
      end,
    },
    { -- скрипт 2: touch_down
      trigger = "touch_down",
      body = function(o)
        E.set_bright(o, 85)
      end,
    },
    { -- скрипт 3: touch_up
      trigger = "touch_up",
      body = function(o)
        E.wait(E.num(0.04))
        E.set_bright(o, 100)
        E.wait(E.num(0.06))
        E.toast("В магазине яиц можно купить золотое леденец за эти изумруды")
      end,
    },
  },
}
