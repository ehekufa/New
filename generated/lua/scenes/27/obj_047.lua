-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 27 "Кубы" / объект 47 "Снежинка"
local E = require("runtime.engine")

return {
  scene_id = 27,
  object_id = 47,
  name = "Снежинка",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_pos(o, 650, E.op_neg(150))
        E.set_size(o, 12)
        E.camera_off(o)
      end,
    },
  },
}
