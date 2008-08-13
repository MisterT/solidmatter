#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 13-10-06.
#  Copyright (c) 2008. All rights reserved.

require 'pop_ups.rb'


class Tool
  attr_reader :toolbar, :uses_toolbar
	def initialize status_text
		@status_text = status_text
		@glview = $manager.glview
		create_toolbar
		@uses_toolbar = false
		resume
	end
public
  def self.world2sketch( v, plane )
	  o = plane.origin
	  v - o
	end
	
	def self.sketch2world( v, plane )
	  o = plane.origin
	  v + o
	end

	def click_left( x,y )
	  $manager.has_been_changed = true
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
	
	def press_right( x,y, time )
	end
	
	def release_left
	end
	
	def release_right
	end
	
	def button_release
	end
	
	def pause
		@glview.immediate_draw_routines.pop
	end
	
	def resume
	  @draw_routine = lambda{ draw }
		@glview.immediate_draw_routines.push @draw_routine
		$manager.set_status_text( @status_text )
	end
	
	def exit
		@glview.immediate_draw_routines.delete @draw_routine
		$manager.glview.window.cursor = nil
	end
	
  #--- UI ---#
	def create_toolbar
		@toolbar = Gtk::Toolbar.new
		@toolbar.toolbar_style = Gtk::Toolbar::BOTH
		@toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		fill_toolbar 
		@toolbar.append( Gtk::SeparatorToolItem.new){}
		@toolbar.append( Gtk::Stock::OK, GetText._("Finish using tool"),"Tool/Ok"){ $manager.cancel_current_tool }
	end
	
	def fill_toolbar
	  # should be overridden by subclasses
	end
private
	def draw
	end
end

###                                                                  ###
######---------------------- Selection tools ----------------------######
###                                                                  ###

class SelectionTool < Tool
	def initialize text
		super text
		@selection = nil
		@callback = Proc.new if block_given?
		@glview.rebuild_selection_pass_colors selection_mode
	end
	
	def selection_mode
	  raise "Must be overridden"
	end
	
	def exit
		super
		@callback.call @selection if @callback
	end
end


class PartSelectionTool < SelectionTool
	def initialize
		super( GetText._("Drag a part to move it around, right click for options:") )
	end
	
	def selection_mode
	  :select_instances
	end
	
	def click_left( x,y )
		super
		sel = @glview.select(x,y, :select_instances)
		if sel
			if $manager.key_pressed? :Shift
				$manager.selection.add $manager.top_ancestor( sel ) 
			else
				$manager.select sel
			end
		else
			$manager.selection.deselect_all
		end
	end
	
	def double_click( x,y )
	  super
 	  real_sel = $manager.selection.first
 	  if real_sel
 	    $manager.change_working_level real_sel 
    else
      $manager.working_level_up
    end
	end
	
	def mouse_move( x,y )
	  super
	  @current_part = @glview.select(x,y, :select_instances)
    @glview.redraw
	end
	
	def press_right( x,y, time )
	  super
		click_left( x,y )
		sel = $manager.selection.first
		menu = sel ? ComponentMenu.new( sel, :glview) : BackgroundMenu.new
		menu.popup(nil, nil, 3,  time)
	end
	
	def draw
	  super
	  GL.Color4f( 0.9, 0.2, 0, 0.5 )
	  GL.Disable(GL::POLYGON_OFFSET_FILL)
    #@current_part.solid.faces.each{|f| f.draw } if @current_part
    GL.CallList @current_part.displaylist if @current_part
    GL.Enable(GL::POLYGON_OFFSET_FILL)
	end
end

class OperatorSelectionTool < SelectionTool
	def initialize
		super( GetText._("Select a feature from your model, right click for options:") )
		@draw_faces = []
=begin
		part = $manager.work_component
		@op_displaylists = {}
		part.operators.map do |op| 
	  	faces = part.solid.faces.select{|f| f.created_by_op == op }
	  	list = @glview.add_displaylist
	  	GL.NewList( list, GL::COMPILE)
	  		faces.each{|f| f.draw }
	  	GL.EndList
	  	@op_displaylists[op] = list
	  end
