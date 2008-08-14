#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'gtkglext'
require 'opengl'
require 'glut'
Glut.glutInit
require 'matrix.rb'
require 'units.rb'
require 'material_editor.rb'
require 'part_dialog.rb'
require 'assembly_dialog.rb'
require 'progress_dialog.rb'



module Selectable
	attr_accessor :selection_pass_color, :selected
end


def bounding_box_from points
	xs = points.map{|p| p.x }
	ys = points.map{|p| p.y }
	zs = points.map{|p| p.z }
	min_x = xs.min ; max_x = xs.max
	min_y = ys.min ; max_y = ys.max
	min_z = zs.min ; max_z = zs.max
	corners = [
		Vector[min_x, min_y, min_z],
		Vector[min_x, min_y, max_z],
		Vector[min_x, max_y, min_z],
		Vector[max_x, min_y, min_z],
		Vector[min_x, max_y, max_z],
		Vector[max_x, max_y, min_z],
		Vector[max_x, min_y, max_z],
		Vector[max_x, max_y, max_z]]
	return points.empty? ? nil : corners
end


class Point
	attr_accessor :x, :y, :constraints
	def initialize( x=0, y=0 )
		@x = x
		@y = y
		@constraints = []
	end
end


class Vector # should be discarded in favor of point
  attr_writer :constraints
  def constraints
    @constraints ||= []
    @constraints
  end
end


class InfiniteLine
  def initialize( pos, dir )
    @pos = pos
    @dir = dir
  end
  
  def intersect_with plane
    po, pn = plane.origin, plane.normal
    t = (po - @pos).dot_product(pn) / @dir.dot_product(pn)
    @pos + (@dir * t)
  end
end


class Segment
  include Selectable
	attr_accessor :reference, :sketch, :resolution, :constraints
  def initialize( sketch )
		@sketch = sketch
		@reference = false
		@constraints = []
		@selection_pass_color = [1.0, 1.0, 1.0]
  end
  
  def snap_points
  	[]
  end
  
  def cut_with segs
  	[self]
  end
  
  def trim_between( p1, p2 )
  	[self]
  end
  
  def +( vec )
    raise "Segment #{self} does not make translated copies of itself"
  end
  
  def draw
    raise "Segment #{self} is not able to draw itself"
  end
end

class Line < Segment
	attr_accessor :pos1, :pos2
	def initialize( start, ende, sketch=nil )
	  super sketch
		@pos1 = start.dup
		@pos2 = ende.dup
	end
=begin
	def own_and_neighbooring_points
	  points = []
	  for seg in @sketch.segments
	    for pos in [seg.pos1, seg.pos2]
	      if [@pos1, @pos2].any?{|p| p.x == pos.x and p.y == pos.y and p.z == pos.z }
	        points.push pos
        end
      end
    end
    return points.uniq
  end
=end
#	def bounding_box
#		return bounding_box_from [@pos1, @pos2]
#	end

	def midpoint
		(@pos1 + @pos2) / 2.0
	end

	def snap_points
		super + [@pos1, @pos2, midpoint]
	end
	
	def dynamic_points
	   [@pos1, @pos2]
	end

	def tesselate
	  [self]
	end
	
	def length
	  @pos1.vector_to(@pos2).length
	end

	def draw
    GL.Begin( GL::LINES )
      GL.Vertex( @pos1.x, @pos1.y, @pos1.z )
      GL.Vertex( @pos2.x, @pos2.y, @pos2.z )
    GL.End
	end

	def +( vec )
	  Line.new( @pos1 + vec, @pos2 + vec, @sketch )
  end

	def dup
    copy = super
    copy.pos1 = @pos1.dup
    copy.pos2 = @pos2.dup
    copy
	end
end

class Arc < Segment
  attr_accessor :center, :radius, :start_angle, :end_angle, :points
  def initialize( center, radius, start_angle, end_angle, sketch=nil )
    super sketch
    @center = center
    @radius = radius
    @start_angle = start_angle
    @end_angle = end_angle
    @points = []
  end
  
  def point_at angle
    x = Math.cos( (angle/360.0) * 2*Math::PI ) * @radius + @center.x
    z = Math.sin( (angle/360.0) * 2*Math::PI ) * @radius + @center.z
    return Vector[ x, @center.y, z ]
  end
  
  def pos1
    point_at @start_angle
  end
  
  def pos2
    point_at @end_angle
  end
  
  def own_and_neighbooring_points
	  points = []
	  for seg in @sketch.segments
	    for pos in [seg.pos1, seg.pos2]
	      if [pos1, pos2].any?{|p| p.x == pos.x and p.y == pos.y and p.z == pos.z }
	        points.push pos
        end
      end
    end
    points.push @center
    return points.uniq
  end

  def snap_points
  	super + [pos1, pos2, @center]
  end
  
  def dynamic_points
    [@center]
  end
  
  def tesselate
    span = (@start_angle - @end_angle).abs
  	if span > 0
		  angle = @start_angle
		  increment = span / $preferences[:surface_resolution]
		  @points.clear
		  while (angle - @end_angle).abs > increment
		  	@points.push point_at angle
		  	angle += increment
		  	angle = angle - 360 if angle > 360
		  end
		  @points << point_at( @end_angle )
		end
    @lines = []
    for i in 0...(@points.size-1)
      line = Line.new( @points[i], @points[i+1] )
      line.selection_pass_color = @selection_pass_color
      @lines.push line
    end
    return @lines
  end
  
	def draw
	  tesselate #if @points.empty?
	  GL.Begin( GL::LINE_STRIP )
  	  for p in @points
        GL.Vertex( p.x, p.y, p.z )
      end
    GL.End
	end
	
	def +( vec )
	  copy = dup
	  copy.center = @center + vec
	  copy
  end
  
  def dup
    copy = super
    copy.center = @center.dup
    copy.points.clear
    copy
	end
end

