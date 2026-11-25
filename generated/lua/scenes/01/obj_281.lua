-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 1 "Меню" / объект 281 "Леденцы"
local E = require("runtime.engine")

return {
  scene_id = 1,
  object_id = 281,
  name = "Леденцы",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_pos(o, 575, E.op_neg(195))
        E.text_show_var(80, E.pos_x(o), E.op_add(E.pos_y(o), 160), 110, "#FFFFFF", "center")
      end,
    },
    { -- скрипт 2: touch_down
      trigger = "touch_down",
      body = function(o)
        E.set_bright(o, 95)
      end,
    },
    { -- скрипт 3: touch_up
      trigger = "touch_up",
      body = function(o)
        E.wait(E.num(0.04))
        E.set_bright(o, 100)
        E.wait(E.num(0.07))
        E.run_scene(89) return
      end,
    },
  },
}