=end
	end
	
	def selection_mode
	  :select_faces
	end
	
	def click_left( x,y )
		super
		mouse_move( x,y )
		if @current_face
		#if @current_op
		  op = @current_face.created_by_op
		  $manager.exit_current_mode
      $manager.operator_mode op
      #$manager.operator_mode @current_op
    end
	end
	
	def mouse_move( x,y )
	  super
	  @current_face = @glview.select(x,y, :select_faces)
	  raise "Wörkking plane" if @current_face.is_a? WorkingPlane
	  @current_face = nil unless $manager.work_component.operators.include? @current_face.created_by_op if @current_face
	  @draw_faces = @current_face ? @current_face.solid.faces.select{|f| f.created_by_op == @current_face.created_by_op } : []
	  #face = @glview.select(x,y, :select_faces)
	  #@current_op = (face and @op_displaylists[face.created_by_op]) ? face.created_by_op : nil
    @glview.redraw
	end
	
	def click_right( x,y, time )
	  super
	  mouse_move( x,y )
	  if @current_face
		  OperatorMenu.new( @current_face.created_by_op).popup(nil, nil, 3,  time)
		else
		  BackgroundMenu.new.popup(nil, nil, 3,  time)
	  end
	end
	
	def draw
	  super
	  GL.Color4f( 0.9, 0.2, 0.0, 0.5 )
	  GL.Disable(GL::POLYGON_OFFSET_FILL)
    @draw_faces.each{|f| f.draw }
    #GL.CallList @op_displaylists[@current_op] if @current_op
    GL.Enable(GL::POLYGON_OFFSET_FILL)
	end
	
	def exit
		super
		#@op_displaylists.values.each{|l| @glview.delete_displaylist l }
	end
end


Region = Struct.new(:chain, :poly, :face)
class RegionSelectionTool < SelectionTool
	def initialize
		super( GetText._("Pick a closed region from a sketch:") )
		# create a list of regions that can be picked
		@op_sketch = $manager.work_operator.settings[:sketch]
		@all_sketches = ($manager.work_component.unused_sketches + [@op_sketch]).compact
		@regions = @all_sketches.inject([]) do |regions, sketch|
		  regions + sketch.all_chains.reverse.map do |chain|
  	    poly = Polygon.from_chain chain #.map{|seg| seg.tesselate }.flatten
  	    face = PlanarFace.new
  	    face.plane = sketch.plane
  	    face.plane.build_displaylists #XXX kann man evtl weglassen
  	    face.segments = chain.map{|seg| seg.tesselate }.flatten.map{|seg| Line.new(Tool.sketch2world(seg.pos1, sketch.plane), Tool.sketch2world(seg.pos2, sketch.plane), sketch)  }
  	    Region.new(chain, poly, face)
	    end
    end
    @regions.compact!
    @op_sketch.visible = true if @op_sketch
    @glview.redraw
	end
	
	def selection_mode
	  :select_planes
	end
	
	def click_left( x,y )
		super
		mouse_move( x,y )
	  if @current_region
	  	@selection ||= []
		  @selection.push @current_region.chain
		  @selection = @selection.first # XXX should really combine the regions into one
		  $manager.cancel_current_tool unless $manager.key_pressed? :Shift
	  end
	end

	def mouse_move( x,y )
	  super
	  for sketch in @all_sketches
	    sketch.plane.visible = true
	    sel = @glview.select(x,y, :select_planes)
	    sketch.plane.visible = false
	    if sel
        pos = pos_of( x,y, sel )
        @current_region = @regions.select{|r| r.face.plane == sel and r.poly.contains? Point.new( pos.x, pos.z ) }.first
        @glview.redraw
        break if @current_region
      end
    end
    $manager.glview.window.cursor = @current_region ? Gdk::Cursor.new(Gdk::Cursor::HAND2) : nil
	end
	
	def draw
	  super
	  GL.Color3f( 0.9, 0.2, 0 )
	  GL.Disable(GL::POLYGON_OFFSET_FILL)
    @current_region.face.draw if @current_region
    GL.Enable(GL::POLYGON_OFFSET_FILL)
	end
	
	def pos_of( x,y, plane )
	  planestate = plane.visible
	 	plane.visible = true
		pos = @glview.screen2world( x,y )
		pos = Tool.world2sketch( pos, plane ) if pos
		plane.visible = planestate
		return pos
	end
	
	def exit
	#	@all_sketches.each { |s| s.plane.visible = false }
	  @op_sketch.visible = false if @op_sketch
		super
	end
end