class Circle < Arc
  def initialize( center, radius, sketch=nil)
    super center, radius, 0.0, 360.0, sketch
  end
  
  def Circle::from3points( p1, p2, p3, sketch=nil )
    
  end
  
  def Circle::from_opposite_points( p1, p2, sketch=nil )
    center = p1 + (p1.vector_to(p2) / 2.0)
    radius = center.distance_to p1
    Circle.new( center, radius, sketch)
  end
end


class Plane
	attr_accessor :origin, :u_vec, :v_vec
	def initialize( p1=nil, p2=nil, p3=nil )
		@origin = p1 ? p1 : Vector[0.0, 0.0, 0.0]
		@u_vec  = Vector[1.0, 0.0, 0.0]
		@v_vec  = Vector[0.0, 0.0, 1.0]
		if p1 and p2 and p3
		  @u_vec = origin.vector_to p2
		  @v_vec = origin.vector_to p3
	  end
	end
	
	def normal_vector
		return @v_vec.cross_product( @u_vec )
	end
	alias normal normal_vector
	
	def normal_vector= normal
	  normal.normalize!
	  help_vec = Vector[normal.y, normal.x, normal.z]
	  @u_vec = normal.cross_product( help_vec ).normalize
	  @v_vec = normal.cross_product( @u_vec ).normalize.invert
	end
	alias normal= normal_vector=
	
	def closest_point( p )
	  distance = normal_vector.dot_product( @origin.vector_to p )
    return p - ( normal_vector * distance )
	end
	
	def transform_like plane
			@origin = plane.origin
			@u_vec = plane.u_vec
			@v_vec = plane.v_vec
	end
end

class WorkingPlane < Plane
  include Selectable
	attr_reader :plane, :parent
	attr_accessor :size, :spacing, :visible, :displaylist, :pick_displaylist
	def initialize( parent, plane=nil )
		if plane
		  @origin = plane.origin
		  @u_vec = plane.u_vec
		  @v_vec = plane.v_vec
	  else
		  super()
	  end
		@displaylist = $manager.glview.add_displaylist
		@pick_displaylist = $manager.glview.add_displaylist
		@selection_pass_color = [1.0, 1.0, 1.0]
		@spacing = 0.05
		@size = 2
		@visible = false
		@parent = parent
		build_displaylists
	end
	
	def resize2fit points
		unless points.empty?
			max_dist = points.map{|p| p.distance_to Vector[0,0,0] }.max
			new_size = 4 * max_dist
			step = (new_size - @size) / ($preferences[:transition_duration] / 2)
			if step != 0
				@size.step( new_size, step ) do |size|
					@size = size
					build_displaylists
					$manager.glview.redraw
				end
			end
		end
	end
	
	def animate( direction=1 )
	  if $preferences[:animate_working_planes]
  	  original_size = @size
      GC.disable if $preferences[:manage_gc]
      start, ende = direction == 1 ? [0, @size] : [@size, 0]
  		start.step( ende, (@size / $preferences[:animation_duration]) * direction ) do |i|
  			@size = i
  			build_displaylists
  			$manager.glview.redraw
  		end
  		GC.enable if $preferences[:manage_gc]
  		@size = original_size
		end
	end
	
	def build_displaylists
		# calculate the number of WorkingPlane cells that fit in size
		num_cells = (@size / @spacing).floor
		# make sure we got an even number of cells
		num_cells -= num_cells % 2
		real_size = @spacing * num_cells
		half_size = real_size / 2
		# create lines for regular displaylist
		@verticals = []
		@horizontals = []
		(-half_size).step(half_size, @spacing) do |shift|
			# go from left to right and create vertical lines
			u_pos   = @u_vec * shift
			u_upper = u_pos + @v_vec * half_size
			u_lower = u_pos - @v_vec * half_size
			v_line  = Line.new( u_upper, u_lower )
			@verticals.push v_line
			# go up from below and create horizontal lines
			v_pos   = @v_vec * shift
			v_left  = v_pos - @u_vec * half_size
			v_right = v_pos + @u_vec * half_size
			u_line  = Line.new( v_left, v_right )
			@horizontals.push u_line
		end
		GL.NewList( @displaylist, GL::COMPILE)
			GL.LineWidth(0.1)
			col = [0.7,0.7,0.7]
			GL.Begin( GL::LINES )
				@verticals.each do |line| 
					GL.Color3f( col[0], col[1], col[2] )
					GL.Vertex( line.pos1.x, line.pos1.y, line.pos1.z )
					GL.Vertex( line.pos2.x, line.pos2.y, line.pos2.z )
				end
				@horizontals.each do |line| 
					GL.Color3f( col[0], col[1], col[2] )
					GL.Vertex( line.pos1.x, line.pos1.y, line.pos1.z )
					GL.Vertex( line.pos2.x, line.pos2.y, line.pos2.z )
				end
			GL.End
		GL.EndList
		# create pick displaylist
		upper_left  = @v_vec * half_size - @u_vec * half_size
		upper_right = @v_vec * half_size + @u_vec * half_size
		lower_right = @v_vec * (-half_size) + @u_vec * half_size
		lower_left  = @v_vec * (-half_size) - @u_vec * half_size
		GL.NewList( @pick_displaylist, GL::COMPILE )
			GL.Begin( GL::POLYGON )
				GL.Vertex( upper_left.x, upper_left.y, upper_left.z )
				GL.Vertex( upper_right.x, upper_right.y, upper_right.z )
				GL.Vertex( lower_right.x, lower_right.y, lower_right.z )
				GL.Vertex( lower_left.x, lower_left.y, lower_left.z )
			GL.End
		GL.EndList
	end
	
	def dup
	  copy = super
	  copy.displaylist = glview.add_displaylist
		copy.pick_displaylist = glview.add_displaylist
		copy.build_displaylists
		copy
	end
	
	def clean_up
		$manager.glview.delete_displaylist @displaylist
		$manager.glview.delete_displaylist @pick_displaylist
		@displaylist = nil
		@pick_displaylist = nil
		self
	end
end


