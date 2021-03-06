#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtkglext'
require 'matrix.rb'
require 'image.rb'
require 'tools.rb'

class Point
  attr_accessor :x, :y
  def initialize(x,y)
    @x = x
    @y = y
  end

  def distance_to p
    Math::sqrt(
      (@x - p.x)**2 + 
      (@y - p.y)**2 
    )
  end
end


class Camera
  attr_accessor :position, :target
  def initialize
    @position = Vector[1.0, 1.0, 1.0]
    @target = Vector[0.0, 0.0, 0.0]
  end
  
  def view_vec
   @position.vector_to( @target ).normalize
  end
  
  def right_vec
   view_vec.cross_product( Vector[0,1,0] ).normalize
  end
  
  def up_vec
    view_vec.cross_product( right_vec ).normalize.invert
  end

  def move_up( value )
    @position += up_vec * value
    @target += up_vec * value
  end
  
  def move_right( value )
    @position += right_vec * value
    @target += right_vec * value
  end
  
  def move_forward( value )
    not_too_far = @position.vector_to(@target).length > value
    @position += view_vec * value if not_too_far
    not_too_far
  end

  def look_at( v )
    motion = @target.vector_to v
    @target += motion
    @position += motion
  end
  
  def look_at_plane( plane=Plane.new )
    @target = plane.origin
    @position = plane.origin + plane.normal_vector * 3 + Vector[0,0,0.1]
  end

  def rotate_around_up( value )
    #rotate_around( up_vec, value )
    @position += right_vec * value
    move_forward value.abs/3.0
  end
  
  def rotate_around_right( value )
    #rotate_around( right_vec, value )
    @position += up_vec * value
    move_forward value.abs/3.0
  end
  
  def stereo
    left, right = dup, dup
    left.position  = @position + right_vec * ($preferences[:eye_distance] / -160.0)
    right.position = @position + right_vec * ($preferences[:eye_distance] /  160.0)
    [left, right]
  end

private
  def rotate_around( axis, angle )
    # move camera temporarily with target to origin
    @position -= @target
    # rotate
    m = Matrix4x4::euler_rotation( axis, angle)
    @position = ( m * @position.vec4 ).vec3!
    # move target back to old position
    @position += @target
  end
end


def load_texture( im, id )
  raw = im.map{|pix| pix.to_a }.flatten.map{|p| (p * 255).round.to_i }.pack("C*")
  GL.BindTexture( GL::TEXTURE_2D, id )
  glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA, im.width, im.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, raw )
end