class PlaneSelectionTool < SelectionTool
	def initialize
		super( GetText._("Select a single plane:") )
		$manager.work_component.working_planes.each{|plane| plane.visible = true }
	end
	
	def selection_mode
	  :select_faces_and_planes
	end
	
	def click_left( x,y )
	  super
	  sel = @glview.select(x,y, :select_faces_and_planes)
		if sel
		  if sel.is_a? PlanarFace
        @selection = sel.plane
      elsif sel.is_a? WorkingPlane
        @selection = sel
      end
      $manager.cancel_current_tool
	  end
	end
	
	def exit
	  $manager.work_component.working_planes.each{|plane| plane.visible = false }
	  super
	end
end

###                                                                  ###
######---------------------- Standard tools ----------------------######
###                                                                  ###

class CameraTool < Tool
	def initialize
		super( GetText._("Drag left to pan, drag right to rotate the camera, middle drag for zoom:") )
		$manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
	end
	
	def click_left( x,y )
		# is already handled by GLView
	end
	
	def press_left( x,y )
	  super
	  $manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
	end
	
	def click_middle( x,y )
	  super
	  $manager.glview.window.cursor =Gdk::Cursor.new Gdk::Cursor::SB_V_DOUBLE_ARROW
	end
	
	def press_right( x,y, time )
	  super
	  $manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::EXCHANGE
	end
	
	def button_release
	  super
	  $manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
	end
	
	def draw
		# is already handled by GLView
	end
end


class MeasureDistanceTool < Tool
	def initialize
		super( GetText._("Pick a series of points to display the lenght of the path along them:") )
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
		@status_text = GetText._("Distance:") + " #{dist}"
		$manager.set_status_text @status_text
	end
	
	def draw
		glcontext = $manager.glview.gl_context
		gldrawable =  $manager.glview.gl_drawable
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
	def initialize( text, sketch )
		super text
		@sketch = sketch		
		@last_reference_points = []
		@create_reference_geometry = false
		@does_snap = true
		@temp_segments = []
	end
	
	def resume
	  super
	  @glview.rebuild_selection_pass_colors :select_segments_and_dimensions
	end
	
	# snap points to guides, then to other points, then to grid
	def snapped( x,y, excluded=[] )
    guide = [@x_guide,@z_guide].compact.first
    point = if guide and $manager.use_sketch_guides
              guide.last
            else
              point = @glview.screen2world( x, y ) 
              point ? world2sketch(point) : nil
            end
    if point
      was_point_snapped = false
      point, was_point_snapped = point_snapped( point, excluded ) if $manager.point_snap
      point = grid_snapped point unless was_point_snapped or guide or not $manager.grid_snap
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
				seg.snap_points.each do |pos|
				  unless excluded.include? pos
  					dist = @glview.world2screen(sketch2world(point)).distance_to @glview.world2screen(sketch2world(pos))
  					if dist < $preferences[:snap_dist]
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
	  if $manager.grid_snap
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
  	  if point and $manager.use_sketch_guides
  	    point = world2sketch( point )
    	  # determine point(s) to draw guide through
    	  x_candidate = nil
    	  z_candidate = nil
        (@last_reference_points - excluded).each do |p|
          # construct a point with our height, but exactly above or below reference point (z axis)
          snap_point = Vector[p.x, point.y, point.z]
          # measure out distance to that in screen coords
          screen_dist = @glview.world2screen(sketch2world(snap_point)).distance_to @glview.world2screen(sketch2world(point))
          if screen_dist < $preferences[:snap_dist]
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
	
	def click_left( x,y )
		super
		@sketch.plane.resize2fit @sketch.segments.map{|s| s.snap_points }.flatten
	end
	
	def click_right( x,y, time )
	  super
	  menu = SketchToolMenu.new self
	  menu.popup(nil, nil, 3,  time)
	end
	
	# draw guides as stippeled lines
	def draw
    super
    GL.Disable(GL::DEPTH_TEST)
    if $manager.use_sketch_guides
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
      end
    end
		if $manager.point_snap and @draw_dot
      # draw dot at snap location
      dot = sketch2world @draw_dot
      GL.Color3f(1,0.3,0.1)
      GL.PointSize(8.0)
      GL.Begin( GL::POINTS )
        GL.Vertex( dot.x, dot.y, dot.z )
      GL.End
		end
	  GL.Enable(GL::DEPTH_TEST)
	  # draw additional temporary geometry
	  #XXX segs should draw themselves
	  for seg in @temp_segments
		  for micro_seg in seg.tesselate
			  GL.LineWidth(2)
			  GL.Color3f(1,1,1)
			  GL.Begin( GL::LINES )
			    pos1 = sketch2world( micro_seg.pos1 )
			    pos2 = sketch2world( micro_seg.pos2 )
				  GL.Vertex( pos1.x, pos1.y, pos1.z )
				  GL.Vertex( pos2.x, pos2.y, pos2.z )
			  GL.End
		  end
		end
	end
	
	def world2sketch( v )
	  Tool.world2sketch( v, @sketch.plane)
	end
	
	def sketch2world( v )
    Tool.sketch2world( v, @sketch.plane)
	end
	
	def exit
	  super
	  @sketch.update_constraints
	  @sketch.build_displaylist
	end