module ChainCompletion
	def chain( segment, segments=@segments )
		chain = [segment]
		last_seg = segment
		pos = segment.pos2
		changed = true
		runs = 0
		while (not pos.near_to segment.pos1) and changed and runs <= segments.size
		  runs += 1
			changed = false
			for seg in segments
				if [seg.pos1, seg.pos2].any?{|p| p.near_to pos } and not seg == last_seg
					chain.push seg
					last_seg = seg
					if pos.near_to seg.pos1
						pos = seg.pos2
					elsif pos.near_to seg.pos2
						pos = seg.pos1
					end
					changed = true
					break
				end
			end
		end
		return (pos.near_to segment.pos1) ? chain : nil
	end
	
	def all_chains
		return [] if @segments.empty?
	  chains = []
	  segs = @segments.dup
	  begin
	    kette = chain( segs.first, segs )
	    chains.push kette
	    segs = segs - kette if kette
	  end until segs.empty? or not kette
	  puts "#{chains.compact.size} chains found"
	  return chains.compact
	end
	
	def ordered_polygons
		polygons = all_chains.map{|ch| Polygon::from_chain ch.map{|seg| seg.tesselate }.flatten }
		contained_in = {}
		depth = 0
		# check each poly for in how many others it is contained
		for poly in polygons
			for other in polygons
				if poly.contains? other
				  contained_in[other] ||= 0
				  contained_in[other]  += 1
				  depth += 1
				end
			end 
		end
		ordered_polys = []
		# subpolys must wind in opposite direction of parent
    depth.times do |i|
      polys = polygons.select{|p| contained_in[p] == i }
      i % 2 == 0 ? polys.each{|p| p.to_cw! } : polys.each{|p| p.to_ccw! }
      ordered_polys += polys
    end
		return ordered_polys.reverse
	end
	
	# close loops that broke because of imprecision
	def close_broken_loops
	  for dynamic_pos in @segments.select{|s| s.is_a? Line }.map{|line| [line.pos1, line.pos2] }.flatten
	  	for static_pos in @segments.select{|s| not s.is_a? Line }.map{|seg| seg.snap_points }.flatten
	  		if dynamic_pos.near_to static_pos
	  			dynamic_pos.x = static_pos.x
	  			dynamic_pos.y = static_pos.y
	  			dynamic_pos.z = static_pos.z
	  		end
	  	end
	  end
	end
	alias repair_broken_loops close_broken_loops
end


class Sketch
	include ChainCompletion
	attr_accessor :name, :parent, :op, :selection_pass, :selected, :displaylist, :segments, :plane, :constraints
	attr_reader :visible
	@@sketchcolor = [0,1,0]
	def initialize( name, parent, plane )
		@name = name
		@parent = parent
		@op = nil
		@segments = []
		@constraints = []
		@plane = WorkingPlane.new( parent, plane )
		@plane_id = parent.solid.faces.map{|f| (f.is_a? PlanarFace) ? f.plane : nil }.compact.index plane
		parent.working_planes.push @plane
		@displaylist = $manager.glview.add_displaylist
		@visible = false
    @selected = false
		@selection_pass = false
	end
	
	def visible= bool
	  @constraints.each{|c| c.visible = bool }
	  @visible = bool
	end
	
	def dimensions
	  @constraints.select{|c| c.is_a? Dimension }
	end

	def build_displaylist
		GL.NewList( @displaylist, GL::COMPILE)
		  for seg in @segments
			  if @selection_pass
				  GL.Color3f( seg.selection_pass_color[0], seg.selection_pass_color[1], seg.selection_pass_color[2] )
			  else
				  if seg.selected
					  GL.Color3f( $manager.glview.selection_color[0], $manager.glview.selection_color[1], $manager.glview.selection_color[2] )
				  else
					  GL.Color3f( @@sketchcolor[0], @@sketchcolor[1], @@sketchcolor[2] )
				  end
			  end
			  seg.draw
		  end
		#  for dim in @dimensions
		#    dim.draw
		#  end
		GL.EndList	
	end
	
	def refetch_plane_from_solid solid=nil
		solid ||= @parent.solid if @parent and @parent.solid
		if solid and @plane_id
			new_plane = solid.faces.map{|f| (f.is_a? PlanarFace) ? f.plane : nil }.compact[@plane_id]
			@plane.transform_like new_plane if new_plane
		end
	end
=begin
	def update_constraints immutable_objs=[]
	  #constraints = immutable_obj.constraints
	  changed = true
	  safety = 1000
	  constraints = @constraints
	  while changed and safety > 0
	    changed = false
	    constraints.sort_by{rand}.each{|c| changed = true if c.update immutable_objs }
	    #constraints = constraints.map{|c| c.connected_constraints }.flatten.uniq
	    safety -= 1
    end
    puts "WARNING: Sketch solver reached safety constraint" if safety == 0
    safety != 0
	end
=end
  def update_constraints immutables=[]
    begin
      #immutable_constr.save_state
  	  constraints = immutables.map{|im| im.constraints }.flatten.uniq
  	  already_checked = []
  	  begin
  	    changed = false
  	    new_constraints = []
  	    constraints.each do |c|
  	      changed = true if c.update immutables
  	      immutables += c.constrained_objects
  	      new_constraints += c.connected_constraints
  	      already_checked << c
	      end
	      constraints = new_constraints - already_checked
      end while changed
      return true
    rescue OverconstrainedException
      #immutable_constr.revert_state
      puts "WARNING: Overconstrained"
      return false
    end
  end
  
	def clean_up
		$manager.glview.delete_displaylist @displaylist
		@displaylist = nil
	end
	
	def dup
	  copy = super
	  copy.displaylist = $manager.glview.add_displaylist
	  copy.op = nil
	  copy.segments = @segments.dup
	  copy.constraints = []
	  copy
	end
end
class OverconstrainedException < RuntimeError ; end


class SketchConstraint
  include Selectable
  attr_accessor :selection_pass, :visible
  def initialize temp=false
    constrained_objects.each{|o| o.constraints << self } unless temp # if only used for drawing
  end
  
  def connected_constraints
    constrained_objects.map{|o| o.constraints }.flatten - [self]
  end
  
  def constrained_objects
    raise "#{self.class} does not constrain objects"
  end
  
  def satisfied
    rasie "#{self.class} doesn't know if it's satisfied"
  end
  
  def update immutable_objs
    raise OverconstrainedException if constrained_objects.all?{|p| immutable_objs.include? p } and not satisfied
  end
