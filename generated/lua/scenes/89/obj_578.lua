-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 89 "Мастерская Деда Мороза" / объект 578 "Открыть леденец"
local E = require("runtime.engine")

return {
  scene_id = 89,
  object_id = 578,
  name = "Открыть леденец",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_pos(o, 400, E.op_sub(230, 95))
        E.camera_off(o)
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
        if E.truthy(E.op_gt(E.gv(80), 9)) then
          E.add_gv(80, E.op_neg(10))
          E.run_scene(104) return
        else
          E.toast("Недостаточно яиц!")
        end
      end,
    },
  },
}
