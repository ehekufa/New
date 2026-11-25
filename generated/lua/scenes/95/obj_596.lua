-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 95 "Онлайн" / объект 596 "Леденец"
local E = require("runtime.engine")

return {
  scene_id = 95,
  object_id = 596,
  name = "Леденец",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.hide(o)
        E.add_body(o, "dynamic")
        E.set_sensor(o, "off")
        E.forever(function()
          E.wait(E.num(0.1))
          if E.truthy(E.op_eq(E.gv(82), "3")) then
            E.show(o)
          else
            E.hide(o)
          end
        end)
      end,
    },
    { -- скрипт 2: start
      trigger = "start",
      body = function(o)
        E.forever(function()
          E.transition(o, 2.5, E.random(E.op_neg(580), 580), E.random(E.op_neg(245), 245))
        end)
      end,
    },
  },
}
