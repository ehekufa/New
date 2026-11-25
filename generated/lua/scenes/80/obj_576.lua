-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 80 "Классы" / объект 576 "Снежный кубик"
local E = require("runtime.engine")

return {
  scene_id = 80,
  object_id = 576,
  name = "Снежный кубик",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_y(o, E.op_sub(E.op_sub(E.op_sub(E.op_sub(25, 95), 95), 95), 95))
        if E.truthy((not E.truthy(E.array_contains(E.array(1), "WinterClass")))) then
          E.set_bright(o, 60)
        end
      end,
    },
    { -- скрипт 2: function:2
      trigger = "function:2",
      body = function(o)
        E.add_y(o, E.gv(48))
      end,
    },
    { -- скрипт 3: touch_down
      trigger = "touch_down",
      body = function(o)
        if E.truthy(E.op_eq(E.bright(o), 100)) then
          E.set_gv(47, 5)
          E.toast("Класс \"снежного кубика\" экипирован:")
        else
          E.toast("У вас нет его, открывайте леденцов для открытия!")
        end
      end,
    },
  },
}