end

class CoincidentConstraint < SketchConstraint
  def initialize( p1, p2 )
    @p1 = p1
    @p2 = p2
    super()
  end
  
  def constrained_objects
    [@p1, @p2]
  end
  
  def satisfied
    @p1 == @p2
  end
  
  def update immutable_objs
    super
    if satisfied
      return false
    else
      objs = constrained_objects
      if objs.any?{|o| immutable_objs.include? o }
        mutable_obj = (objs - immutable_objs)[0]
        immutable = (objs - [mutable_obj])[0]
        mutable_obj.take_coords_from immutable
      else
        rand > 0.5 ? @p2.take_coords_from(@p1) : @p1.take_coords_from(@p2)
      end
      return true
    end
  end
end

class Dimension < SketchConstraint
  include Units
  def self.draw_arrow( points, draw_tip=true )
		GL.Begin( GL::LINE_STRIP )
			for p in points.flatten
		  	GL.Vertex(p.x, p.y, p.z)
		  end
		GL.End
    if draw_tip  
      p = points.last
      #XXX
    end
  end
  
  def self.draw_text( t, pos )
    GL.PushMatrix
      GL.Translate( pos.x, pos.y, pos.z )
      GL.Scale(0.0005, 0.0005, 0.0005)
      GL.Rotate(-90,1,0,0)
    	t.each_byte{|b| GLUT.StrokeCharacter(GLUT::STROKE_ROMAN, b) }
  	GL.PopMatrix
  end
  
  def initialize( sketch, temp = false )
    @sketch = sketch
    super(temp)
  end
  
  def value
    raise "Dimension #{self} cannot report its value"
  end
  
  def value= val
    # descandand code here
    update []
    constrained_objects.each{|o| @sketch.update_constraints [o] }
  end
  
  def draw
    c = @selection_pass ? @selection_pass_color : [0.85, 0.5, 0.99]
    GL.Color3f( *c )
    GL.LineWidth( @selection_pass ? 6.0 : 3.0 )
  end
end

class RadialDimension < Dimension
  def initialize( arc, position, sketch, temp=false )
    @arc = arc
    @direction = arc.center.vector_to(position).normalize
    @radius = value
    super(sketch, temp)
  end
  
  def satisfied
    @arc.radius == @radius
  end
  
  def value
     @arc.radius
  end
  
  def value= val
    @radius = val
    super
  end
  
  def constrained_objects
    [@arc]
  end
  
  def update immutable_objs
    super
    if satisfied
      return false
    else
      @arc.radius = @radius
      return true
    end
  end
  
  def draw
    super
    pos3 = @arc.center + (@direction * @arc.radius)
    pos2 = @arc.center + (@direction * (@arc.radius + $preferences[:dimension_offset]))
    pos1 = Vector[pos2.x + $preferences[:dimension_offset], pos2.y, pos2.z]
    pl = @arc.sketch.plane
    Dimension.draw_arrow [Tool.sketch2world(pos1, pl), Tool.sketch2world(pos2, pl), Tool.sketch2world(pos3, pl)]
    Dimension.draw_text( "R#{enunit @arc.radius}", Tool.sketch2world(pos2, pl) )
  end
end

class LinearDimension < Dimension
  def initialize( line, orientation, pos, sketch, temp=false )
    @line = line
    @orientation = orientation
    p1 = @line.pos1
    p2 = @line.pos2
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    @offset = (pos.z > @line.midpoint.z ? pos.z - upper : pos.z - lower)
    @length = value
    super(sketch, temp)
  end
  
  def satisfied
    @length == value
  end
  
  def value
    if @orientation == :horizontal
      (@line.pos1.x - @line.pos2.x).abs
    elsif @orientation == :vertical
      (@line.pos1.y - @line.pos2.y).abs
    end
  end
  
  def value= val
    @length = val
    super
  end
  
  def update immutable_objs
    super
    if satisfied
      return false
    else
      diff = @length - value
      points = constrained_objects
      if points.any?{|p| immutable_objs.include? p }
        mutable = (points - immutable_objs)[0]
        immutable = (points - [mutable])[0]
        diff = -diff if mutable.x < immutable.x
        mutable.x += diff
      else
        points.sort_by{|p| p.x }.first.x -= diff/2.0
        points.sort_by{|p| p.x }.last.x  += diff/2.0
      end
      return true
    end
  end
  
  def constrained_objects
    [@line.pos1, @line.pos2]
  end
  
  def draw
    super
    pl = @line.sketch.plane
    p1 = Tool.sketch2world(@line.pos1, pl)
    p2 = Tool.sketch2world(@line.pos2, pl)
    left  = [p1.x, p2.x].min
    right = [p1.x, p2.x].max
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    # draw boundaries
    if @offset >= 0
      lbound = [Vector[left,  p1.y, upper], Vector[left,  p1.y, upper + @offset]]
      rbound = [Vector[right, p1.y, upper], Vector[right, p1.y, upper + @offset]]
    else
      lbound = [Vector[left,  p1.y, lower], Vector[left,  p1.y, lower + @offset]]
      rbound = [Vector[right, p1.y, lower], Vector[right, p1.y, lower + @offset]]
    end
    Dimension.draw_arrow( lbound, false )
    Dimension.draw_arrow( rbound, false )
		# draw arrows
		midpoint = lbound.last + lbound.last.vector_to(rbound.last) * 0.5
    Dimension.draw_arrow [midpoint - Vector[0.01,0,0], lbound.last]
    Dimension.draw_arrow [midpoint + Vector[0.01,0,0], rbound.last]
    # draw text
    Dimension.draw_text( enunit(value), midpoint )
  end
end


