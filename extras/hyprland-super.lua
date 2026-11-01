
-- Report both Super keys without consuming them or changing other shortcuts.
-- Transparent release bindings still run after another key/button was released.
for _, key in ipairs({ { "Super_L", "left" }, { "Super_R", "right" } }) do
  o.bind_hold(key[1], nil, "omarchy-shell -q omacorners superKey " .. key[2] .. " 1",
    nil, "omarchy-shell -q omacorners superKey " .. key[2] .. " 0",
    { ignore_mods = true, non_consuming = true, transparent = true })
end
