#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'glut'
require 'matrix.rb'
require 'units.rb'

Glut.glutInit


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
      for static_pos in @segments.reject{|s| s.is_a? Line }.map{|seg| seg.snap_points }.flatten
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

  def update_constraints( immutables, try=0 )
    max_retries = @constraints.size * 2
    begin
      #immutable_constr.save_state
      constraints = immutables.map{|im| im.constraints }.flatten.uniq
      already_checked = []
      begin
        changed = false
        new_constraints = []
        constraints.sort_by{rand}.each do |c|
          changed = true if c.update immutables
          immutables += c.constrained_objects
          new_constraints += c.connected_constraints
          already_checked << c
        end
        constraints = new_constraints - already_checked
      end while changed
      return true
    rescue OverconstrainedException => e
      #immutable_constr.revert_state
      #puts "WARNING: Could not solve sketch"
      return e.constraint.constrained_objects.any?{|o| update_constraints([o], try+1) } if try < max_retries
      puts "ERROR: Sketch is overdefined"
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

class OverconstrainedException < StandardError
  attr :constraint
  def initialize c
    super()
    @constraint = c
  end
end


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
    raise OverconstrainedException.new(self) if constrained_objects.all?{|p| immutable_objs.include? p } and not satisfied
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

class HorizontalConstraint < SketchConstraint
  def initialize( p1, p2 )
    @p1 = p1
    @p2 = p2
    super()
  end
  
  def constrained_objects
    [@p1, @p2]
  end
  
  def satisfied
    @p1.z == @p2.z
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
        mutable_obj.z = immutable.z
      else
        rand > 0.5 ? (@p2.z = @p1.z) : (@p1.z = @p2.z)
      end
      return true
    end
  end
end

class VerticalConstraint < SketchConstraint
  def initialize( p1, p2 )
    @p1 = p1
    @p2 = p2
    super()
  end
  
  def constrained_objects
    [@p1, @p2]
  end
  
  def satisfied
    @p1.x == @p2.x
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
        mutable_obj.x = immutable.x
      else
        rand > 0.5 ? (@p2.x = @p1.x) : (@p1.x = @p2.x)
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
    #constrained_objects.each{|o| @sketch.update_constraints [o] }
    @sketch.update_constraints constrained_objects
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
    pl = @sketch.plane
    Dimension.draw_arrow [Tool.sketch2world(pos1, pl), Tool.sketch2world(pos2, pl), Tool.sketch2world(pos3, pl)]
    Dimension.draw_text( "R#{enunit @arc.radius}", Tool.sketch2world(pos1, pl) )
  end
end

class HorizontalDimension < Dimension
  def initialize( line, pos, sketch, temp=false )
    @line = line
    p1 = @line.pos1
    p2 = @line.pos2
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    @up_direction = (pos.z > @line.midpoint.z)
    @offset = (@up_direction ? pos.z - upper : pos.z - lower)
    @length = value
    super(sketch, temp)
  end
  
  def satisfied
    @length == value
  end
  
  def value
    (@line.pos1.x - @line.pos2.x).abs
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
    pl = @sketch.plane
    p1 = Tool.sketch2world(@line.pos1, pl)
    p2 = Tool.sketch2world(@line.pos2, pl)
    left  = [p1.x, p2.x].min
    right = [p1.x, p2.x].max
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    # draw boundaries
    if @up_direction
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

class VerticalDimension < Dimension
  def initialize( line, pos, sketch, temp=false )
    @line = line
    p1 = @line.pos1
    p2 = @line.pos2
    left = [p1.x, p2.x].min
    right = [p1.x, p2.x].max
    @right_direction = (pos.x > @line.midpoint.x)
    @offset = (@right_direction ? pos.x - right : pos.x - left)
    @length = value
    super(sketch, temp)
  end
  
  def satisfied
    @length == value
  end
  
  def value
    (@line.pos1.z - @line.pos2.z).abs
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
        diff = -diff if mutable.z < immutable.z
        mutable.z += diff
      else
        points.sort_by{|p| p.z }.first.x -= diff/2.0
        points.sort_by{|p| p.z }.last.x  += diff/2.0
      end
      return true
    end
  end
  
  def constrained_objects
    [@line.pos1, @line.pos2]
  end
  
  def draw
    super
    pl = @sketch.plane
    p1 = Tool.sketch2world(@line.pos1, pl)
    p2 = Tool.sketch2world(@line.pos2, pl)
    left  = [p1.x, p2.x].min
    right = [p1.x, p2.x].max
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    # draw boundaries
    if @right_direction
      lbound = [Vector[right,  p1.y, lower], Vector[right + @offset,  p1.y, lower]]
      ubound = [Vector[right, p1.y, upper],  Vector[right + @offset, p1.y, upper]]
    else
      lbound = [Vector[left,  p1.y, lower], Vector[left + @offset,  p1.y, lower]]
      ubound = [Vector[left, p1.y, upper],  Vector[left + @offset, p1.y, upper]]
    end
    Dimension.draw_arrow( lbound, false )
    Dimension.draw_arrow( ubound, false )
    # draw arrows
    midpoint = lbound.last + lbound.last.vector_to(ubound.last) * 0.5
    Dimension.draw_arrow [midpoint - Vector[0,0,0.01], lbound.last]
    Dimension.draw_arrow [midpoint + Vector[0,0,0.01], ubound.last]
    # draw text
    Dimension.draw_text( enunit(value), midpoint )
  end
end

class LengthDimension < Dimension
  def initialize( p1, p2, cursor_pos, sketch, temp=false )
    @p1 = p1
    @p2 = p2
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    @offset = ((p1 + p2) / 2.0).vector_to(cursor_pos).length
    @value = value
    super(sketch, temp)
  end
  
  def constrained_objects
    [@p1, @p2]
  end
  
  def satisfied
    @value == value
  end
  
  def value
    @p1.vector_to(@p2).length
  end
  
  def value= val
    @value = val
    super
  end
  
  def update immutable_objs
    super
    if satisfied
      return false
    else
      diff = value - @value
      points = constrained_objects
      if points.any?{|p| immutable_objs.include? p }
        mutable = (points - immutable_objs)[0]
        immutable = (points - [mutable])[0]
      else
        mutable, immutable = points.sort_by{rand}
      end
      mutable.take_coords_from( mutable + mutable.vector_to(immutable).normalize * diff )
      return true
    end
  end
  
  def draw
    super
    pl = @sketch.plane
    p1 = Tool.sketch2world(@p1, pl)
    p2 = Tool.sketch2world(@p2, pl)
    left  = [p1.x, p2.x].min
    right = [p1.x, p2.x].max
    upper = [p1.z, p2.z].max
    lower = [p1.z, p2.z].min
    offset = p1.vector_to(p2).normalize.cross_product(pl.normal) * @offset
    # draw boundaries
    lbound = [p1, p1 + offset]
    rbound = [p2, p2 + offset]
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