class Polygon
  attr_accessor :points
  def Polygon::from_chain chain
    redundant_chain_points = chain.map{|s| s.tesselate }.flatten.map{|line| [line.pos1, line.pos2] }.flatten
    chain_points = []
    for p in redundant_chain_points
      chain_points.push p unless chain_points.include? p
    end
    poly = Polygon.new( chain_points )
    poly.close
		return poly
  end
  
  def initialize( points=[] )
    @points = points
    @normal = Vector[0,1,0]
  end
  
  def close
    @points.push @points.first unless @points.last == @points.first    
  end
  
  def push p
    @points.push p
  end
  
  def area
    mesh_area
  end
  
  def mesh_area
    tesselate.inject(0.0) do |area, triangle|
      edge_vec1 = triangle[0].vector_to triangle[1]
      edge_vec2 = triangle[0].vector_to triangle[2]
      tr_area = (edge_vec1.cross_product edge_vec2).length * 0.5
      area + tr_area
    end
  end
  
  def monte_carlo_area
  	samples = $preferences[:area_samples]
  	xs = @points.map{|p| p.x }.sort
  	zs = @points.map{|p| p.z }.sort
  	left = xs.first
  	right = xs.last
  	upper = zs.last
  	lower = zs.first
  	a = 0.0
  	samples.times do
  		x = left + rand * (right-left).abs
  		z = lower + rand * (upper-lower).abs
  		a += 1 if contains? Vector[x,z,0]
  	end
  	(a / samples) * (right-left).abs * (upper-lower).abs
  end

  def contains? point_or_poly
  	if point_or_poly.is_a? Polygon
  		poly = point_or_poly
  		return poly.points.all?{|p| self.contains? p }
  	else
  		point = point_or_poly
		  # shoot a ray from the point upwards and count the number ob edges it intersects
		  intersections = 0
		  0.upto( @points.size - 2 ) do |i|
		    e1 = @points[i]
		    e2 = @points[i+1]
		    # check if edge intersects up-axis
		    if (e1.x <= point.x and point.x <= e2.x) or (e1.x >= point.x and point.x >= e2.x)
		      left_dist = (e1.x - point.x).abs
		      right_dist = (e2.x - point.x).abs
		      intersection_point = (e1 * right_dist + e2 * left_dist) * (1.0 / (left_dist + right_dist))
		      intersections += 1 if intersection_point.z > point.y
		    end
		  end
		  return intersections % 2 != 0
		 end
  end
  
  def to_cw!
    @points.reverse! unless clockwise?
    self
  end
  
  def to_ccw!
    @points.reverse! if clockwise?
    self
  end
  
  def clockwise?
    cross = @points[0].vector_to( @points[1] ).cross_product( @points[1].vector_to( @points[2] ) )
    dot = cross.dot_product @normal
    return dot < 0
  end
	
	def tesselate
	  vertices = []
		tess = GLU::NewTess()
		GLU::TessCallback( tess, GLU::TESS_VERTEX, lambda{|v| vertices << Vector[v[0],v[1],v[2]] if v } )
   	GLU::TessCallback( tess, GLU::TESS_BEGIN, lambda{|which| vertices << which.to_s } )
   	GLU::TessCallback( tess, GLU::TESS_END, lambda{ } )
   	GLU::TessCallback( tess, GLU::TESS_ERROR, lambda{|errCode| raise "Tessellation Error: #{GLU::ErrorString errCode}" } )
   	GLU::TessCallback( tess, GLU::TESS_COMBINE, 
     	lambda do |coords, vertex_data, weight|
  			vertex = [coords[0], coords[1], coords[2]]
  			vertex
  		end 
		)
		GLU::TessProperty( tess, GLU::TESS_WINDING_RULE, GLU::TESS_WINDING_POSITIVE )
		GLU::TessBeginPolygon( tess, nil )
			GLU::TessBeginContour tess
				@points.each{|p| GLU::TessVertex( tess, p.elements, p.elements ) }
			GLU::TessEndContour tess
		GLU::TessEndPolygon tess
		GLU::DeleteTess tess
		# vertices should now be filled with interleaved points and drawing instructions
		# as grouping is triggered through the next instruction string we put a random one at the end 
		vertices << GL::TRIANGLES.to_s
		triangles = []
		container = []
		last_geom_type = nil
		for point_or_instruct in vertices
		  case point_or_instruct
	    when String    
	      case last_geom_type
        when GL::TRIANGLES.to_s
          triangles += triangles2triangles container
        when GL::TRIANGLE_STRIP.to_s
          triangles += triangle_strip2triangles container
        when GL::TRIANGLE_FAN.to_s
          triangles += triangle_fan2triangles container
        when nil
        else 
          raise "We dont handle this GL geometry type yet: #{point_or_instruct}"
        end
        last_geom_type = point_or_instruct
        container = []
      when Vector
        container << point_or_instruct
	    end
		end
		return triangles
	end
	
	def triangle_strip2triangles points
	  triangles = []
	  points.each_with_index do |p,i|
	    break unless points[i+2]
	    triangles << ( i % 2 == 0 ? [p, points[i+1], points[i+2]] : [points[i+1], p, points[i+2]] )
    end
    triangles
	end
	
	def triangle_fan2triangles points
	  center = points.shift
	  triangles = []
	  points.each_with_index do |p,i|
	    break unless points[i+1]
	    triangles << [center, p, points[i+1]]
    end
    triangles
	end
	
	def triangles2triangles points
	  triangles = []
	  triangles << [points.shift, points.shift, points.shift] until points.empty?
	  triangles
	end
end


class Face
  include Selectable
  include ChainCompletion
	attr_accessor :segments, :solid, :created_by_op
	def initialize op=nil
	  @created_by_op = op
		@segments = []
		@selection_pass_color = [1.0, 1.0, 1.0]
		@solid = nil
	end
	
	def draw
    raise "Face #{self} cannot draw itself"
	end
	
	def area
    0.0
	end
	
	def dup
		copy = super
		copy.segments = segments.map{|s| s.dup }
		return copy
	end
end

