-- АВТОГЕНЕРАЦИЯ: tools/catrobat2lua.py — не редактировать вручную.
-- Сцена 26 "Игра" / объект 22 "Враг"
local E = require("runtime.engine")

return {
  scene_id = 26,
  object_id = 22,
  name = "Враг",
  scripts = {
    { -- скрипт 1: start
      trigger = "start",
      body = function(o)
        E.set_pos(o, E.op_neg(500), 200)
        E.set_size(o, 350)
        E.set_gv(4, 20)
        E.add_body(o, "static")
        E.set_hitbox(o, 115, 115)
        E.set_image_by_id(o, E.random(1, 2))
        E.set_gv(28, E.image_number(o))
        E.wait(E.num(3.2))
        E.forever(function()
          if E.truthy(E.op_eq(E.gv(85), 0)) then
            E.face(o, 21)
            E.go_steps(o, 3.3)
          end
          E.set_gv(43, E.rot(o))
          E.text_show_var(4, E.pos_x(o), E.op_add(E.pos_y(o), 125), 185, "#FF0000", "center")
        end)
      end,
    },
    { -- скрипт 2: when_truth
      trigger = "when_truth",
      cond = function(o) return E.truthy(E.touching_object(o, 247)) end,
      body = function(o)
        E.go_steps(o, E.op_neg(100))
        E.add_gv(4, E.op_neg(5))
      end,
    },
    { -- скрипт 3: function:3
      trigger = "function:3",
      body = function(o)
        E.go_steps(o, E.op_neg(90))
      end,
    },
    { -- скрипт 4: start
      trigger = "start",
      body = function(o)
        if E.truthy(E.truthy(E.op_eq(E.image_number(o), 2)) and E.truthy(E.op_eq(E.gv(47), 1))) then
          E.toast("My...  darling???")
          E.play_sound(o, 31)
        end
        if E.truthy(E.truthy(E.op_eq(E.image_number(o), 2)) and E.truthy(E.op_eq(E.gv(47), 4))) then
          E.toast("I'll hack you, Nastya!")
          E.play_sound(o, 34)
        end
      end,
    },
    { -- новогодняя атака: босс выпускает конфету примерно раз в 2.8 секунды
      trigger = "start",
      body = function(o)
        E.wait(E.num(3.4))
        E.forever(function()
          local candy = E.clone(600)
          if candy and candy ~= 0 then
            E.set_pos(candy, E.pos_x(o), E.pos_y(o))
            E.set_size(candy, 55)
            E.show(candy)
          end
          E.wait(E.num(2.8))
        end)
      end,
    },
  },
}
