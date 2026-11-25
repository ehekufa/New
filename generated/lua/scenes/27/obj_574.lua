-- Единственный зимний скин: «Зимний куб» с гирляндой.
local E = require("runtime.engine")
return {
  scene_id = 27,
  object_id = 574,
  name = "Зимний куб",
  scripts = {
    { trigger = "start", body = function(o)
      E.set_pos(o, 180, E.op_sub(E.op_sub(E.op_sub(E.op_sub(130, 240), 240), 240), 240))
      E.set_size(o, 70)
      if not E.truthy(E.array_contains(E.array(1), "WinterCubeSkin")) then E.set_bright(o, 60) end
    end },
    { trigger = "function:2", body = function(o) E.add_y(o, E.gv(48)) end },
    { trigger = "touch_down", body = function(o) E.set_bright(o, 85) end },
    { trigger = "touch_up", body = function(o)
      E.set_bright(o, 100)
      if E.truthy(E.array_contains(E.array(1), "WinterCubeSkin")) then
        E.set_gv(12, 12)
        E.run_scene(1) return
      end
      E.toast("Собери две части подарка в зимнем событии!")
    end },
  },
}