class PlanarFace < Face
	attr_accessor :plane
	attr_reader :polygon
	def initialize
	  super()
		@plane = Plane.new
	end
	
	def pretesselate
	 	ch = chain( @segments.first )
		if ch
			@polygon = Polygon.from_chain( ch ).to_cw!
		else
			raise "Trying to build face #{self} from non-closed segment chain"
		end
	end
	
	def draw
	  pretesselate unless @polygon
	  normal = @plane.normal_vector.invert
	  GL.Normal( normal.x, normal.y, normal.z )
		tess = GLU::NewTess()
		GLU::TessCallback( tess, GLU::TESS_VERTEX, lambda{|v| GL::Vertex v if v} )
   	GLU::TessCallback( tess, GLU::TESS_BEGIN, lambda{|which| GL::Begin which } )
   	GLU::TessCallback( tess, GLU::TESS_END, lambda{ GL::End() } )
   	GLU::TessCallback( tess, GLU::TESS_ERROR, lambda{|errCode| raise "Tessellation Error: #{GLU::ErrorString errCode}" } )
   	GLU::TessCallback( tess, GLU::TESS_COMBINE, 
   	lambda do |coords, vertex_data, weight|
			vertex = [coords[0], coords[1], coords[2]]
			vertex
		end )
		GLU::TessProperty( tess, GLU::TESS_WINDING_RULE, GLU::TESS_WINDING_POSITIVE )
		GLU::TessBeginPolygon( tess, nil )
			GLU::TessBeginContour tess
				for point in @polygon.points
					GLU::TessVertex( tess, point.elements, point.elements )
				end
			GLU::TessEndContour tess
		GLU::TessEndPolygon tess
		GLU::DeleteTess tess
	end
	
	def area
	  @polygon or pretesselate
	  @polygon.area
	end
end

class CircularFace < Face
	def initialize( axis, radius, position, height, start_angle, end_angle )
	  super()
		@axis        = axis.normalize
		@radius      = radius
		@position    = position
		@height      = height
		@start_angle = start_angle
		@end_angle   = end_angle
		# build outlines
		lower_arc = Arc.new( @position, @radius, start_angle, end_angle)
		upper_arc = lower_arc.dup
		upper_arc.center = @position + @axis * @height
		lower_edge = lower_arc.tesselate
		upper_edge = upper_arc.tesselate
		borders = [ Line.new( lower_arc.pos1, upper_arc.pos1), Line.new( lower_arc.pos2, upper_arc.pos2) ]
		@segments =  [lower_arc, upper_arc] + borders
	end
	
	def draw
	  plane = Plane.new
	  plane.normal = @axis
	  arc = Arc.new( @position, @radius, @start_angle, @end_angle )
	  for line in arc.tesselate
  	  corner1 = line.pos1
  		corner2 = line.pos1 + @axis * @height
  		corner3 = line.pos2 + @axis * @height
  		corner4 = line.pos2
			GL.Begin( GL::POLYGON )
			  normal = @position.vector_to( line.pos1 ).normalize
			  GL.Normal( normal.x, normal.y, normal.z )
				GL.Vertex( corner1.x, corner1.y, corner1.z )
				GL.Vertex( corner2.x, corner2.y, corner2.z )
				normal = @position.vector_to( line.pos2 ).normalize
  			GL.Normal( normal.x, normal.y, normal.z )
				GL.Vertex( corner3.x, corner3.y, corner3.z )
				GL.Vertex( corner4.x, corner4.y, corner4.z )
			GL.End
		end
	end
end

class FreeformFace < Face
  def initialize
    
  end
end


class Solid
	attr_accessor :faces
	def initialize
		@faces = []
	end
	
	def add_face f
	  f.solid = self
	  @faces.push f
	end
	
	def surface_area
	 @faces.inject(0){|sum,f| sum + f.area }
	end
	alias area surface_area
	
	def volume
	  bbox = bounding_box
	  if bbox
	    left  = bbox.map{|v| v.x }.min
	    right = bbox.map{|v| v.x }.max
	    upper = bbox.map{|v| v.y }.max
	    lower = bbox.map{|v| v.y }.min
	    front = bbox.map{|v| v.z }.max
	    back  = bbox.map{|v| v.z }.min
	    divisions = 5
	    max_change = 0.00001
	    # divide bounding volume into subvolumes
	    x_span = (right - left)  / divisions
	    y_span = (upper - lower) / divisions
	    z_span = (front - back)  / divisions
	    box_volume = x_span * y_span * z_span
	    max_change_per_box = max_change * divisions / box_volume
	    subvolumes = []
	    progress = ProgressDialog.new "<b>Calculating solid volume...</b>"
	    progress.fraction = 0.0
	    subvolumes_finished = 0
	    increment = 1.0 / divisions**3
	    @faces.each{|f| f.pretesselate }
	    for ix in 0...divisions
	      box_left = left + (ix * x_span)
	      for iy in 0...divisions
	        box_lower = lower + (iy * y_span)
	        for iz in 0...divisions
	          box_back = back + (iz * z_span)
	          # shoot samples into each subvolume until it converges
	          #subvolumes << Thread.start(box_left, box_lower, box_back) do |le,lo,ba|
	            le,lo,ba = box_left, box_lower, box_back
	            shots_fired = 0.0
	            hits = 0.0
	            change = 1.0
	            old_share = 1.0
	            begin
	              sx = le + (rand * x_span)
	              sy = lo + (rand * y_span)
	              sz = ba + (rand * z_span)
	              hits += 1 if self.contains? Vector[sx,sy,sz]
	              shots_fired += 1
	              if shots_fired % 10 == 0
	                share = hits / shots_fired
	                change = (share - old_share).abs
	                old_share = share
                end
	            end while change > max_change_per_box
	            #puts "Fired #{shots_fired} shots"
	            Gtk.queue do
	   	      	  progress.fraction += increment
  				      progress.text = GetText._("sampling bucket") + " #{subvolumes_finished}/#{divisions**3}" 
  				      subvolumes_finished += 1
  				    end
	            subvolumes << box_volume * (hits / shots_fired)
           # end
	        end
        end
	    end
	    volume = subvolumes.inject(0){|total,v| total + v } #.value }
	    Gtk::main_iteration while Gtk::events_pending?
	    progress.close
	    volume
    else
      0.0
    end
	end
	
	def contains? p
	  l = InfiniteLine.new( p, Vector[0,1,0] )
	  intersections = 0
	  for f in faces.select{|f| f.is_a? PlanarFace } #XXX should work for all faces
	    sect = l.intersect_with f.plane
	    # only consider the ray going in one direction
	    if sect.y > p.y
	      # check if within bounds of face
	      #sect = Tool.world2sketch( sect, f.plane )
	      sect = Point.new( sect.x, sect.z )
	      intersections += 1 if f.polygon.contains? sect
      end
	  end
	  intersections % 2 != 0
	end
	
	def bounding_box
		points = @faces.map{|f| f.segments.map{|seg| seg.snap_points } }.flatten
		return bounding_box_from points
	end
	
	def dup
		copy = super
		copy.faces = faces.dup#map{|f| f.dup }
		return copy
	end
