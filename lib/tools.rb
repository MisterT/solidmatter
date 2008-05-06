#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 13-10-06.
#  Copyright (c) 2008. All rights reserved.

require 'lib/pop_ups.rb'


class Tool
	def initialize( status_text, glview, manager )
		@status_text = status_text
		@glview = glview
		@manager = manager
		resume
	end
public
	def click_left( x,y )
	  @manager.has_been_changed = true
	end
	
	def double_click( x,y )
	 
	end
	
	def click_middle( x,y )

	end
	
	def click_right( x,y, time )

	end
	
	def drag_left( x,y )

	end
	
	def drag_middle( x,y )

	end
	
	def drag_right( x,y )

	end
	
	def mouse_move( x,y )

	end
	
	def press_left( x,y )
	 
	end
	
	def release_left
	 
	end
	
	def button_release
	 
	end
	
	def pause
		@glview.immediate_draw_routines.pop
	end
	
	def resume
		@glview.immediate_draw_routines.push lambda{ draw }
		@manager.set_status_text( @status_text )
	end
	
	def exit
		@glview.immediate_draw_routines.pop
	end
private
	def draw
	  
	end
end

###                                                                  ###
######---------------------- Selection tools ----------------------######
###                                                                  ###

class SelectionTool < Tool
	def initialize( text, glview, manager )
		super( text, glview, manager )
		@selection = nil
		@callback = Proc.new if block_given?
	end
	
	def exit
		super
		@callback.call @selection if @callback
	end
end


class PartSelectionTool < SelectionTool
	def initialize( glview, manager )
		super( "Drag a part to move it around, right click for options:", glview, manager )
	end
	
	def click_left( x,y )
		super
		sel = @glview.select(x,y, :select_instances)
		if sel
			if @manager.key_pressed? :Shift
				@manager.selection.add @manager.top_ancestor( sel ) 
			else
				@manager.select sel
			end
		else
			@manager.selection.deselect_all
		end
	end
	
	def double_click( x,y )
	  super
 	  real_sel = @manager.selection.first
 	  if real_sel
 	    @manager.change_working_level real_sel 
    else
      @manager.working_level_up
    end
	end
	
	def click_right( x,y, time )
	  super
		click_left( x,y )
		sel = @manager.selection.first
		menu = sel ? ComponentMenu.new(@manager, sel, :glview) : BackgroundMenu.new(@manager)
		menu.popup(nil, nil, 3,  time)
	end
end

class OperatorSelectionTool < SelectionTool
	def initialize( glview, manager )
		super( "Select a feature from yout model, right click for options:", glview, manager )
	end
	
	def click_right( x,y, time )
	  super
		click_left( x,y )
		BackgroundMenu.new(@manager).popup(nil, nil, 3,  time)
	end
end

=begin
class SketchSelectionTool < SelectionTool
	def initialize( glview, manager )
		super( "Pick a closed sketch:", glview, manager )
	end
	
	def click_left( x,y )
		super
		sel = @glview.select(x,y, :select_segments)
		if sel
		  @selection = sel.sketch   
		  @manager.selection.select *@selection.segments
		  @glview.redraw
		  @manager.cancel_current_tool
	  end
	end
end
=end
Region = Struct.new(:chain, :poly, :face)
class RegionSelectionTool < SelectionTool
	def initialize( glview, manager )
		super( "Pick a closed region from a sketch:", glview, manager )
		@op_sketch = manager.work_operator.settings[:sketch]
		@plane = @op_sketch ? @op_sketch.plane : manager.work_component.unused_sketches.first.plane
		@plane.build_displaylists
		@regions = (manager.work_component.unused_sketches + [@op_sketch]).compact.inject([]) do |regions, sketch|
		  regions += sketch.all_chains.map do |chain|
  	    poly = Polygon.from_chain( chain )
  	    face = PlanarFace.new
  	    face.segments = chain.map{|seg| Line.new(seg.pos1 + @plane.origin, seg.pos2 + @plane.origin, seg.sketch)  }
  	    Region.new(chain, poly, face)
	    end
    end
    @regions.compact!
    @op_sketch.visible = true if @op_sketch
	end
	
	def click_left( x,y )
		super
    pos = pos_of( x,y )
	  region = @regions.select{|r| r.poly.contains? Point.new( pos.x, pos.z ) }.first if pos
	  if pos and region 
		  @selection = region.chain
		  @manager.cancel_current_tool
	  end
	end
	
	def mouse_move( x,y )
    pos = pos_of( x,y )
    @current_region = @regions.select{|r| r.poly.contains? Point.new( pos.x, pos.z ) }.first if pos
    @glview.redraw
	end
	
	def draw
	  GL.Color3f( 0.9, 0.2, 0 )
    @current_region.face.draw if @current_region
	end
	
	def pos_of( x,y )
	 	@plane.visible = true
		pos = @glview.screen2world( x,y )
		pos -= @plane.origin if pos
		@plane.visible = false
		return pos
	end
	
	def exit
		@op_sketch.visible = false if @op_sketch
		super
	end