class GroundPlane
  def initialize res_x=32, res_y=32
    @res_x, @res_y = res_x, res_y
    @tex = GL.GenTextures(1)[0]
    GL.BindTexture( GL::TEXTURE_2D, @tex )
    GL.TexEnvf( GL::TEXTURE_ENV, GL::TEXTURE_ENV_MODE, GL::REPLACE )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_MIN_FILTER, GL_LINEAR )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_MAG_FILTER, GL_LINEAR )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_WRAP_S, GL::CLAMP )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_WRAP_T, GL::CLAMP )
    clean_up
  end
  
  def generate_shadowmap objects=$manager.project.all_part_instances.select{|p| p.visible }
    GC.enable
    @g_plane, @g_width, @g_height, @g_depth = ground objects
    @objects = objects
    if @g_plane and $manager.glview.render_shadows
      cancel = false
      progress = ProgressDialog.new( GetText._("<b>Rendering shadowmap...</b>") ){ cancel = true }
      progress.fraction = 0.0
      increment = 1.0 / @res_x 
      map = Image.new @res_x, @res_y
      for x in 0...@res_x
        break if cancel
        progress.fraction += increment
        progress.text = GetText._("Processing scanline ") + "#{x}/#{@res_x}"
        for y in 0...@res_y
          break if cancel
          pix = Pixel.new
          pix_finished = false
          for o in objects
            for face in o.solid.faces.select{|f| f.is_a? PlanarFace } #XXX should work with all facetypes
              face_dist = 0.0
              planar_loop = face.segments.map do |seg|
                #s = seg.dup
                #XXX convert from object to world space
                #s.pos1 = @g_plane.closest_point s.pos1
                #s.pos2 = @g_plane.closest_point s.pos2
                face_dist += (seg.pos1.y - @g_plane.origin.y).abs
                seg
              end
              face_dist /= face.segments.size
              poly = Polygon::from_chain planar_loop
              wx = @g_plane.origin.x - @g_width/2.0  + (x.to_f/@res_y)*@g_width
              wz = @g_plane.origin.z - @g_depth/2.0  + (y.to_f/@res_y)*@g_depth
              p = Point.new(wx,wz)
              if poly.contains? p
                value = 0.8 * (1.0 - face_dist/@g_height)
                if value > pix.red 
                  pix.red   = value
                  pix.green = value
                  pix.blue  = value
                  pix_finished = true
                  break #XXX let user decide between fast and accurate
                end
              end
            end
            break if pix_finished
          end
          map.set_pixel( x,y, pix )
        end
      end
      unless cancel
        map.gaussian_blur(3).gaussian_blur(3).each_pixel do |x,y, p|
          p.alpha = p.red
          p.red, p.green, p.blue = 0.0,0.0,0.0
          p.alpha = 0.0 if x == 0 or y == 0 or x == map.width-1 or y == map.height-1
          map.set_pixel(x,y, p)
        end
        load_texture( map, @tex )
      end
      progress.close
      $manager.glview.redraw
    end
  end
  
  def ground objects
    points = objects.map{|o| o.bounding_box }.flatten.compact
    unless points.empty?
      center, width, height, depth = sparse_bounding_box_from points
      origin = Vector[center.x, center.y - height/2.0 - 0.02, center.z]
      plane = Plane.new origin
      [plane, width * 1.6, height, depth * 1.6]
    else
      nil
    end
  end
  
  def draw_shadow
    GL.BindTexture( GL::TEXTURE_2D, @tex )
    GL.Enable( GL::TEXTURE_2D )
    GL.Disable( GL::LIGHTING )
    hw = @g_width/2.0
    hd = @g_depth/2.0
    GL.Begin( GL::QUADS )
      glTexCoord2f(1.0, 0.0)
      GL.Vertex( @g_plane.origin.x - hw, @g_plane.origin.y, @g_plane.origin.z + hd )
      glTexCoord2f(1.0, 1.0)
      GL.Vertex( @g_plane.origin.x + hw, @g_plane.origin.y, @g_plane.origin.z + hd )
      glTexCoord2f(0.0, 1.0)
      GL.Vertex( @g_plane.origin.x + hw, @g_plane.origin.y, @g_plane.origin.z - hd )
      glTexCoord2f(0.0, 0.0)
      GL.Vertex( @g_plane.origin.x - hw, @g_plane.origin.y, @g_plane.origin.z - hd )
    GL.End
  end
  
  def draw_floor
    GL.Disable( GL::TEXTURE_2D )
    GL.Disable( GL::LIGHTING )
    c = $preferences[:background_color].dup
    c.pop ; c.push 0.92
    GL.Color4f( *c )
    w = d = 200
    y = @g_plane.origin.y - 0.01
    GL.Begin( GL::QUADS )
      GL.Vertex( 0 - w, y, 0 + d )
      GL.Vertex( 0 + w, y, 0 + d )
      GL.Vertex( 0 + w, y, 0 - d )
      GL.Vertex( 0 - w, y, 0 - d )
    GL.End
  end
  
  def draw_reflection
      GL.Disable( GL::TEXTURE_2D )
      GL.Enable( GL::LIGHTING )
      GL.Enable( GL::NORMALIZE )
      GL.PushMatrix
        GL.Scalef(1.0,-1.0, 1.0)
        GL.Translate(0, -@g_plane.origin.y + 0.02, 0)
        #XXX lightsources should be mirrored as well
        @objects.each{|o| $manager.glview.draw_part o }
      GL.PopMatrix
      GL.Disable( GL::NORMALIZE )
  end
  
  def draw
    if @g_plane and $manager.glview.cameras[$manager.glview.current_cam_index].position.y > @g_plane.origin.y
      draw_reflection
      draw_floor
      draw_shadow if $manager.glview.render_shadows and not $manager.glview.displaymode == :wireframe
    end
  end
  
  def clean_up
    @objects = []
    map = Image.new @res_x, @res_y
    map.each_pixel do |x,y, p|
      p.alpha = 0.0
      map.set_pixel(x,y, p)
    end
    load_texture( map, @tex )
  end
end


