#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'gtkglext'
require 'opengl'
require 'lib/matrix.rb'
require 'lib/material_editor.rb'
require 'lib/part_dialog.rb'
require 'lib/assembly_dialog.rb'
require 'lib/progress_dialog.rb'


module Selectable
	attr_accessor :selection_pass_color, :selected
end


class Point
	attr_accessor :x, :y
	def initialize( x=0, y=0 )
		@x = x
		@y = y
	end
end


class Segment
  include Selectable
  attr_reader :sketch
	attr_accessor :reference
  def initialize( sketch )
		@sketch = sketch
		@reference = false
		@selection_pass_color = [1.0, 1.0, 1.0]
  end
end


class Line < Segment
	attr_accessor :pos1, :pos2
	def initialize( start, ende, sketch=nil )
	  super sketch
		@pos1 = start.dup
		@pos2 = ende.dup
	end
	
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
	
	def move( v )
    for pos in own_and_neighbooring_points
      pos.x += v.x
      pos.y += v.y
      pos.z += v.z
    end
    @sketch.build_displaylist
	end
	
	def dup
	 copy = super
	 copy.pos1 = @pos1.dup
	 copy.pos2 = @pos2.dup
	 return copy
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
	
	def closest_point( p )
	  distance = normal_vector.dot_product( @origin.vector_to p )
    return p - ( normal_vector * distance )
	end
end


class WorkingPlane < Plane
  include Selectable
	attr_reader :plane, :parent
	attr_accessor :size, :spacing, :visible, :glview, :displaylist, :pick_displaylist
	def initialize( glview, parent, plane=nil )
		if plane
		  @origin = plane.origin
		  @u_vec = plane.u_vec
		  @v_vec = plane.v_vec
	  else
		  super()
	  end
		@glview = glview
		@displaylist = glview.add_displaylist
		@pick_displaylist = glview.add_displaylist
		@selection_pass_color = [1.0, 1.0, 1.0]
		@spacing = 0.05
		@size = 2
		@visible = false
		@parent = parent
		build_displaylists
	end
	
	def animate( direction=1 )
	  if $preferences[:view_transitions]
  	  original_size = @size
      GC.disable if $preferences[:manage_gc]
      start, ende = direction == 1 ? [0, @size] : [@size, 0]
  		start.step( ende, (@size / $preferences[:transition_duration]) * direction ) do |i|
  			@size = i
  			build_displaylists
  			@glview.redraw
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
	
	def clean_up
		GL.DeleteLists( @displaylist, 1 )
		GL.DeleteLists( @pick_displaylist, 1 )
		@displaylist = nil
		@pick_displaylist = nil
	end
end


module ChainCompletion
	def chain( segment, segments=@segments )
		chain = [segment]
		last_seg = segment
		pos = segment.pos2
		changed = true
		runs = 0
		while (not pos == segment.pos1) and changed and runs <= segments.size
		  runs += 1
			changed = false
			for seg in segments
				if [seg.pos1, seg.pos2].include? pos and not seg == last_seg
					chain.push seg
					last_seg = seg
					if pos == seg.pos1
						pos = seg.pos2
					elsif pos == seg.pos2
						pos = seg.pos1
					end
					changed = true
					break
				end
			end
		end
		return pos == segment.pos1 ? chain : nil
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
		polygons = all_chains.map{|ch| Polygon::from_chain ch }
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
		# subpolys must wind in opposite direction of parent
    depth.times do |i|
      polys = polygons.select{|p| contained_in[p] == i }
      i % 2 == 0 ? polys.each{|p| p.to_cw! } : polys.each{|p| p.to_ccw! }
    end
		return polygons
	end
end



class Sketch
	include ChainCompletion
	attr_accessor :name, :parent, :op, :selection_pass, :visible, :selected, :glview, :displaylist
	attr_reader :plane, :segments
	@@sketchcolor = [0,1,0]
	def initialize( name, parent, plane, glview )
		@name = name
		@parent = parent
		@op = nil
		@glview = glview
		@segments = []
		@plane = WorkingPlane.new( glview, parent, plane )
		parent.working_planes.push @plane
		@displaylist = glview.add_displaylist
		@visible = false
    @selected = false
		@selection_pass = false
	end

	def build_displaylist
		GL.NewList( @displaylist, GL::COMPILE)
			GL.Begin( GL::LINES )
				@segments.each do |seg|
					if @selection_pass
						GL.Color3f( seg.selection_pass_color[0], seg.selection_pass_color[1], seg.selection_pass_color[2] )
					else
						if seg.selected
							GL.Color3f( @glview.selection_color[0], @glview.selection_color[1], @glview.selection_color[2] )
						else
							GL.Color3f( @@sketchcolor[0], @@sketchcolor[1], @@sketchcolor[2] )
						end
					end
					GL.Vertex( seg.pos1.x, seg.pos1.y, seg.pos1.z )
					GL.Vertex( seg.pos2.x, seg.pos2.y, seg.pos2.z )
				end
			GL.End
		GL.EndList	
	end
	
	def clean_up
		GL.DeleteLists( @displaylist, 1 )
		@displaylist = nil
	end