end


class PlaneSelectionTool < SelectionTool
	def initialize( glview, manager )
		super( "Select a single plane:", glview, manager )
		@manager.work_component.working_planes.each{|plane| plane.visible = true }
		puts manager.work_component.working_planes
	end
	
	def click_left( x,y )
	  super
	  sel = @glview.select(x,y, :select_faces)
		if sel
		  if sel.is_a? PlanarFace
        @selection = sel.plane
      elsif sel.is_a? WorkingPlane
        @selection = sel
      end
      @manager.cancel_current_tool
	  end
	end
	
	def exit
	  @manager.work_component.working_planes.each{|plane| plane.visible = false }
	  super
	end
end

###                                                                  ###
######---------------------- Standard tools ----------------------######
###                                                                  ###

class CameraTool < Tool
	def initialize( glview, manager )
		super( "Drag left to pan, drag right to rotate the camera, middle drag for zoom:", glview, manager )
	end
	
	def click_left( x,y )
		# is already handled by GLView
	end
	
	def draw
		# is already handled by GLView
	end
end


class MeasureDistanceTool < Tool
	def initialize( glview, manager )
		super( "Pick a series of points to display the lenght of the path along them:", glview, manager )
		@points = []
	end
	
	def click_left( x,y )
	  super
		pick_point x, y
	end
	
private
	def pick_point( x, y )
		@points.push( @glview.screen2world( x, y ) )
		display_distance
	end
	
	def display_distance
		dist = 0
		previous = nil
		@points.each do |p|
			dist += p.distance_to previous if previous
			previous = p
		end
		# lenght should be displayed even when tool was paused
		@status_text = "Distance: #{dist}"
		@manager.set_status_text @status_text
	end
	
	def draw
		glcontext = @manager.glview.gl_context
		gldrawable =  @manager.glview.gl_drawable
		if gldrawable.gl_begin( glcontext )
			GL.LineWidth(3)
			GL.Color3f(1,0,1)
			previous = nil
			@points.each do |p|
				if previous
					GL.Begin( GL::LINES )
						GL.Vertex( previous.x, previous.y, previous.z )
						GL.Vertex( p.x, p.y, p.z )
					GL.End
				end
				previous = p
			end
			@points.each do |p|
				GL.Begin( GL::POINTS ) #XXX must be drawn taller
					GL.Vertex( p.x, p.y, p.z )
				GL.End
			end
		gldrawable.gl_end
		end
	end
end

###                                                                     ###
######---------------------- Sketch mode tools ----------------------######
###                                                                     ###

