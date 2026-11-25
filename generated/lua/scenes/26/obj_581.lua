-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 26 "Игра" / объект 581 "Яйцо"
local E = require("runtime.engine")

return {
  scene_id = 26,
  object_id = 581,
  name = "Леденец",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.hide(o)
        E.forever(function()
          E.wait(E.num(2.2))
          E.clone_self(o)
        end)
      end,
    },
    { -- скрипт 2: clone
      trigger = "clone",
      body = function(o)
        E.set_pos(o, E.random(E.op_neg(580), 580), E.random(E.op_neg(245), 245))
        E.add_body(o, "static")
        E.set_sensor(o, "off")
        E.set_image_by_id(o, E.random(1, 2))
        E.show(o)
        E.wait_until(function() return E.truthy(E.touching_object(o, 21)) end, o)
        if not E.truthy(E.lv(o, 99)) then
          E.set_lv(o, 99, 1)
          E.add_gv(80, 1)
        end
        E.delete_clone(o) return
      end,
    },
    { -- можно подобрать леденец, нажав на него
      trigger = "touch_up",
      body = function(o)
        if E.visible(o) and not E.truthy(E.lv(o, 99)) then
          E.set_lv(o, 99, 1)
          E.add_gv(80, 1)
          E.delete_clone(o)
        end
      end,
    },
  },
}