end


class Polygon
  attr_accessor :points
  def Polygon::from_chain chain
    redundant_chain_points = chain.map{|s| [s.pos1, s.pos2] }.flatten
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
		  return (intersections % 2 == 0) ? false : true
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
end


class Face
  include Selectable
  include ChainCompletion
	attr_accessor :segments
	def initialize
		@segments = []
		@selection_pass_color = [1.0, 1.0, 1.0]
	end
	
	def draw
		tess = GLU::NewTess()
		GLU::TessCallback( tess, GLU::TESS_VERTEX, lambda{|v| GL::Vertex v if v} )
   	GLU::TessCallback( tess, GLU::TESS_BEGIN, lambda{|which| GL::Begin which } )
   	GLU::TessCallback( tess, GLU::TESS_END, lambda{ GL::End() } )
   	GLU::TessCallback( tess, GLU::TESS_ERROR, lambda{|errCode| puts "Tessellation Error: #{GLU::ErrorString errCode}" } )
   	GLU::TessCallback( tess, GLU::TESS_COMBINE, 
   	lambda do |coords, vertex_data, weight|
			vertex = [coords[0], coords[1], coords[2]]
			vertex
		end )
		GLU::TessProperty( tess, GLU::TESS_WINDING_RULE, GLU::TESS_WINDING_POSITIVE )
		GLU::TessBeginPolygon( tess, nil )
			GLU::TessBeginContour tess
				ch = chain( @segments.first )
				if ch
					for point in Polygon.from_chain( ch ).to_cw!.points
						GLU::TessVertex( tess, point.elements, point.elements )
					end
				else
					puts "WARNING: Face #{self} could not be tesselated correctly"
				end 
			GLU::TessEndContour tess
		GLU::TessEndPolygon tess
		GLU::DeleteTess tess
	end
	
	def dup
		copy = super
		copy.segments = segments.map{|s| s.dup }
		return copy
	end
end

class PlanarFace < Face
	attr_accessor :plane
	def initialize
		@plane = Plane.new
	end
	
	def draw
	  normal = @plane.normal_vector.invert
	  GL.Normal( normal.x, normal.y, normal.z )
	  super
	end
end

class CircularFace < Face
	def initialize
		@axis = Line.new
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
	
	def dup
		copy = super
		copy.faces = faces.map{|f| f.dup }
		return copy
	end
end


# abstract base class for operators
class Operator
	attr_reader :settings, :solid, :part
	attr_accessor :name, :enabled, :previous, :manager, :toolbar
	def initialize( part, manager )
		@name ||= "operator"
		@settings ||= {}
		@save_settings = @settings
		@solid = nil
		@part = part
		@manager = manager
		@enabled = true
		@previous = nil
		create_toolbar
	end
	
	def operate
		@solid = @previous ? @previous.solid.dup : Solid.new
		real_operate if @enabled 
	end
	
	def real_operate
		raise "Error in #{self} : Operator#real_operate must be overriden by child class"
	end
	
	def show_toolbar
		@save_settings = @settings.dup
		return @toolbar
	end

	def draw_gl_interface

	end
	
	def ok
	  @part.build( self )
	  @manager.working_level_up
	  @manager.glview.redraw
	end
	
	def cancel
	 @settings = @save_settings
	 ok
	end

	def create_toolbar
		@toolbar = Gtk::Toolbar.new
		@toolbar.toolbar_style = Gtk::Toolbar::BOTH
		@toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
		fill_toolbar 
		toolbar.append( Gtk::SeparatorToolItem.new){}
		@toolbar.append( Gtk::Stock::CANCEL, "Exit operator without saving changes","Operator/Cancel"){ cancel }
		@toolbar.append( Gtk::Stock::OK, "Save changes and exit operator","Operator/Ok"){ ok }
	end
private
	def fill_toolbar 
		raise "Error in #{self} : Operator#fill_toolbar must be overriden by child class"
	end
	
	def show_changes
	 @part.build self
	 @manager.glview.redraw 
	end