class SketchTool < Tool
  attr_accessor :create_reference_geometry
	def initialize( text, glview, manager, sketch )
		super( text, glview, manager )
		@sketch = sketch
		@snap_tolerance = 6
		@last_reference_points = []
		@create_reference_geometry = false
		@does_snap = true
	end
	
	# snap points to guides, then to other points, then to grid
	def snapped( x,y, excluded=[] )
    guide = [@x_guide,@z_guide].compact.first
    point = if guide and @manager.use_sketch_guides
              guide.last
            else
              point = @glview.screen2world( x, y ) 
              point ? world2sketch(point) : nil
            end
    if point
      was_point_snapped = false
      point, was_point_snapped = point_snapped( point, excluded ) if @manager.point_snap
      point = grid_snapped point unless was_point_snapped or guide or not @manager.grid_snap
      return point, was_point_snapped
    else
      return nil
    end
	end
	
	# snap to surrounding points
	def point_snapped( point, excluded=[] )
		closest = nil
		unless @sketch.segments.empty?
			closest_dist = 999999
			@sketch.segments.each do |seg|
				[seg.pos1, seg.pos2].each do |pos|
				  unless excluded.include? pos
  					dist = @glview.world2screen(sketch2world(point)).distance_to @glview.world2screen(sketch2world(pos))
  					if dist < @snap_tolerance
  						if dist < closest_dist
  							closest = pos
  							closest_dist = dist
  						end
  					end
					end
				end
			end
		end
		if closest
			return closest, true
		else
			return point, false
		end
	end
	
	def grid_snapped p
	  if @manager.grid_snap
	    spacing = @sketch.plane.spacing
	    div, mod = p.x.divmod spacing
	    new_x = div * spacing
	    new_x += spacing if mod > spacing / 2
	    div, mod = p.y.divmod spacing
	    new_y = div * spacing
	    new_y += spacing if mod > spacing / 2
	    div, mod = p.z.divmod spacing
	    new_z = div * spacing
	    new_z += spacing if mod > spacing / 2
	    new_point = Vector[new_x, new_y, new_z]
	    return new_point
    else
      return p
    end
	end
		
	def mouse_move( x,y, excluded=[] )
	  super( x,y )
	  if @does_snap
  	  point = @glview.screen2world( x, y )
  	  if point and @manager.use_sketch_guides
  	    point = world2sketch( point )
    	  # determine point(s) to draw guide through
    	  x_candidate = nil
    	  z_candidate = nil
        (@last_reference_points - excluded).each do |p|
          # construct a point with our height, but exactly above or below reference point (z axis)
          snap_point = Vector[p.x, point.y, point.z]
          # measure out distance to that in screen coords
          screen_dist = @glview.world2screen(sketch2world(snap_point)).distance_to @glview.world2screen(sketch2world(point))
          if screen_dist < @snap_tolerance
            x_candidate ||= [p, screen_dist]
    	      x_candidate = [p, screen_dist] if screen_dist < x_candidate.last
          end
          # now for y direction (x axis)
          snap_point = Vector[point.x, point.y, p.z]
          screen_dist = @glview.world2screen(sketch2world(snap_point)).distance_to @glview.world2screen(sketch2world(point))
          if screen_dist < 6
            z_candidate ||= [p, screen_dist]
    	      z_candidate = [p, screen_dist] if screen_dist < z_candidate.last
          end
        end
        # snap cursor point to guide(s)
        # point on axis schould be calculated from workplane instead of world coordinates
        cursor_point = if x_candidate and z_candidate
          		           Vector[x_candidate.first.x, point.y, z_candidate.first.z]
          		         elsif x_candidate
          		           Vector[x_candidate.first.x, point.y, point.z] 
          		         elsif z_candidate
          		           Vector[point.x, point.y, z_candidate.first.z]
          	           else
          	             point
          	           end
        @x_guide = z_candidate ? [z_candidate.first, cursor_point] : nil 
        @z_guide = x_candidate ? [x_candidate.first, cursor_point] : nil
        # if we are near a snap point, use it as reference in the next run
        point, was_snapped = point_snapped( point, excluded )
        @last_reference_points.push point if was_snapped
        @last_reference_points.uniq!
    	  @last_reference_points.shift if @last_reference_points.size > $preferences[:max_reference_points]
      end
    end
	end
	
	# draw guides as stippeled lines
	def draw
    super
    if @manager.use_sketch_guides and @does_snap
      #GL.Disable(GL::DEPTH_TEST)
		  [@x_guide, @z_guide].compact.each do |guide|
		    first = sketch2world(guide.first)
		    last = sketch2world( guide.last )
		    GL.Enable GL::LINE_STIPPLE
		    GL.LineWidth(2)
		    GL.Enable GL::LINE_STIPPLE
				GL.LineStipple(5, 0x1C47)
				GL.Color3f(0.5,0.5,1)
				GL.Begin( GL::LINES )
					GL.Vertex( first.x, first.y, first.z )
					GL.Vertex( last.x, last.y, last.z )
				GL.End
				GL.Disable GL::LINE_STIPPLE
				#GL.Enable(GL::DEPTH_TEST)
			end
		end
	end
	
	def world2sketch( v )
	  o = @sketch.plane.origin
	  v - o
	end
	
	def sketch2world( v )
	  o = @sketch.plane.origin
	  v + o
	end
end