end


# abstract base class for operators
class Operator
	attr_reader :settings, :solid, :part, :dimensions
	attr_accessor :name, :enabled, :previous#, :toolbar
	def initialize part
		@name ||= "operator"
		@settings ||= {}
		@save_settings = @settings.dup
		@solid = nil
		@part = part
		@dimensions = []
		@enabled = true
		@previous = nil
		#create_toolbar
	end
	
	def operate
		if @previous
			@solid = @previous.solid ? @previous.solid.dup : nil
			segs = settings[:segments]
		  if segs
		  	sketches = segs.map{|seg| seg.sketch }.compact.uniq
		  	sketches.each{|sk| sk.refetch_plane_from_solid @previous.solid }
		  end
		else
			@solid = Solid.new
		end
		if @enabled
  		new_faces = real_operate 
  		new_faces.each{|f| f.created_by_op = self }
		end
	end
	
	def real_operate
		raise "Error in #{self} : Operator#real_operate must be overriden by child class"
	end
	
	def show_toolbar
		@save_settings = @settings.dup
		toolbar = Gtk::Toolbar.new
		toolbar.toolbar_style = Gtk::Toolbar::BOTH
		toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		fill_toolbar toolbar
		toolbar.append( Gtk::SeparatorToolItem.new){}
		toolbar.append( Gtk::Stock::CANCEL, GetText._("Exit operator without saving changes"),"Operator/Cancel"){ cancel }
		toolbar.append( Gtk::Stock::OK, GetText._("Save changes and exit operator"),"Operator/Ok"){ ok }
		return toolbar
	end

	def draw_gl_interface

	end
	
	def ok
	  @part.build( self )
	  $manager.working_level_up
	  $manager.glview.redraw
	end
	
	def cancel
		@settings = @save_settings
		ok
	end
=begin
	def create_toolbar
		@toolbar = Gtk::Toolbar.new
		@toolbar.toolbar_style = Gtk::Toolbar::BOTH
		@toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		fill_toolbar 
		toolbar.append( Gtk::SeparatorToolItem.new){}
		@toolbar.append( Gtk::Stock::CANCEL, GetText._("Exit operator without saving changes"),"Operator/Cancel"){ cancel }
		@toolbar.append( Gtk::Stock::OK, GetText._("Save changes and exit operator"),"Operator/Ok"){ ok }
	end
=end
private
	def fill_toolbar 
		raise "Error in #{self} : Operator#fill_toolbar must be overriden by child class"
	end
	
	def show_changes
		@part.build self
		$manager.glview.redraw 
	end
end


class Component
  @@used_ids = []
	attr_reader :information, :component_id
	attr_accessor :thumbnail
	
	def self.new_id
	  id = rand 99999999999999999999999999999999999999999 while @@used_ids.include? id
    @@used_ids.push id
    id
  end
  
	def initialize
    @component_id = Component.new_id
    @thumbnail = nil
	end
	
	def thumbnail
	  @thumbnail ? @thumbnail.to_native : nil
	end
	
	def thumbnail= im
	 @thumbnail = im.to_tiny
	end
	
	def dup
	  copy = super
	  copy.component_id = new_id
	  copy
	end
	
	def name
	  information[:name]
	end
end