end


class Component
  @@used_ids = []
	attr_reader :information
	def initialize
		@component_id = rand 99999999999999999999999999999999999999999 while @@used_ids.include? @component_id
    @@used_ids.push @component_id 
	end
	
	def name
	  information[:name]
	end
	
	def clean_up
	  GL.DeleteLists( @displaylist, 1 )
	  GL.DeleteLists( @wire_displaylist, 1 )
	  @displaylist = nil
	  @wire_displaylist = nil
	end
end


class Part < Component
  attr_accessor :manager, :displaylist, :wire_displaylist
	attr_reader :component_id, :operators, :working_planes, :unused_sketches, :solid
	def initialize(name, manager, disp_num, wire_disp_num )
		super()
		@manager = manager
		@unused_sketches = []
		@working_planes = [ WorkingPlane.new( manager.glview, self) ]
		@operators = []
		@history_limit = 0
		@information = {:name     => name,
		                :author   => "",
							      :approved => "",
							      :version  => "0.1",
							      :material => @manager.materials.first}
		@displaylist = disp_num
		@wire_displaylist = wire_disp_num
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
	  if from_op
  		@operators.index( from_op ).upto( @history_limit - 1 ){|i| op = @operators[i] ; yield op if block_given? ; op.operate  } # update progressbar
  		solid = @operators[@history_limit - 1].solid
  		if solid
  			@solid = solid
  			build_displaylist
  			@manager.component_changed self
  		else
  			dia = Gtk::MessageDialog.new( nil, Gtk::Dialog::DESTROY_WITH_PARENT,
  							                           Gtk::MessageDialog::WARNING,
  							                           Gtk::MessageDialog::BUTTONS_OK,
  							                           "Part could not be built. \nPlease recheck all operator settings!"
  			)
  			dia.run
  			dia.destroy
  		end
		end
	end
	
	def bounding_box
		xs = @solid.faces.map{|f| f.segments.map{|seg| [seg.pos1, seg.pos2].map{|pos| pos.x } } }.flatten
		ys = @solid.faces.map{|f| f.segments.map{|seg| [seg.pos1, seg.pos2].map{|pos| pos.y } } }.flatten
		zs = @solid.faces.map{|f| f.segments.map{|seg| [seg.pos1, seg.pos2].map{|pos| pos.z } } }.flatten
		corners = [
			Vector[xs.min, ys.min, zs.min],
			Vector[xs.min, ys.min, zs.max],
			Vector[xs.min, ys.max, zs.min],
			Vector[xs.max, ys.min, zs.min],
			Vector[xs.min, ys.max, zs.max],
			Vector[xs.max, ys.max, zs.min],
			Vector[xs.max, ys.min, zs.max],
			Vector[xs.max, ys.max, zs.max]]
		return corners
	end

	def build_displaylist( type=:normal)
		# generate mesh and write to displaylist
	  GL.NewList( @displaylist, GL::COMPILE)
	    # draw shaded faces
		  @solid.faces.each do |face|
			  #col = @information[:material].color
			  #GL.Color4f(col[0], col[1], col[2], @information[:material].opacity)
			  c = face.selection_pass_color
			  GL.Color3f( c[0],c[1],c[2] ) if type == :select_faces
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
  		GL.Begin( GL::LINES )
  		  for seg in all_segs
  				GL.Vertex( seg.pos1.x, seg.pos1.y, seg.pos1.z )
  				GL.Vertex( seg.pos2.x, seg.pos2.y, seg.pos2.z )
  			end
  		GL.End
		GL.EndList
	end
	
	def display_properties
		dia = PartInformationDialog.new( @information, @manager ) do |info|
		  @information = info if info
			@manager.op_view.update
			build_displaylist if @solid
			@manager.glview.redraw
	  end
	end
=begin
	def dup
	  copy = super
	  copy.unused_sketches = @unused_sketches.dup
	  copy.working_planes = @working_planes.dup
	  copy.operators = @operators.dup
	  copy.information = @information.dup
	  copy.solid = @solid.dup
	end
=end
end


class Assembly < Component
	attr_accessor :component_id, :components, :manager
	def initialize( name, manager )
		super()
		@component_id = component_id() 
		@manager = manager
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
		dia = AssemblyInformationDialog.new( @information, @manager ) do |info|
		  @information = info if info
			@manager.op_view.update
	  end
	end
	
	def bounding_box
		@components.map{|c| c.bounding_box }.flatten
	end
end

class Instance
  include Selectable
  @@highest_id ||= 0
  @@used_ids = []
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




