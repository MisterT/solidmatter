#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtkglext'
require 'lib/matrix.rb'
require 'lib/image.rb'
require 'lib/tools.rb'

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
	 @position += view_vec * value
	end

	def look_at( v )
	  motion = @target.vector_to v
    @target += motion
    @position += motion
	end
	
	def look_at_plane( plane=Plane.new )
    @target = plane.origin
    @position = plane.origin + plane.normal_vector * 3 + Vector[0,0,-0.1]
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


class GLView < Gtk::DrawingArea
	attr_accessor :num_callists, :immediate_draw_routines, :manager, :selection_color
	def initialize
		super
		@manager = nil
		@selection_color = [1,0,1]
		# these are called for immediate mode drawing
		@immediate_draw_routines = []
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
	             Gdk::Event::BUTTON_RELEASE_MASK
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
				@last_button_down = :right
				@last_down = Point.new( event.x, event.y )
				click_right( event.x, event.y, event.time )
			end
			redraw
		end
		signal_connect("button_release_event") do |w,e| 
		  button_release( e.x, e.y ) 
		  release_left( e.x, e.y ) if e.button == 1
	  end
		signal_connect("motion_notify_event") do |widget, event|
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
	
	def mouse_move( x,y )
		@manager.current_tool.mouse_move( x,y )
	end
	
	def press_left( x,y )
	  @last_button_down = :left
		@last_down = Point.new( x, y )
		if @manager.current_tool.is_a? CameraTool
			add_view
			@last_mouse_down_cam = @cameras[@current_cam_index].clone
		end
		@manager.current_tool.press_left( x,y )
    @button_press_time = Time.now
	end
	
	def release_left( x,y )
	  @manager.current_tool.release_left
	 	click_left( x, y ) if @button_press_time and Time.now - @button_press_time < 0.5
	end
	
	def click_left( x,y )
		@manager.current_tool.click_left( x,y )
		redraw
	end
	
	def double_click( x,y )
		case @manager.current_tool
			when CameraTool then 
				target = screen2world( x,y )
				look_at target if target
		else
			@manager.current_tool.double_click( x,y )
		end
	end
	
	def button_release( x,y )
	  @last_button_down = nil
	  @manager.current_tool.button_release
	  if $preferences[:manage_gc]
	  	GC.enable
	  	GC.start
	  end
	end
	
	def click_middle( x,y )
		case @manager.current_tool
			when CameraTool then
				add_view
				@last_mouse_down_cam = @cameras[@current_cam_index].clone
		else
			@manager.current_tool.click_middle( x,y )
		end
	end
	
	def click_right( x,y, time )
		case @manager.current_tool
			when CameraTool then
				add_view
				@last_mouse_down_cam = @cameras[@current_cam_index].clone
		else
			@manager.current_tool.click_right( x,y, time )
			button_release( x,y ) # btn does not get released when pop-up is open
		end
	end
	
	def drag_left( x,y )
		case @manager.current_tool
			when CameraTool then
			  drag_x = (x - @last_down.x).to_f / allocation.width
				drag_y = (y - @last_down.y).to_f / allocation.height
				cam = @last_mouse_down_cam.clone
				cam.move_right -drag_x * 2
				cam.move_up drag_y * 2
				@cameras[@current_cam_index] = cam
				redraw
		else
			@manager.current_tool.drag_left( x,y )
		end
	end
	
	def drag_middle( x,y )
		case @manager.current_tool
			when CameraTool then
			  drag_x = (x - @last_down.x).to_f / allocation.width
  			drag_y = (y - @last_down.y).to_f / allocation.height
				cam = @last_mouse_down_cam.clone
				cam.move_forward drag_x * 4
				@cameras[@current_cam_index] = cam
				redraw
		else
			@manager.current_tool.drag_middle( x,y )
		end
	end
	
	def drag_right( x,y )
		case @manager.current_tool
			when CameraTool then
			  drag_x = (x - @last_down.x).to_f / allocation.width
				drag_y = (y - @last_down.y).to_f / allocation.height
				cam = @last_mouse_down_cam.clone
				cam.rotate_around_up -drag_x * 6
				cam.rotate_around_right drag_y * 6
				@cameras[@current_cam_index] = cam
				redraw
		else
			@manager.current_tool.drag_right( x,y )
		end
	end
	
	def add_displaylist
		list = GL.GenLists(1)
		return list
	end
	
	def realize
		glcontext = self.gl_context
		gldrawable = self.gl_drawable
		return unless gldrawable.gl_begin(glcontext)
		# define background
		@background_color = [0.3, 0.3, 0.3, 1.0]
		GL.ClearColor( *@background_color )
		GL.ClearDepth(1.0)
		# set up lighting
		GL.Light(GL::LIGHT0, GL::DIFFUSE, $preferences[:first_light_color])
		GL.Light(GL::LIGHT0, GL::POSITION, $preferences[:first_light_position])
		GL.Light(GL::LIGHT1, GL::DIFFUSE, $preferences[:second_light_color])
		GL.Light(GL::LIGHT1, GL::POSITION, $preferences[:second_light_position])
		GL.Enable(GL::LIGHTING)
		GL.Enable(GL::LIGHT0)
		GL.Enable(GL::LIGHT1)
		GL.Enable(GL::DEPTH_TEST)
		# set stipple pattern for focus transparency
		GL.PolygonStipple [0xAA, 0xAA, 0xAA, 0xAA, 0x55, 0x55, 0x55, 0x55] * 16
		GL.Enable(GL::POLYGON_OFFSET_FILL)
    GL.PolygonOffset(1.0, 1.0)
    render_style :regular
		gldrawable.gl_end
	end
	
	def render_style style
		case style
		when :selection_pass
	  	GL.ShadeModel(GL::FLAT)
			GL.Disable(GL::TEXTURE_2D)
			GL.Disable(GL::DITHER)
			GL.Disable(GL::LINE_SMOOTH)
	  	GL.Disable(GL::BLEND)
		when :regular
			# setup model rendering
			GL.ShadeModel(GL::SMOOTH)
			GL.Enable(GL::TEXTURE_2D)
			GL.Enable(GL::DITHER)
			# setup line antialiasing
			if $preferences[:anti_aliasing]
				GL.Enable(GL::LINE_SMOOTH)
	  		GL.Enable(GL::BLEND)
				GL.BlendFunc(GL::SRC_ALPHA, GL::ONE_MINUS_SRC_ALPHA)
				GL.Hint(GL::LINE_SMOOTH_HINT, GL::NICEST)
			else
				GL.Disable(GL::LINE_SMOOTH)
	  		GL.Disable(GL::BLEND)
			end
		end
	end
	
	def configure
		glcontext = self.gl_context
		gldrawable = self.gl_drawable
		if gldrawable.gl_begin(glcontext)
			GL.Viewport(0, 0, allocation.width, allocation.height)
			GL.MatrixMode(GL::PROJECTION)
			GL.LoadIdentity
			aspect_ratio = allocation.width.to_f / allocation.height.to_f
			GLU.Perspective(40.0, aspect_ratio, 0.05, 25.0)
			GL.MatrixMode(GL::MODELVIEW)
			gldrawable.gl_end
			true
		else
			false
		end
	end
	
	def redraw
		glcontext = self.gl_context
		gldrawable = self.gl_drawable
		gldrawable.gl_begin( glcontext )
			GL.Clear(GL::COLOR_BUFFER_BIT | GL::DEPTH_BUFFER_BIT)
			GL.LoadIdentity
			# setup camera position und rotation
			cam = @cameras[@current_cam_index]
			GLU.LookAt(cam.position.x, cam.position.y, cam.position.z,
				 		     cam.target.x,   cam.target.y,   cam.target.z,
						     cam.up_vec.x,   cam.up_vec.y,   cam.up_vec.z)
			# draw assembly components and sketches
			GL.Disable(GL::LIGHTING)
			draw_coordinate_axes
			GL.LineStipple(5, 0x1C47)
			recurse_draw( @manager.main_assembly )
			# draw 3d interface stuff
			GL.Disable(GL::LIGHTING)
			@immediate_draw_routines.each{|r| r.call }
			gldrawable.swap_buffers unless @selection_pass or @picking_pass or @restore_backbuffer
		gldrawable.gl_end
	end
	
	def recurse_draw( top_comp )
	  if top_comp.visible
  		GL.PushMatrix
  		#XXX rotate 
  		### ------------------------ Assembly ------------------------ ###
  		if top_comp.class == Assembly
  			GL.Translate( top_comp.position.x, top_comp.position.y, top_comp.position.z )
  			top_comp.components.each{|c| recurse_draw(c) }
  		### -------------------------- Part -------------------------- ###
  		elsif top_comp.class == Part
  			GL.Translate( top_comp.position.x, top_comp.position.y, top_comp.position.z )
  			if @selection_pass
  			  GL.Disable GL::LIGHTING
  				unless @manager.work_sketch
  				  c = top_comp.selection_pass_color
    				GL.Color3f( c[0],c[1],c[2] ) if c
  				  top_comp.build_displaylist @selection_pass
  				  GL.CallList top_comp.displaylist 
  				  top_comp.build_displaylist # XXX kann man evtl weglassen
				  end
  			else
  				GL.Enable GL::LIGHTING
  				if top_comp.transparent and $preferences[:stencil_transparency]
  				  GL.Enable GL::POLYGON_STIPPLE
  				  GL.Enable GL::LINE_STIPPLE
  				  GL.LineStipple(5, 0x1C47)
    		  end
  				top_comp.selected ? GL.Color3f(1,0,0) : GL.Color3f(1,1,1)
  			  unless @picking_pass and @manager.work_sketch
  			    GL.CallList top_comp.displaylist 
  			    GL.CallList top_comp.wire_displaylist
			    end
  			  GL.Disable GL::POLYGON_STIPPLE
  			  GL.Disable GL::LINE_STIPPLE
  			end
  			top_comp.working_planes.each{|wp| recurse_draw( wp ) }
  			top_comp.unused_sketches.each{|sketch| recurse_draw( sketch ) }
  			if @manager.work_operator
  				op_sketch = @manager.work_operator.settings[:sketch] 
  				recurse_draw op_sketch if op_sketch
  			end
  			recurse_draw @manager.work_sketch if @manager.work_sketch
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
  			GL.CallList( (@picking_pass or @selection_pass == :select_faces) ? top_comp.pick_displaylist : top_comp.displaylist )
  		end
  		GL.PopMatrix
	  end
	end
	
	def restore_backbuffer
	  @restore_backbuffer = true
	  redraw
	  @restore_backbuffer = false
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
		col.zip @background_color do |colcomp, backcomp|
		  diff += (colcomp - backcomp).abs
	  end
	  if diff > 0.01
	    # read z-buffer value at pixel
  		z = GL.ReadPixels( x,y, 1,1, GL::DEPTH_COMPONENT, GL::FLOAT ).unpack("f")[0]
  		# convert to world space
  		pos = GLU.UnProject( x, y, z, modelview, projection, viewport )
  		pos = Vector[ pos[0], pos[1], pos[2] ]
  		# resolution of the depth buffer is low, so we correct the point position
  		pos = @manager.work_sketch.plane.closest_point pos if @manager.work_sketch
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
	
	def select( x, y, type=true )
		# corect coords from gtk to GL orientation
		y = allocation.height - y
		if @manager.work_sketch
		  selectables = @manager.work_sketch.segments 
	  else
	    case type
	    when :select_faces
	      selectables = @manager.all_part_instances.select{|inst| inst.visible }.map{|inst| inst.solid.faces }.flatten
	      selectables += @manager.work_component.working_planes
      when :select_instances
        selectables = @manager.all_part_instances.select{|inst| inst.visible }
      when :select_segments
        selectables = @manager.work_component.unused_sketches.map{|sk| sk.segments }.flatten if @manager.work_component.class == Part
	    end
    end
    # create colors to represent selectable objects
		current_color = [0, 0, 0]
		increment = 1.0 / 255
		i = 0
		selectables.each do |s|
			s.selection_pass_color = current_color.dup
			current_color[i] += increment
			raise "maximum number of colors reached" if current_color[i] >= 1
			i == 2 ? i = 0 : i += 1 
		end
		# change rendering style to aliased, flat-color rendering
		render_style :selection_pass
		# render scene to the back buffer
		@selection_pass = type
		redraw
		@selection_pass = false
		# look up color under cursor
		color_bytes = GL.ReadPixels( x,y, 1,1, GL::RGB, GL::UNSIGNED_BYTE )
		color = [ color_bytes[0] / 255.0, color_bytes[1] / 255.0, color_bytes[2] / 255.0 ]
		# select corresponding object
		obj = nil
		best_diff = 9999
		selectables.each do |inst| 
			obj_color = inst.selection_pass_color
			diff = 0
			3.times{|i| diff += (obj_color[i] - color[i]).abs }
			if diff < best_diff 
				best_diff = diff
				obj = inst
			end
		end
		obj = nil unless best_diff < increment
		@manager.work_component.unused_sketches.each{|sk| sk.build_displaylist } if @manager.work_component.class == Part
		# reset regular rendering style
		render_style :regular
		restore_backbuffer
		return obj
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
	
	def zoom_selection
		unless @manager.selection.empty?
			corners = @manager.selection.map{|e| e.bounding_box }.flatten
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
	  @manager.previous_btn.sensitive = (@current_cam_index > 0)
	  @manager.next_btn.sensitive = (@current_cam_index < (@cameras.size - 1))
	end
	
	def draw_coordinate_axes
		GL.LineWidth(2)
		GL.Begin( GL::LINES )
			GL.Color3f(0.3,0,0)
			GL.Vertex(0,0,0)
			GL.Vertex(0.1,0,0)
			GL.Color3f(0,0.3,0)
			GL.Vertex(0,0,0)
			GL.Vertex(0,0.1,0)
			GL.Color3f(0,0,0.3)
			GL.Vertex(0,0,0)
			GL.Vertex(0,0,0.1)
		GL.End
	end
	
	def screenshot( x=0, y=0, width=allocation.width, height=allocation.height, step=6 )
		redraw
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
		return im
	end
end












