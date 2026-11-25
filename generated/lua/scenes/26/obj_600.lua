-- Рождественская атака босса: конфета летит в сторону игрока.
local E = require("runtime.engine")
return {
  scene_id = 26,
  object_id = 600,
  name = "Конфета Деда Мороза",
  scripts = {
    { trigger = "start", body = function(o) E.hide(o) end },
    { trigger = "clone", body = function(o)
      E.set_size(o, 55)
      E.show(o)
      E.face(o, 21)
      for _ = 1, 55 do
        E.go_steps(o, 12)
        local player = E.cb.obj_by_id(21)
        if player ~= 0 and math.abs(E.pos_x(o) - E.pos_x(player)) < 100
            and math.abs(E.pos_y(o) - E.pos_y(player)) < 100 then
          E.add_gv(3, -1)
          E.delete_clone(o)
          return
        end
        E.frame()
      end
      E.delete_clone(o)
    end },
  },
}