class LineTool < SketchTool
	def initialize( glview, manager, sketch )
		super( "Click left to create a point, middle click to move points:", glview, manager, sketch )
	end
	
	# add temporary line to sketch and add a new one
	def click_left( x,y )
	  super
		if @temp_line
			@sketch.segments.push @temp_line unless @temp_line.pos1 == @temp_line.pos2
			@sketch.build_displaylist
		end
    @last_point, dummy = snapped( x,y )
    @last_reference_points.push @last_point
	end
	
	# update temp line
	def mouse_move( x,y )
	  super
		if @last_point
			new_point, was_snapped = snapped( x,y )
		 	@temp_line = Line.new( @last_point, new_point, @sketch) if new_point
		 	@draw_dot = was_snapped
		end
		@glview.redraw
	end
	
	def click_right( x,y, time )
	  super
	  menu = SketchToolMenu.new( @manager, self )
	  menu.popup(nil, nil, 3,  time)
	end
	
	def draw
	  super
		if @temp_line
		  # draw line segment
			GL.LineWidth(2)
			GL.Color3f(1,1,1)
			GL.Begin( GL::LINES )
			  pos1 = sketch2world( @temp_line.pos1 )
			  pos2 = sketch2world( @temp_line.pos2 )
				GL.Vertex( pos1.x, pos1.y, pos1.z )
				GL.Vertex( pos2.x, pos2.y, pos2.z )
			GL.End
			if @draw_dot
  			# draw dot at snap location
  			GL.Disable(GL::DEPTH_TEST)
    		GL.Color3f(1,0.3,0.1)
    		GL.PointSize(8.0)
    		GL.Begin( GL::POINTS )
    			GL.Vertex( pos2.x, pos2.y, pos2.z )
    		GL.End
    		GL.Enable(GL::DEPTH_TEST)
  		end
		end
	end
end


class EditSketchTool < SketchTool
	def initialize( glview, manager, sketch )
		super( "Click left to select points, drag to move points, right click for options:", glview, manager, sketch )
		@draw_points = []
		@does_snap = false
		@points_to_drag = []
	end
	
	def click_left( x,y )
	  super
	  sel = @glview.select( x,y )
	 	if sel
	 	  if @manager.key_pressed? :Shift
	 	    @manager.selection.add sel
	 	    @selection.push sel
 	    else
	 	    @manager.selection.select sel
		    @selection = [sel]
	    end
	  else
	    @manager.selection.deselect_all
	    @selection = nil
		end
	end
	
  def press_left( x,y )
    super
    @does_snap = true
    pos = @glview.screen2world( x,y )
    new_selection = @glview.select( x,y )
    # if drag starts on an already selected segment
    if pos
      pos = world2sketch(pos)
    	@drag_start = pos
    	@old_draw_points = Marshal.load(Marshal.dump( @draw_points ))
		  if @selection and @selection.include? new_selection	    
		    @points_to_drag = @selection.map{|e| e.own_and_neighbooring_points }.flatten.uniq
		    @old_points = Marshal.load(Marshal.dump( @points_to_drag ))
		  elsif new_selection
		    click_left( x,y )
		    press_left( x,y )
		  else
		    click_left( x,y )
		  end
		end
  end
	
	def drag_left( x,y )
	  super
	  mouse_move( x,y, true, @draw_points )
	  pos, dummy = snapped( x,y, @draw_points )
	  if pos and @drag_start
	  	move = @drag_start.vector_to pos
	  	if @selection
			  @points_to_drag.zip( @old_points ).each do |neu, original|
			    neu.x = original.x + move.x
			    neu.y = original.y + move.y
			    neu.z = original.z + move.z
		    end
		  else
			  @draw_points.zip( @old_draw_points ).each do |neu, original|
			    neu.x = original.x + move.x
			    neu.y = original.y + move.y
			    neu.z = original.z + move.z
		    end
		  end
		  @sketch.build_displaylist
	    @glview.redraw
    end
	end
	
	def release_left
	  super
	  @does_snap = false
  end
  
  def mouse_move( x,y, only_super=false, excluded=[] )
  	super( x,y, excluded )
  	unless only_super
  		points = @sketch.segments.map{|s| [s.pos1, s.pos2] }.flatten
  		@draw_points = points.select do |point|
  			dist = Point.new(x, @glview.allocation.height - y).distance_to @glview.world2screen(sketch2world(point))
  			dist < @snap_tolerance
  		end
  		@glview.redraw
		end
  end
	
	def click_middle( x,y )
	  super
	  sel = @glview.select( x,y )
		if sel
			@selection = sel.sketch.chain( sel )
			if @selection
				@manager.selection.select *@selection
				sel.sketch.build_displaylist
				@glview.redraw
			end
		else
		  @manager.selection.deselect_all
		end
  end
  
  def click_right( x,y, time )
	  super
	  click_left( x,y )
	  menu = SketchSelectionToolMenu.new @manager
	  menu.popup(nil, nil, 3,  time)
	end
	
	def draw
		super
		unless @draw_points.empty?
			point = sketch2world(@draw_points.first)
			GL.Disable(GL::DEPTH_TEST)
			GL.Color3f(1,0.3,0.1)
			GL.PointSize(8.0)
			GL.Begin( GL::POINTS )
				GL.Vertex( point.x, point.y, point.z )
			GL.End
			GL.Enable(GL::DEPTH_TEST)
		end
	end
end



