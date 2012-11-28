require 'lubyk'
require 'app'
require 'bunny_geometry'

local V2 = four.V2
local V3 = four.V3
local Quat = four.Quat
local Transform = four.Transform
local Geometry = four.Geometry
local Effect = four.Effect
local Camera = four.Camera 
local Manip = four.Manip
local Color = four.Color

local effect = Effect 
{
  uniforms = 
    {  model_to_cam = Effect.modelToCamera,
       normal_to_cam = Effect.normalModelToCamera,
       cam_to_clip = Effect.cameraToClip,
       world_to_cam = Effect.worldToCamera,
       light_pos = V3(3, 5, 5),
       light_color = V3(1, 1, 1),
       Kd = V3(0.5, 0.5, 0.5)
    },

  vertex_in = { vertex = Effect.vec3,
                normal = Effect.vec3 },

  vertex_out = { v_position = Effect.vec4, 
                 v_normal = Effect.vec3 },

  vertex = Effect.Shader [[
     void main () 
     {
        v_position = model_to_cam * vec4(vertex, 1.0);
        v_normal = normal_to_cam * normal; 
        gl_Position = cam_to_clip * v_position;
     }
  ]],

  fragment_out = { f_color = Effect.vec4 },

  fragment = Effect.Shader [[
    void main () 
    {
      vec4 f_light_pos = world_to_cam * vec4(light_pos, 1.0);
      vec4 l = normalize(f_light_pos - v_position);
      float I = clamp(dot(normalize(v_normal), l.xyz), 0, 1);
      f_color = vec4(clamp(Kd * light_color * I, 0, 1), 1.0);
    }
  ]]
}

-- World

local angle = math.pi/4

local obj = 
  { transform = Transform { rot = Quat.rotZYX(V3(angle, angle, 0)) },
    geometry = four.Geometry.Cube(1),
    effect = effect }

local camera = Camera 
{ transform = Transform { pos = V3(0, 0, 5) },
  background = { color = Color(0.2, 0.3, 0.55), depth = 1.0 },
  range = V2(0.1, 10) }

local obj_geom_id = -1
function geometryWithID(i)
  collectgarbage()
  collectgarbage()
  local geoms =
    { function () return Geometry.Cube(1), V3(1, 1, 1) end,
      function () return Geometry.Sphere(0.5, 4), V3(1, 1, 1) end,
      function () return Geometry.Plane(four.V2(1,1)), V3(1, 1, 1) end,
      function () return bunny (), V3(6,6,6) end }
  return geoms[(i % #geoms) + 1]
end

-- Interaction

function command(app, c)
  if c.ExitFullscreen then app.win:showFullScreen(false) end
  if c.ToggleFullscreen then app.win:swapFullScreen() end
  if c.Resize then camera.aspect = V2.x(app.size) / V2.y(app.size) end
  if c.StartRotation then 
    local pos = camera:screenToDevice(c.pos) 
    app.rotator = Manip.Rot(obj.transform.rot, pos)
  end
  if c.Rotation then 
    local pos = camera:screenToDevice(c.pos)
    obj.transform.rot = Manip.rotUpdate(app.rotator, pos)
  end
  if c.MoveOut then 
    -- TODO factor that out 
    local forward = V3.unit(four.M4.col(four.Quat.toM4(camera.transform.rot),3))
    camera.transform.pos = camera.transform.pos + 0.2 * forward
  end
  if c.MoveIn then 
    -- TODO factor that out 
    local forward = V3.unit(four.M4.col(four.Quat.toM4(camera.transform.rot),3))
    camera.transform.pos = camera.transform.pos - 0.2 * forward
  end
  if c.CycleGeometry then
    obj_geom_id = obj_geom_id + 1; 
    local g, scale = geometryWithID(obj_geom_id)()
    g:computeVertexNormals()
    obj.geometry = g
    obj.transform.scale = scale
  end
  if c.SwapMode then 
    obj.effect.uniforms.mode = not obj.effect.uniforms.mode;
  end
  app.win:update()
end

function event(app, e) 
  local c = {} 
  if e.Resize then c.Resize = true end
  if e.KeyDown then 
    if e.key == mimas.Key_Escape then c.ExitFullscreen = true
    elseif e.key == mimas.Key_Space then c.ToggleFullscreen = true
    elseif e.key == mimas.Key_Down then c.MoveOut = true 
    elseif e.key == mimas.Key_Up then c.MoveIn = true
    elseif e.key == mimas.Key_Left then c.MoveLeft = true
    elseif e.key == mimas.Key_Right then c.MoveRight = true    
    elseif e.utf8 == 'g' then c.CycleGeometry = true
    elseif e.utf8 == 'm' then c.SwapMode = true
    end
  end
  if e.MouseDown then c.StartRotation = true c.pos = e.pos end
  if e.MouseMove then c.Rotation = true c.pos = e.pos end
  command(app, c)
end

-- Application

local app = App { event = event, camera = camera, objs = { obj } }

app.init()
command(app, { CycleGeometry = true })

run ()



