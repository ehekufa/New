-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 96 "Достижения" / объект 556 "Зимняя битва подарков"
local E = require("runtime.engine")

return {
  scene_id = 96,
  object_id = 556,
  name = "Зимняя битва подарков",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_y(o, 25)
        if E.truthy((not E.truthy(E.array_contains(E.array(1), "WinterGiftBattle")))) then
          E.set_bright(o, 65)
        end
      end,
    },
    { -- скрипт 2: function:2
      trigger = "function:2",
      body = function(o)
        E.add_y(o, E.gv(48))
      end,
    },
  },
}