class GLView < Gtk::DrawingArea
  attr_accessor :num_callists, :immediate_draw_routines, :selection_color
  attr_reader :displaymode, :ground, :cameras, :current_cam_index, :render_shadows, :stereo
  def initialize
    super
    @selection_color = [1,0,1]
    @displaymode = :overlay
    # these are called for immediate mode drawing
    @immediate_draw_routines = []
    @all_displaylists = []
    # camera handling stuff
    @max_remembered_views = 25
    @cameras = [Camera.new]
    @current_cam_index = 0
    @last_mouse_down_cam_position = Vector[0,0,0]
    @last_mouse_down_cam_rotation = Vector[0,0,0]
    @last_down = Point.new(0,0)
    @last_button_down = nil
    # configure buffers
    set_gl_capability( Gdk::GLConfig.new(
                       Gdk::GLConfig::MODE_RGB   |
                       Gdk::GLConfig::MODE_DEPTH |
                       Gdk::GLConfig::MODE_DOUBLE ) )
    # create GLScene as soon as drawpad is realized
    signal_connect_after("realize"){|w| realize }
    # redraw if window gets damaged
    signal_connect("expose_event"){|w,e| redraw }
    # user changed window size
    signal_connect("configure_event"){|w,e| configure }
    # handle mouse interaction
    add_events(Gdk::Event::BUTTON1_MOTION_MASK |
               Gdk::Event::BUTTON2_MOTION_MASK |
               Gdk::Event::BUTTON3_MOTION_MASK |
               Gdk::Event::POINTER_MOTION_MASK |
               Gdk::Event::BUTTON_PRESS_MASK   |
               Gdk::Event::BUTTON_RELEASE_MASK |
               Gdk::Event::SCROLL_MASK
    )
    signal_connect("button_press_event") do |widget, event|
      GC.disable if $preferences[:manage_gc]
      if event.button == 1
        if event.event_type == 5
          double_click( event.x, event.y )
        else
          press_left( event.x, event.y )
        end
      elsif event.button == 2
        @last_button_down = :middle
        @last_down = Point.new( event.x, event.y )
        click_middle( event.x, event.y )
      elsif event.button == 3
        press_right( event.x, event.y, event.time )
      end
      redraw
    end
    signal_connect("button_release_event") do |w,e| 
      case e.button
        when 1 then release_left( e.x, e.y )
        when 3 then release_right( e.x, e.y, e.time )
      end
      button_release( e.x, e.y ) 
    end
    signal_connect("motion_notify_event") do |widget, event|
      unless Gtk::events_pending?
        if @last_button_down == :left
          drag_left( event.x, event.y )
        elsif @last_button_down == :middle
          drag_middle( event.x, event.y )
        elsif @last_button_down == :right
          drag_right( event.x, event.y )
        else
          mouse_move( event.x, event.y )
        end
      end
    end
    signal_connect("scroll_event") do |widget, event|
      cam = @cameras[@current_cam_index]
      zoom_amount = cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity] * 0.2
      if event.direction == Gdk::EventScroll::UP
        cam.move_forward zoom_amount 
      else
        cam.move_forward -zoom_amount
      end
      redraw
    end
  end
  
  def mouse_move( x,y )
    $manager.current_tool.mouse_move( x,y )
  end
  
  def button_release( x,y )
    @last_button_down = nil
    $manager.current_tool.button_release
    if $preferences[:manage_gc]
      GC.enable
      GC.start
    end
  end
  
  def press_left( x,y )
    @last_button_down = :left
    @last_down = Point.new( x, y )
    if $manager.current_tool.is_a? CameraTool
      add_view
      @last_mouse_down_cam = @cameras[@current_cam_index].clone
    end
    $manager.current_tool.press_left( x,y )
    @button_press_time = Time.now
  end
  
  def release_left( x,y )
    $manager.current_tool.release_left
    click_left( x, y ) if @button_press_time and Time.now - @button_press_time < 1
  end
  
  def click_left( x,y )
    $manager.current_tool.click_left( x,y )
    redraw
  end
  
  def double_click( x,y )
    case $manager.current_tool
      when CameraTool then 
        target = screen2world( x,y )
        look_at target if target
    else
      $manager.current_tool.double_click( x,y )
    end
  end
  
  def click_middle( x,y )
    if $manager.current_tool.is_a? CameraTool
      add_view
      @last_mouse_down_cam = @cameras[@current_cam_index].clone
    end
    $manager.current_tool.click_middle( x,y )
  end
  
  def press_right( x,y, time )
    @last_button_down = :right
    @last_down = Point.new( x, y )
    if $manager.current_tool.is_a? CameraTool
      add_view
      @last_mouse_down_cam = @cameras[@current_cam_index].clone
    end
    $manager.current_tool.press_right( x,y, time )
    @button_press_time = Time.now
  end
  
  def release_right( x,y, time )
    $manager.current_tool.release_right
    click_right( x, y, time ) if @button_press_time and Time.now - @button_press_time < 1
  end
  
  def click_right( x,y, time )
    $manager.current_tool.click_right( x,y, time )
  end
  
  def drag_left( x,y )
    case $manager.current_tool
      when CameraTool then
        drag_x = (x - @last_down.x).to_f / allocation.width
        drag_y = (y - @last_down.y).to_f / allocation.height
        cam = @last_mouse_down_cam.clone
        cam.move_right -drag_x * 1.5 * cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity]
        cam.move_up drag_y * 0.8 * cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity]
        @cameras[@current_cam_index] = cam
        redraw
    else
      $manager.current_tool.drag_left( x,y )
    end
  end
  
  def drag_middle( x,y )
    case $manager.current_tool
      when CameraTool then
        drag_x = (x - @last_down.x).to_f / allocation.width
        drag_y = (y - @last_down.y).to_f / allocation.height
        cam = @last_mouse_down_cam.clone
        zoom_amount = drag_x * 3 * cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity]
        if cam.move_forward zoom_amount
          @cameras[@current_cam_index] = cam 
          redraw
        end
    else
      $manager.current_tool.drag_middle( x,y )
    end
  end
  
  def drag_right( x,y )
    case $manager.current_tool
      when CameraTool then
        drag_x = (x - @last_down.x).to_f / allocation.width
        drag_y = (y - @last_down.y).to_f / allocation.height
        cam = @last_mouse_down_cam.clone
        cam.rotate_around_up -drag_x * 5 * cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity]
        cam.rotate_around_right drag_y * 4 * cam.target.distance_to( cam.position ) * $preferences[:mouse_sensivity]
        @cameras[@current_cam_index] = cam
        redraw
    else
      $manager.current_tool.drag_right( x,y )
    end
  end
  
  def add_displaylist
    list = GL.GenLists(1)
    @all_displaylists << list
    return list
  end
  
  def delete_displaylist list
    @all_displaylists.delete list
    GL.DeleteLists( list, 1 ) if list
  end
  
  def delete_all_displaylists
    delete_displaylist @all_displaylists.pop until @all_displaylists.empty?
  end
  
  def realize
    glcontext = self.gl_context
    gldrawable = self.gl_drawable
    return unless gldrawable.gl_begin(glcontext)
    # define background
    GL.ClearColor( *$preferences[:background_color] )
    GL.ClearDepth(1.0)
    GL.ClearStencil(0.0)
    # set up lighting
    GL.Light(GL::LIGHT0, GL::DIFFUSE, $preferences[:first_light_color])
    GL.Light(GL::LIGHT0, GL::AMBIENT, [ 0.1, 0.1, 0.1, 1.0 ])
    GL.Light(GL::LIGHT0, GL::POSITION, $preferences[:first_light_position])
    GL.Light(GL::LIGHT1, GL::DIFFUSE, $preferences[:second_light_color])
    GL.Light(GL::LIGHT1, GL::AMBIENT, [ 0.1, 0.1, 0.1, 1.0 ])
    GL.Light(GL::LIGHT1, GL::POSITION, $preferences[:second_light_position])
    GL.Enable(GL::LIGHTING)
    GL.Enable(GL::LIGHT0)
    GL.Enable(GL::LIGHT1)
    # stuff
    GL.Enable(GL::DEPTH_TEST)
    GL.Hint(GL::PERSPECTIVE_CORRECTION_HINT, GL::NICEST)
    GL.Enable(GL_AUTO_NORMAL)
    GL.Enable(GL_NORMALIZE)
    GL.Enable(GL_MAP1_VERTEX_3)
    GL.PixelStorei(GL_UNPACK_ALIGNMENT, 1)
    # set stipple pattern for focus transparency
    GL.PolygonStipple [0xAA, 0xAA, 0xAA, 0xAA, 0x55, 0x55, 0x55, 0x55] * 16
    # make sure highlighting doesn't flicker
    GL.Enable(GL::POLYGON_OFFSET_FILL)
    GL.PolygonOffset(1.0, 1.0)
    # prepare shadows and reflections
    @ground = GroundPlane.new
    # load enviroment map
    @spheremap = GL.GenTextures(1)[0]
    GL.BindTexture( GL::TEXTURE_2D, @spheremap )
    GL.TexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE)
    GL.TexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP)
    GL.TexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP)
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_MIN_FILTER, GL_LINEAR )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_MAG_FILTER, GL_LINEAR )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_WRAP_S, GL::CLAMP )
    GL.TexParameterf( GL::TEXTURE_2D, GL::TEXTURE_WRAP_T, GL::CLAMP )
    map = Image.new('../data/icons/fx_spheremapping.png')
    map.each_pixel do |x,y, p|
      p.alpha = 0.99
      map.set_pixel(x,y, p)
    end
    load_texture( map, @spheremap )
    render_style :regular
    gldrawable.gl_end
  end
  
  def render_style style
    case style
    when :selection_pass
      GL.ShadeModel(GL::FLAT)
      GL.Disable(GL::DITHER)
      GL.Disable(GL::LINE_SMOOTH)
      GL.Disable(GL::BLEND)
    when :regular
      # setup model rendering
      GL.ShadeModel(GL::SMOOTH)
      GL.Enable(GL::DITHER)
      GL.Enable(GL::BLEND)
      GL.BlendFunc(GL::SRC_ALPHA, GL::ONE_MINUS_SRC_ALPHA)
      # setup line antialiasing
      if $preferences[:anti_aliasing]
        GL.Enable(GL::LINE_SMOOTH)
        GL.Hint(GL::LINE_SMOOTH_HINT, GL::NICEST)
      else
        GL.Disable(GL::LINE_SMOOTH)
      end
    end
  end
  
  def set_displaymode mode
    @displaymode = mode
    if mode == :shaded
      GL.Disable(GL::POLYGON_OFFSET_FILL)
    else
      GL.Enable(GL::POLYGON_OFFSET_FILL)
    end
    redraw
  end
  
  def configure
    glcontext = self.gl_context
    gldrawable = self.gl_drawable
    if gldrawable.gl_begin(glcontext)
      GL.Viewport(0, 0, allocation.width, allocation.height)
      GL.MatrixMode(GL::PROJECTION)
      GL.LoadIdentity
      aspect_ratio = allocation.width.to_f / allocation.height.to_f
      GLU.Perspective(40.0, aspect_ratio, 0.02, 60.0)
      GL.MatrixMode(GL::MODELVIEW)
      gldrawable.gl_end
      true
    else
      false
    end
  end
  
  def render_shadows= b
    @render_shadows = b
    @ground.generate_shadowmap
    redraw
  end
  
  def stereo= b
    @stereo = b
    redraw
  end
  
  def redraw
    glcontext = self.gl_context
    gldrawable = self.gl_drawable
    gldrawable.gl_begin( glcontext )
      glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
      GL.Clear(GL::COLOR_BUFFER_BIT)
      GL.Clear(GL::DEPTH_BUFFER_BIT)
      cam = @cameras[@current_cam_index]
      if @stereo and not @selection_pass
        glColorMask(GL_TRUE, GL_FALSE, GL_FALSE, GL_TRUE)
        draw cam.stereo.first
        GL.Clear(GL::DEPTH_BUFFER_BIT)
        glColorMask(GL_FALSE, GL_TRUE, GL_TRUE, GL_TRUE)
        draw cam.stereo.last
      else
        draw cam
      end
      gldrawable.swap_buffers unless @selection_pass or @picking_pass or @do_not_swap
    gldrawable.gl_end
  end
  
  def draw cam
      GL.Disable(GL::TEXTURE_2D)
      GL.LoadIdentity
      # setup camera position und rotation
      GLU.LookAt(cam.position.x, cam.position.y, cam.position.z,
                 cam.target.x,   cam.target.y,   cam.target.z,
                 cam.up_vec.x,   cam.up_vec.y,   cam.up_vec.z)
      # draw assembly components and sketches
      draw_coordinate_axes unless @do_not_swap
      GL.LineStipple(5, 0x1C47)
      recurse_draw $manager.project.main_assembly
      $manager.work_component.dimensions.each{|dim| recurse_draw dim }
      # draw 3d interface stuff
      GL.Disable(GL::LIGHTING)
      @immediate_draw_routines.each{|r| r.call } unless @selection_pass or @picking_pass
      @ground.draw unless @selection_pass or @picking_pass
  end
  
  def draw_part p
    [:shaded,  :overlay].any?{|e| e == @displaymode} ? (GL.Enable GL::LIGHTING) : (GL.Disable GL::LIGHTING)
    if p.transparent and $preferences[:stencil_transparency]
      GL.Enable GL::POLYGON_STIPPLE
      GL.Enable GL::LINE_STIPPLE
      GL.LineStipple(5, 0x1C47)
    end
    GL.Color4f( *$preferences[:background_color] )
    unless @picking_pass and $manager.work_sketch
      if [:shaded,  :overlay, :hidden_lines ].any?{|e| e == @displaymode}
        unless @displaymode == :hidden_lines
          if p.information[:material].reflectivity > 0
            GL.BindTexture( GL::TEXTURE_2D, @spheremap )
            glEnable(GL_TEXTURE_GEN_S)
            glEnable(GL_TEXTURE_GEN_T)
            glEnable(GL_TEXTURE_2D)
          end
        end
        glMaterial(GL_FRONT_AND_BACK, GL_DIFFUSE, p.information[:material].color + [1.0])
        s = p.information[:material].specularity
        glMaterial(GL_FRONT_AND_BACK, GL_SPECULAR, [s, s, s, 1.0])
        glMaterial(GL_FRONT_AND_BACK, GL_SHININESS, p.information[:material].smoothness)
        GL.CallList p.displaylist
        glDisable(GL_TEXTURE_GEN_S)
        glDisable(GL_TEXTURE_GEN_T)
        glDisable(GL_TEXTURE_2D)
      end
      p.selected ? GL.Color3f(1,0,0) : GL.Color3f(1,1,1)
      GL.CallList p.wire_displaylist if [:overlay, :wireframe, :hidden_lines ].any?{|e| e == @displaymode} or p.selected
      p.draw_cog
    end
    GL.Disable GL::POLYGON_STIPPLE
    GL.Disable GL::LINE_STIPPLE
  end
  
  def recurse_draw top_comp
    if top_comp.visible
      GL.PushMatrix
      #XXX rotate 
      ### ------------------------ Assembly ------------------------ ###
      if top_comp.class == Assembly
        GL.Translate( top_comp.position.x, top_comp.position.y, top_comp.position.z )
        top_comp.components.each{|c| recurse_draw c }
        top_comp.draw_cog unless @picking_pass or @selection_pass
      ### -------------------------- Part -------------------------- ###
      elsif top_comp.class == Part
        GL.Translate( top_comp.position.x, top_comp.position.y, top_comp.position.z )
        if @selection_pass
          GL.Disable GL::LIGHTING
          GL.CallList top_comp.selection_displaylist unless $manager.work_sketch
        else
          draw_part top_comp
        end
        top_comp.working_planes.each{|wp| recurse_draw wp }
        top_comp.unused_sketches.each{|sketch| recurse_draw sketch }
        if $manager.work_operator
          op_sketch = $manager.work_operator.settings[:sketch] 
          recurse_draw op_sketch if op_sketch
        end
        recurse_draw $manager.work_sketch if $manager.work_sketch
      ### ------------------------- Sketch ------------------------- ###
      elsif top_comp.class == Sketch
        GL.Translate( top_comp.plane.origin.x, top_comp.plane.origin.y, top_comp.plane.origin.z )
        GL.Disable(GL::LIGHTING)
        if @selection_pass
          top_comp.selection_pass = true
          top_comp.build_displaylist
          GL.LineWidth(12)
          GL.CallList( top_comp.displaylist )
          top_comp.selection_pass = false
          top_comp.build_displaylist
        else
          GL.LineWidth(4)
          GL.CallList( top_comp.displaylist )
        end
      ### ---------------------- Working plane ---------------------- ###
      elsif top_comp.class == WorkingPlane
        GL.Translate( top_comp.origin.x, top_comp.origin.y, top_comp.origin.z )
        GL.Disable(GL::LIGHTING)
        c = top_comp.selection_pass_color
        GL.Color3f( c[0],c[1],c[2] ) if c
        GL.Disable(GL::POLYGON_OFFSET_FILL)
        GL.CallList( (@picking_pass or @selection_pass == :select_planes or @selection_pass == :select_faces_and_planes) ? top_comp.pick_displaylist : top_comp.displaylist )
        GL.Enable(GL::POLYGON_OFFSET_FILL)
      ### ---------------------- Dimension ---------------------- ###
      elsif top_comp.is_a? Dimension
        top_comp.selection_pass = true if @selection_pass
        top_comp.draw
        top_comp.selection_pass = false
      end
      GL.PopMatrix
    end
  end
  
  def restore_backbuffer
    @do_not_swap = true
    redraw
    @do_not_swap = false
  end
  
  def screen2world( x, y )
    modelview  = GL.GetDoublev( GL::MODELVIEW_MATRIX )
    projection = GL.GetDoublev( GL::PROJECTION_MATRIX )
    viewport   = GL.GetDoublev( GL::VIEWPORT )
    y = allocation.height - y
    # render back buffer in pick mode
    @picking_pass = true
    redraw
    @picking_pass = false
    # check if we hit something by comparing pixel color to background
    col = GL.ReadPixels( x,y, 1,1, GL::RGB, GL::UNSIGNED_BYTE )
    col = [ col[0] / 255.0, col[1] / 255.0, col[2] / 255.0 ]
    diff = 0
    col.zip $preferences[:background_color] do |colcomp, backcomp|
      diff += (colcomp - backcomp).abs
    end
    if diff > 0.01
      # read z-buffer value at pixel
      z = GL.ReadPixels( x,y, 1,1, GL::DEPTH_COMPONENT, GL::FLOAT ).unpack("f")[0]
      # convert to world space
      pos = GLU.UnProject( x, y, z, modelview, projection, viewport )
      pos = Vector[ pos[0], pos[1], pos[2] ]
      # resolution of the depth buffer is low, so we correct the point position
      pos = $manager.work_sketch.plane.closest_point pos if $manager.work_sketch
    else
      pos = nil
    end
    restore_backbuffer
    return pos
  end
  
  def world2screen( v )
    modelview  = GL.GetDoublev( GL::MODELVIEW_MATRIX )
    projection = GL.GetDoublev( GL::PROJECTION_MATRIX )
    viewport   = GL.GetDoublev( GL::VIEWPORT )
    # convert to screen space
    pos = GLU.Project( v.x, v.y, v.z, modelview, projection, viewport )
    pos = Point.new( pos[0], pos[1] )
    return pos
  end
  
  def rebuild_selection_pass_colors type=nil
    if type or $manager.current_tool.is_a?(SelectionTool)
      case type or $manager.current_tool.selection_mode
      when :select_faces
        @selectables = $manager.project.all_part_instances.select{|inst| inst.visible }.map{|inst| inst.solid.faces }.flatten
      when :select_planes
        @selectables = $manager.work_component.working_planes
      when :select_faces_and_planes
        @selectables = $manager.work_component.working_planes.dup
        @selectables += $manager.project.all_part_instances.select{|inst| inst.visible }.map{|inst| inst.solid.faces }.flatten
      when :select_instances
        @selectables = $manager.project.all_part_instances.select{|inst| inst.visible }
      when :select_segments
        if $manager.work_sketch
          @selectables = $manager.work_sketch.segments
        else
          @selectables = $manager.work_component.unused_sketches.map{|sk| sk.segments }.flatten if $manager.work_component.class == Part
        end
      when :select_dimensions
        @selectables = $manager.work_component.dimensions
      when :select_segments_and_dimensions
        @selectables = $manager.work_sketch.segments.dup
        @selectables += $manager.work_component.dimensions
      when :select_faces_and_dimensions
        @selectables = $manager.project.all_part_instances.select{|inst| inst.visible }.map{|inst| inst.solid.faces }.flatten
        @selectables += $manager.work_component.dimensions
      end
      # create colors to represent selectable objects
      current_color = [0, 0, 0]
      @color_increment = 1.0 / 255
      i = 0
      parts_to_build = []
      @selectables.each do |s|
        s.selection_pass_color = current_color.dup
        if s.class == Part
          s.solid.faces.each{|f| f.selection_pass_color = current_color.dup }
          s.build_selection_displaylist 
        elsif s.is_a? Face
          parts_to_build << s.created_by_op.part
        end
        current_color[i] += @color_increment
        raise "maximum number of colors reached" if current_color[i] >= 1
        i == 2 ? i = 0 : i += 1 
      end
      parts_to_build.uniq.each{|p| p.build_selection_displaylist }
    end
  end
  
  def select( x, y, type=true )
    if @selectables
      # corect coords from gtk to GL orientation
      y = allocation.height - y
      # change rendering style to aliased, flat-color rendering
      render_style :selection_pass
      # render colorcoded scene to the back buffer
      @selection_pass = type
      redraw
      @selection_pass = false
      # look up color under cursor
      color_bytes = GL.ReadPixels( x,y, 1,1, GL::RGB, GL::UNSIGNED_BYTE )
      color = [ color_bytes[0] / 255.0, color_bytes[1] / 255.0, color_bytes[2] / 255.0 ]
      # select corresponding object
      obj = nil
      best_diff = 9999
      @selectables.each do |inst| 
        obj_color = inst.selection_pass_color
        diff = 0
        3.times{|i| diff += (obj_color[i] - color[i]).abs }
        if diff < best_diff 
          best_diff = diff
          obj = inst
        end
      end
      obj = nil unless best_diff < @color_increment
      $manager.work_component.unused_sketches.each{|sk| sk.build_displaylist } if $manager.work_component.class == Part
      # reset regular rendering style
      render_style :regular
      restore_backbuffer
      return obj
    end
    return nil
  end
  
  def view_transition( from_cam, to_cam )
    GC.disable if $preferences[:manage_gc]
    if $preferences[:view_transitions]
      @cameras.insert( @current_cam_index, Camera.new )
      steps = $preferences[:transition_duration]
      1.upto( steps ) do |i|
        @cameras[@current_cam_index].position = from_cam.position / steps * (steps - i)  +  to_cam.position / steps * i
        @cameras[@current_cam_index].target   = from_cam.target   / steps * (steps - i)  +  to_cam.target   / steps * i
        redraw
      end
      @cameras.delete_at( @current_cam_index )
    end
    GC.enable if $preferences[:manage_gc]
  end
  
  def look_at_selection
    old = @cameras[@current_cam_index]
    add_view
    neu = @cameras[@current_cam_index]
    neu.look_at_plane
    view_transition( old, neu )
    redraw
  end
  
  def look_at target
    old = @cameras[@current_cam_index]
    add_view
    neu = @cameras[@current_cam_index]
    neu.look_at target
    view_transition( old,neu )
    redraw
  end
  
  def zoom_onto objects
    corners = objects.map{|e| e.bounding_box }.flatten.compact
    unless corners.empty?
      add_view
      cog = corners.inject(Vector[0,0,0]){|sum,c| sum + c } / corners.size
      look_at cog
      cam = @cameras[@current_cam_index]
      width = allocation.width
      height = allocation.height
      GC.disable if $preferences[:manage_gc]
      # move towards objects
      while corners.map{|c| world2screen c }.all?{|p| (0...width).include? p.x and (0...height).include? p.y }
        cam.move_forward 0.02
        redraw
      end
      # move away from objects
      while not corners.map{|c| world2screen c }.all?{|p| (0...width).include? p.x and (0...height).include? p.y }
        cam.move_forward -0.02
        redraw
      end
      GC.enable if $preferences[:manage_gc]
    end
  end
  
  def zoom_selection
    sel = $manager.selection.empty? ? [$manager.project.main_assembly] : $manager.selection
    zoom_onto sel
  end
  
  def previous_view
    if @current_cam_index > 0
      current = @cameras[@current_cam_index]
      previous = @cameras[@current_cam_index - 1]
      view_transition( current, previous )
      @current_cam_index -= 1
      redraw
    end
    set_view_buttons
  end
  
  def next_view
    if @current_cam_index < @cameras.size - 1
      current = @cameras[@current_cam_index]
      nekst = @cameras[@current_cam_index + 1]
      view_transition( current, nekst )
      @current_cam_index += 1
      redraw
    end
    set_view_buttons
  end
  
  def add_view
    newcam = @cameras[@current_cam_index].clone
    @cameras.insert( @current_cam_index + 1, newcam )
    if @cameras.size > @max_remembered_views
      if @current_cam_index > @cameras.size / 2
        @cameras.delete( @cameras.first )
      else
        @cameras.delete( @cameras.last )
        @current_cam_index += 1
      end
    else
      @current_cam_index += 1
    end
    set_view_buttons
  end
  
  def set_view_buttons
    $manager.previous_btn.sensitive = (@current_cam_index > 0)
    $manager.next_btn.sensitive = (@current_cam_index < (@cameras.size - 1))
  end
  
  def draw_coordinate_axes at=Vector[0,0,0]
    GL.LineWidth(4)
    GL.Disable(GL::LIGHTING)
    GL.Begin( GL::LINES )
      GL.Color3f(0.5,0,0)
      GL.Vertex(at.x, at.y, at.z)
      GL.Vertex(at.x + 0.1, at.y, at.z)
      GL.Color3f(0,0.5,0)
      GL.Vertex(at.x, at.y, at.z)
      GL.Vertex(at.x, at.y + 0.1, at.z)
      GL.Color3f(0,0,0.5)
      GL.Vertex(at.x, at.y, at.z)
      GL.Vertex(at.x, at.y, at.z + 0.1)
    GL.End
  end
  
  def image_of_parts parts
    parts = [parts] unless parts.is_a? Array
    # find an instance of each part for rendering
    temp = []
    instances = parts.map do |part|
      inst = $manager.project.all_part_instances.select{|inst| inst.real_component == part }.first
      if inst
        inst
      else
        temp_inst = $manager.project.new_instance( part, false )
        temp.push temp_inst
        temp_inst
      end
    end
    im = image_of_instances instances
    temp.each{|t| $manager.delete_object t }
    redraw
    return im
  end
  
  def image_of_instances( instances, step=8, res=nil, name=nil )
    name = name ? name.shorten(16) : (instances.size == 1 ? instances.first.name.shorten(16) : "")
    # make screenshot of parts
    visible = {}
    $manager.project.all_part_instances.each{|p| visible[p] = p.visible ; p.visible = false }
    instances.each{|i| i.visible = true }
    @do_not_swap = true
    zoom_onto instances
    screen = screenshot step
    previous_view
    $manager.project.all_part_instances.each{|p| p.visible = visible[p] }
    @do_not_swap = false
    # render reflection and normalize size
    res ||= $preferences[:thumb_res]
    back = Image.new(res, res)
    object = screen.matte_floodfill(0,0).trim.resize_to_fit( res,res )
    composite = back.blend( object, 0.99, 0.01, Magick::CenterGravity )
    composite[:caption] = name
    composite = composite.polaroid
    redraw
    return composite
  end
  
  def screenshot( step=8, x=0, y=0, width=allocation.width, height=allocation.height )
    old_mode = @displaymode
    set_displaymode :shaded
    iwidth = width / step
    iheight = height / step
    im = Image.new( iwidth, iheight )
    ix, iy = 0, iheight-1
    x.step( x + width - 1, step ) do |sx|
      y.step( y + height - 1, step ) do |sy|
        pix = GL.ReadPixels( sx,sy, 1,1, GL::RGB, GL::FLOAT )
        comp_size = pix.size / 3
        r = pix[0..(comp_size-1)].unpack("f")[0]
        g = pix[comp_size..(2*comp_size-1)].unpack("f")[0]
        b = pix[(2*comp_size)..(3*comp_size-1)].unpack("f")[0]
        im.set_pixel( ix, iy, Pixel.new(r,g,b) ) unless ix >= iwidth or iy >= iheight
        iy -= 1
      end
      ix += 1
      iy = iheight-1
    end
    set_displaymode old_mode
    return im
  end
end












