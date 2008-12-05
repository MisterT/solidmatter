#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'matrix.rb'
require 'units.rb'


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
	points.empty? ? nil : corners
end

def sparse_bounding_box_from points
  if points.empty?
    nil
  else
	  xs = points.map{|p| p.x }
	  ys = points.map{|p| p.y }
	  zs = points.map{|p| p.z }
	  min_x = xs.min ; max_x = xs.max
	  min_y = ys.min ; max_y = ys.max
	  min_z = zs.min ; max_z = zs.max
    center = Vector[(min_x + max_x)/2.0, (min_y + max_y)/2.0, (min_z + max_z)/2.0,]
    width  = (min_x - max_x).abs
    height = (min_y - max_y).abs
    depth  = (min_z - max_z).abs
    [center, width, height, depth]
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
  
  def bounding_box
    bounding_box_from snap_points.map{|p| Tool.sketch2world(p, @sketch.plane) }
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


class Vector # should be discarded in favor of point
  attr_writer :constraints
  def constraints
    @constraints ||= []
    @constraints
  end
  
  def dynamic_points
    [self]
  end

  def draw
    GL.Color3f(0.98,0.87,0.18)
    GL.PointSize(8.0)
    GL.Begin( GL::POINTS )
      GL.Vertex( x,y,z )
    GL.End
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
		  increment = span.to_f / $preferences[:surface_resolution]
		  @points.clear
		  begin
		  	@points.push point_at angle
		  	angle += increment
		  	angle = angle - 360 if angle > 360
		  end until (angle - @end_angle).abs < increment
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
  
  def snap_points
    quadrants = [0, 90, 180, 270].map{|a| point_at a }
  	super + quadrants
  end
end

class Spline < Segment
	attr_accessor :cvs, :degree
	def initialize( cvs, degree=3, sketch=nil )
	  super sketch
	  @cvs = cvs
	  @degree = degree
	end
	
	def order
	  @degree + 1
	end
	
	def pos1
	  @cvs.first
	end
	
	def pos2
	  @cvs.last
	end
	
	def midpoint
	  
	end

	def snap_points
		super + [@cvs.first, @cvs.last]
	end
	
	def dynamic_points
	   @cvs
	end

	def tesselate
	  tess_vertices = []
	  if @cvs.size >= 2
  	  first_p = @cvs[0] + @cvs[1].vector_to(@cvs[0])
  	  last_p = @cvs[-1] + @cvs[-2].vector_to(@cvs[-1])
  	  nurb = GLU.NewNurbsRenderer
  	  knots = (0..(@cvs.size+order+2)).to_a
  	  points = ([first_p] + @cvs + [last_p]).map{|cv| cv.elements[0..3] }.flatten
  	  GLU.NurbsProperty( nurb, GLU::DISPLAY_MODE, GLU::OUTLINE_POLYGON)
  	  GLU.NurbsProperty( nurb, GLU::SAMPLING_METHOD, GLU::OBJECT_PATH_LENGTH )
      GLU.NurbsProperty( nurb, GLU::SAMPLING_TOLERANCE, $preferences[:surface_resolution] )
      GLU.NurbsProperty( nurb, GLU::NURBS_MODE, GLU::NURBS_TESSELLATOR )
      # register callbacks
      GLU.NurbsCallback( nurb, GLU::NURBS_BEGIN, lambda{ } )
      GLU.NurbsCallback( nurb, GLU::NURBS_END, lambda{ } )
  		GLU.NurbsCallback( nurb, GLU::NURBS_VERTEX, lambda{|v| puts "hooray"; tess_vertices << Vector[v[0],v[1],v[2]] if v } )
     	GLU.NurbsCallback( nurb, GLU::NURBS_ERROR, lambda{|errCode| raise "Nurbs tessellation Error: #{GLU::ErrorString errCode}" } )
      # tesselate curve
      GLU.BeginCurve nurb
        GLU.NurbsCurve( nurb, @cvs.size+order+2, knots, 3, points, order, GL::MAP1_VERTEX_3 )
      GLU.EndCurve nurb
      GLU.DeleteNurbsRenderer nurb
    end
    tess_vertices
	end
	
	def length
    0
	end

	def draw
	  if @cvs.size >= 2
  	  first_p = @cvs[0] + @cvs[1].vector_to(@cvs[0])
  	  last_p = @cvs[-1] + @cvs[-2].vector_to(@cvs[-1])
  	  # render curve
  	  nurb = GLU.NewNurbsRenderer
  	  knots = (0..(@cvs.size+order+2)).to_a
  	  points = ([first_p] + @cvs + [last_p]).map{|cv| cv.elements[0..3] }.flatten
  	  GLU.NurbsProperty( nurb, GLU::SAMPLING_METHOD, GLU::OBJECT_PATH_LENGTH )
      GLU.NurbsProperty( nurb, GLU::SAMPLING_TOLERANCE, $preferences[:surface_resolution] )
      GLU.BeginCurve nurb
        GLU.NurbsCurve( nurb, @cvs.size+order+2, knots, 3, points, order, GL::MAP1_VERTEX_3 )
      GLU.EndCurve nurb
      GLU.DeleteNurbsRenderer nurb
    end
    # draw vertices
    @cvs.each{|p| p.draw }
	end

	def dup
    copy = super
    copy.cvs.map!{|p| p.dup }
	end
end


class Plane
	attr_accessor :origin, :rotation, :u_vec, :v_vec
	def Plane.from3points( p1=nil, p2=nil, p3=nil)
		origin = p1 ? p1 : Vector[0.0, 0.0, 0.0]
		u_vec  = Vector[1.0, 0.0, 0.0]
		v_vec  = Vector[0.0, 0.0, 1.0]
		if p1 and p2 and p3
		  u_vec = origin.vector_to p2
		  v_vec = origin.vector_to p3
	  end
	  Plane.new(origin, u_vec, v_vec)
	end
	
	def initialize( o=nil, u=nil, v=nil )
		@origin = o ? o : Vector[0.0, 0.0, 0.0]
		@u_vec  = u ? u : Vector[1.0, 0.0, 0.0]
		@v_vec  = v ? v : Vector[0.0, 0.0, 1.0]
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


class Polygon
  attr_accessor :points
  def Polygon::from_chain chain
    redundant_chain_points = chain.map{|s| s.tesselate }.flatten.map{|line| [line.pos1, line.pos2] }.flatten
    chain_points = []
    for p in redundant_chain_points #XXX this should be possible with .uniq
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



