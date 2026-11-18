# Trailer capture

A filming aid for the Brelm trailer. It is never shipped: `tools/*` is left out of every export, and
`scripts/main.gd` only loads it when the game is started with `trailer=<shots.json>`.

- `trailer.gd` walks the shots in a JSON list. For each one it sets the hour, weather, lit beacons and
  forms, lets the land load around the eye, then flies a camera along a path (`"mode": "cine"`) or walks
  Brelm along one with a gun (`"mode": "fp"`, with `"fire"` and `"aim"` time windows). It writes the
  first and last frame of each shot to `trailer_cuts.json` in the user folder, so the frames spent
  loading between shots can be thrown away.
- `shots.json` is the shot list. Points are `[x, up, z]` metres about the shot's anchor (`"at"`: a town,
  beacon, ruin, the heart of a land, or `"xz"`), `up` above the ground there; or `{"ang", "dist", "up"}`.
- `override.cfg` is copied to the project folder when filming: own user folder (your saves are not
  touched), Movie Maker at 60 fps and JPEG quality 0.95.
- `render.ps1` does the whole run on Windows: gets Godot 4.3 and ffmpeg, films with Movie Maker,
  cuts each shot to its own MP4 with a contact sheet.

On Linux (slow without a GPU): copy override.cfg to the project, then
`godot --path . --resolution 960x540 --write-movie out.avi -- level=12 trailer=res://tools/trailer/shots.json only=s01_dawn_ash`.