class Part < Component
  attr_accessor :displaylist, :wire_displaylist, :selection_displaylist, :history_limit, :solid, :information
	attr_reader :operators, :working_planes, :unused_sketches, :solid
	def initialize name
		super()
		@unused_sketches = []
		@working_planes = [ WorkingPlane.new(self) ]
		@operators = []
		@history_limit = 0
		@information = {:name     => name,
		                :author   => "",
							      :approved => "",
							      :version  => "0.1",
							      :material => $manager.materials.first}
		@displaylist = $manager.glview.add_displaylist
		@wire_displaylist = $manager.glview.add_displaylist
		@selection_displaylist = $manager.glview.add_displaylist
		@solid = Solid.new
	end

	def add_operator( op, index=@history_limit )
		@operators.insert( index, op )
		op.previous = @operators[index-1] unless index == 0
		@operators[index+1].previous = op if @operators[index+1]
		@history_limit += 1 if index <= @history_limit
		build op
	end
	
	def move_operator_up op
	  i = @operators.index op
	  unless i == 0 
	    remove_operator op
	    add_operator( op, i-1 )
    end
	end
	
	def move_operator_down op
	  i = @operators.index op
	  unless i == @operators.size - 1
	    remove_operator op
	    add_operator( op, i+1 )
    end
	end

	def remove_operator( op )
	  i = @operators.index op
		@operators.delete_at i 
		@operators[i].previous = (i >= 1 ? @operators[i-1] : nil) if @operators[i]
		@history_limit -= 1 if i < @history_limit
		if @operators[i]
		  build @operators[i] 
	  else
	    @solid = @operators.empty? ? Solid.new : @operators.last.solid
	    build_displaylist
    end
	end

	def build( from_op=@operators.first )
    if @history_limit >= 1
      raise "Operator must come before history limit" unless @operators.index(from_op) < @history_limit
		  @operators.index( from_op ).upto( @history_limit - 1 ) do |i|
		  	op = @operators[i]
		  	yield op if block_given?  # update progressbar
		  	op.operate
		  end
		  solid = @operators[@history_limit - 1].solid
	  else
	    solid = Solid.new
    end
		if solid
			@solid = solid
			build_displaylist
			$manager.glview.rebuild_selection_pass_colors
			$manager.component_changed self
			self.all_sketches.each{|sk| sk.refetch_plane_from_solid }
		else
			dia = Gtk::MessageDialog.new( nil, Gtk::Dialog::DESTROY_WITH_PARENT,
							                           Gtk::MessageDialog::WARNING,
							                           Gtk::MessageDialog::BUTTONS_OK,
							                           GetText._("Part could not be built"))
			dia.secondary_text = GetText._("Please recheck all operator settings and close any open sketch regions!")
			dia.run
			dia.destroy
		end
	end
	
	def bounding_box
    @solid.bounding_box
	end

	def build_displaylist
		# generate mesh and write to displaylist
	  GL.NewList( @displaylist, GL::COMPILE)
	    # draw shaded faces
		  @solid.faces.each do |face|
			  #col = @information[:material].color
			  #GL.Color4f(col[0], col[1], col[2], @information[:material].opacity)
				#GL.Begin( GL::POLYGON )
				#face.segments.each do |seg|
          #GL.TexCoord2f(0.995, 0.005)
					#GL.Vertex( seg.pos1.x, seg.pos1.y, seg.pos1.z )
				#end
				face.draw
				#GL.End
			end
		GL.EndList
		build_wire_displaylist
	end
	
	def build_wire_displaylist
	  GL.NewList( @wire_displaylist, GL::COMPILE)
  		all_segs = @solid.faces.map{|face| face.segments }.flatten
  		GL.Disable(GL::LIGHTING)
  		GL.LineWidth( 1.5 )
  			for seg in all_segs
  			  seg.draw
  			end
		GL.EndList
	end
	
	def build_selection_displaylist
	  GL.NewList( @selection_displaylist, GL::COMPILE)
		  @solid.faces.each do |face|
			  c = face.selection_pass_color
			  GL.Color3f( c[0],c[1],c[2] )
				face.draw
			end
		GL.EndList
	end
	
	def display_properties
		dia = PartInformationDialog.new(self) do |info|
		  @information = info if info
			$manager.op_view.update
			#XXX build_displaylist if @solid
			$manager.glview.redraw
	  end
	end
	
	def area
	  @solid.area
	end
	
	def volume
	  @solid.volume
	end
	
	def mass from_volume=@solid.volume
	  from_volume * @information[:material].density
	end
	
	def dimensions
	  (all_sketches.map{|sk| sk.dimensions } + @operators.map{|op| op.dimensions }).flatten.uniq
	end
	
	def clean_up
		$manager.glview.delete_displaylist @displaylist
		$manager.glview.delete_displaylist @wire_displaylist
		$manager.glview.delete_displaylist @selection_displaylist
	  @displaylist = nil
	  @wire_displaylist = nil
	  @selection_displaylist = nil
	end
	
	def all_sketches
	  (@unused_sketches + @operators.map{|op| op.settings[:sketch] }).compact
	end
	

	def dup
	  copy = super
	  copy.unused_sketches = @unused_sketches.dup
	  copy.working_planes = @working_planes.dup
	  copy.operators = @operators.dup
	  copy.information = @information.dup
	  copy.solid = @solid.dup
	  @displaylist = $manager.glview.add_displaylist
		@wire_displaylist = $manager.glview.add_displaylist
		@selection_displaylist = $manager.glview.add_displaylist
	end
end

class Assembly < Component
	attr_accessor :components
	def initialize name
		super()
		@component_id = component_id() 
		@components = []
		@contact_set = []
		@information = {:name      => name,
		                :author    => "",
				            :approved  => "",
				            :version   => "0.1"}
	end

	def remove_component( comp )
		if comp.is_a? String
			@components.delete_if {|c| c.name == comp }
		elsif comp.is_a? Instance
			@components.delete comp 
		end
	end
	
	def build_displaylist
	 @components.each{|c| c.build_displaylist }
	end

	def add_constraint(part1, face1, part2, face2)

	end

	def remove_constraint(part1, face1, part2, face2)

	end

	def update_constraints

	end

	def transparent=( bool )
		@components.each {|c| c.transparent = bool}
	end

	def display_properties
		dia = AssemblyInformationDialog.new(self) do |info|
		  @information = info if info
			$manager.op_view.update
	  end
	end
	
	def area
	  @components.inject(0.0){|area,c| area + c.area }
	end
	
	def volume
	  @components.inject(0.0){|area,c| area + c.volume }
	end
	
	def mass
	  @components.inject(0.0){|area,c| area + c.mass }
	end
	
	def bounding_box
		@components.map{|c| c.bounding_box }.flatten.compact
	end
	
	def dimensions
	  @components.map{|c| c.dimensions }.flatten
	end
end


class Instance
  include Selectable
  @@used_ids ||= []
	attr_reader :parent, :position, :transparent, :component_id
	attr_accessor :visible, :real_component
	def initialize( component, parent=nil )
		raise "Parts must have a parent" if component.class == Part and not parent
		@real_component = component
		@position = Vector[0,0,0]
		@parent = parent
		@transparent = false
		@visible = true
		@selection_pass_color = [1.0, 1.0, 1.0]
		@instance_id = rand 99999999999999999999999999999999999999999 while @@used_ids.include? @instance_id
    @@used_ids.push @instance_id
	end
	
	def dup
		copy = super
		copy.real_component = @real_component
		copy
	end
	
	def class
		@real_component.class
	end
	
	def method_missing( method, *args )
		@real_component.send( method, *args )
	end
	
	def selected= bool
	 self.components.each{|c| c.selected = bool } if self.class == Assembly
	 @selected = bool
	end
	
	def transparent= bool
	  @transparent = bool
	  self.components.each{|c| c.transparent = bool} if self.class == Assembly
  end
end