end


class LineTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to create a point, middle click to move points:"), sketch )
		$manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if $manager.glview.window
		@first_line = true
	end
	
	# add temporary line to sketch and add a new one
	def click_left( x,y )
	  super
		if @temp_line
		  unless @temp_line.pos1 == @temp_line.pos2
			  snap_p, snapped = point_snapped( world2sketch( @glview.screen2world(x,y)))
			  @sketch.constraints << CoincidentConstraint.new( @temp_line.pos2, snap_p ) if snapped
			  @sketch.constraints << CoincidentConstraint.new( @temp_line.pos1, @sketch.segments.last.pos2 ) unless @first_line
			  @sketch.segments << @temp_line
			  @first_line = false
			  @sketch.build_displaylist
		  end
		end
    @last_point, dummy = snapped( x,y )
    @last_reference_points.push @last_point
	end
	
	# update temp line
	def mouse_move( x,y )
	  super
	  new_point, was_snapped = snapped( x,y )
	  @draw_dot = was_snapped ? new_point : nil
	  if new_point and @last_point
		  @temp_line = Line.new( @last_point, new_point, @sketch)
		  @temp_segments = [@temp_line]
	  end
		@glview.redraw
	end
	
	def pause
	  super
	  $manager.glview.window.cursor = nil
	end
	
	def resume
	  super
	  $manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if $manager.glview.window
	end
end


class ArcTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to select center:"), sketch )
		$manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if $manager.glview.window
		@step = 1
		@uses_toolbar = true
	end

	def click_left( x,y )
	  point, was_snapped = snapped( x,y )
	  if point
      case @step
      when 1
        @center = point
        $manager.set_status_text GetText._("Click left to select first point on arc:")
      when 2
        @radius = @center.distance_to point
		    @start_angle = 360 - (@sketch.plane.u_vec.angle @center.vector_to point)
		    @start_point = point
		    $manager.set_status_text GetText._("Click left to select second point on arc:")
	    when 3
	      #end_angle = 360 - @sketch.plane.u_vec.angle( @center.vector_to( point ) )
	      end_angle = @sketch.plane.u_vec.angle @center.vector_to point
        end_angle = 360 - end_angle 
        end_angle = 360 - end_angle if point.z > @center.z
	      @sketch.segments.push Arc.new( @center, @radius, @start_angle, end_angle, @sketch )
	      @sketch.build_displaylist
	      $manager.cancel_current_tool
      end
      @step += 1
    end
    super
	end

	def mouse_move( x,y )
	  super
		point, was_snapped = snapped( x,y )
		@draw_dot = was_snapped ? point : nil
		if point
  		case @step
		  when 2
        @temp_segments = [ Line.new( @center, point, @sketch ) ]
	    when 3
        end_angle =@sketch.plane.u_vec.angle @center.vector_to point
        end_angle = 360 - end_angle 
        end_angle = 360 - end_angle if point.z > @center.z
        arc = Arc.new( @center, @radius, @start_angle, end_angle )
        @temp_segments = [ Line.new( @center, arc.pos1 ), arc, Line.new( @center, arc.pos2 ) ]
		  end
	  end
		@glview.redraw
	end
end


class CircleTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to select center:"), sketch )
		$manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if $manager.glview.window
		@step = 1
	end
	
	def click_left( x,y )
	  point, was_snapped = snapped( x,y )
	  if point
      case @step
      when 1
        @center = point
        $manager.set_status_text GetText._("Click left to select a point on the circle:")
	    when 2
        radius = @center.distance_to point
	      @sketch.segments.push Circle.new( @center, radius, @sketch )
	      @sketch.build_displaylist
	      $manager.cancel_current_tool
      end
      @step += 1
    end
    super
	end

	def mouse_move( x,y )
	  super
		point, was_snapped = snapped( x,y )
		@draw_dot = was_snapped ? point : nil
		if point
  		if @step == 2
        radius = @center.distance_to point
        circle = Circle.new( @center, radius )
        @temp_segments = [ Line.new(@center, point), circle ]
		  end
	  end
		@glview.redraw
	end
end


class TwoPointCircleTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to select first point on circle:"), sketch )
		$manager.glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if $manager.glview.window
		@step = 1
	end
	
	def click_left( x,y )
	  point, was_snapped = snapped( x,y )
	  if point
      case @step
      when 1
        @p1 = point
        $manager.set_status_text GetText._("Click left to select second point on circle:")
	    when 2
	      @sketch.segments.push Circle::from_opposite_points( @p1, point, @sketch )
	      @sketch.build_displaylist
	      $manager.cancel_current_tool
      end
      @step += 1
    end
    super
	end

	def mouse_move( x,y )
	  super
		point, was_snapped = snapped( x,y )
		@draw_dot = was_snapped ? point : nil
		if point and @step == 2
      @temp_segments = [ Circle::from_opposite_points( @p1, point ) ]
	  end
		@glview.redraw
	end
end


class DimensionTool < SketchTool
	def initialize sketch
		super( GetText._("Choose a segment or two points to add a dimension:"), sketch )
		@points = []
		@selected_segments = []
		@does_snap = false
	end
	
	def click_left( x,y )
    if dim = dimension_for( @selected_segments, x,y )
      dim.visible = true
      @sketch.constraints << dim
      $manager.cancel_current_tool
      @glview.redraw
    else
      # use point instead of segment if we find one near
=begin
      points = @sketch.segments.map{|s| s.snap_points }.flatten
  		points = points.select do |p|
  			dist = Point.new(x, @glview.allocation.height - y).distance_to @glview.world2screen(sketch2world p)
  			dist < $preferences[:snap_dist]
  		end
=end
  		p, was_snapped = point_snapped( world2sketch(@glview.screen2world(x,y)) )
  		#if not points.empty?
  		if was_snapped
  		  #p = points.first
  		  @selected_segments << p
  		  $manager.set_status_text( GetText._("Choose a point to position your dimension:") ) if @selected_segments.size == 2
		  else
		    # don't use segment if we have one point already
		    unless @selected_segments.is_a? Array and @selected_segments.size == 1
  		    if seg = @glview.select(x,y)
  	        @selected_segments = seg
  	        $manager.set_status_text( GetText._("Choose a point to position your dimension:") )
	        end
	      end
	    end
	  end
	  super
	end
	
	def dimension_for( seg_or_points, x,y )
	  if seg_or_points.is_a? Arc
	    pos = @glview.screen2world( x,y )
	    return RadialDimension.new( seg_or_points, world2sketch(pos) ) if pos
	    return nil
    elsif seg_or_points.is_a? Line
      pos = @glview.screen2world( x,y )
	    return LinearDimension.new( seg_or_points, :horizontal, world2sketch(pos) ) if pos
      return nil
    elsif seg_or_points.is_a? Array and seg_or_points.size == 2
      #XXX create linear dimension
      return nil
    else
      return nil
    end
	end
	
	def mouse_move( x,y )
  	super
  	p = @glview.screen2world(x,y)
  	p, snapped = point_snapped( world2sketch(p) ) if p
  	@draw_dot = snapped ? p : nil
  	@temp_dim = dimension_for( @selected_segments, x,y )
  	@glview.redraw
	end
	
	def draw
	  super
	  @temp_dim.draw if @temp_dim
	end
end
  

class EditSketchTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to select points, drag to move points, right click for options:"), sketch )
		@does_snap = false
		@points_to_drag = []
	end
	
	def click_left( x,y )
	  sel = @glview.select( x,y )
	 	case sel
	 	when Segment
	 	  if $manager.key_pressed? :Shift
	 	    $manager.selection.add sel
	 	    @selection ? (@selection.push sel) : (@selection = [])
 	    else
	 	    $manager.selection.select sel
		    @selection = [sel]
	    end
	  when Dimension
	    FloatingEntry.new( x,y, sel.value ) do |value| 
	      sel.value = value
	      #@sketch.update_constraints
	      @sketch.build_displaylist
	      @glview.redraw
      end
	  else
	    $manager.selection.deselect_all
	    @selection = nil
		end
		@sketch.build_displaylist
		@glview.redraw
		super
	end
	
  def press_left( x,y )
    super
    @does_snap = true
    pos = @glview.screen2world( x,y )
    new_selection = @glview.select( x,y )
    if pos and not new_selection.is_a? Dimension
      pos = world2sketch(pos)
      @drag_start = @draw_dot ? @draw_dot.dup : pos
    	@old_draw_dot = Marshal.load(Marshal.dump(@draw_dot))
    	# if drag starts on an already selected segment
		  if @selection and @selection.include? new_selection	   
		    @points_to_drag = @selection.map{|e| e.dynamic_points }.flatten.uniq
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
	  mouse_move( x,y, true, [@draw_dot] )
	  pos, dummy = snapped( x,y, [@draw_dot] )
	  if pos and @drag_start
	  	move = @drag_start.vector_to pos
	  	if @selection
			  @points_to_drag.zip( @old_points ).each do |neu, original|
			    neu.x = original.x + move.x
			    neu.y = original.y + move.y
			    neu.z = original.z + move.z
		    end
		    @sketch.update_constraints @points_to_drag
		  elsif @draw_dot
		    @draw_dot.x = @old_draw_dot.x + move.x
	      @draw_dot.y = @old_draw_dot.y + move.y
	      @draw_dot.z = @old_draw_dot.z + move.z
	      @sketch.update_constraints [@draw_dot]
		  end
		  @sketch.build_displaylist
	    @glview.redraw
    end
	end
	
	def release_left
	  super
	  @does_snap = false
    @sketch.update_constraints
    @sketch.build_displaylist
	  @glview.redraw
  end
  
  def mouse_move( x,y, only_super=false, excluded=[] )
  	super( x,y, excluded )
  	unless only_super
  		points = @sketch.segments.map{|s| [s.pos1, s.pos2] }.flatten
  		@draw_dot = points.select{|point|
  			dist = Point.new(x, @glview.allocation.height - y).distance_to @glview.world2screen(sketch2world(point))
  			dist < $preferences[:snap_dist]
  		}.first #XXX use point_snapped instead
  		@glview.redraw
		end
  end
	
	def click_middle( x,y )
	  super
	  sel = @glview.select( x,y )
		if sel
			@selection = sel.sketch.chain( sel )
			if @selection
				$manager.selection.select *@selection
				sel.sketch.build_displaylist
				@glview.redraw
			end
		else
		  $manager.selection.deselect_all
		end
  end
  
  def click_right( x,y, time )
    new_selection = @glview.select( x,y )
    click_left( x,y ) unless @selection and @selection.include? new_selection
	  @glview.redraw
	  menu = SketchSelectionToolMenu.new
	  menu.popup(nil, nil, 3,  time)
	end
end


class TrimTool < SketchTool
	def initialize sketch
		super( GetText._("Click left to delete subsegments of your sketch:"), sketch )
		@does_snap = false
		save_real_segments
	end
	
	def save_real_segments
		# replace sketch segments with precut versions
		@old_segments = @sketch.segments
		@mapper = {}
		cut_segments = @sketch.segments.inject([]) do |all_cut, seg| 
			cut_segs = seg.cut_with( @sketch.segments - [seg] )
			cut_segs.each{|cs| @mapper[cs.object_id] = seg }
			all_cut += cut_segs
		end
		@sketch.segments = cut_segments
		@sketch.build_displaylist
	end
	
	def mouse_move( x,y )
  	super
  	if sel = @glview.select( x,y )
			$manager.selection.select sel
		else
			$manager.selection.deselect_all
		end
		@glview.redraw
  end
  
	def click_left( x,y )
	  super
  	if sel = @glview.select( x,y )
			real_seg = @mapper[sel.object_id]
			new_segs = real_seg.trim_between( sel.pos1, sel.pos2 )
			@old_segments.delete real_seg
			@sketch.segments = @old_segments + new_segs
			save_real_segments
		end
	end
	
	def exit
		super
		# restore sketch with original segments
		@sketch.segments = @old_segments
		@sketch.build_displaylist
	end
end













