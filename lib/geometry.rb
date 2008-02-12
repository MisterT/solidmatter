#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'gtkglext'
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
	attr_reader :plane, :displaylist, :pick_displaylist, :parent
	attr_accessor :size, :spacing, :visible, :glview
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
	
	def animate
		0.step(@size, 0.1) do |i|
			@size = i
			build_displaylist
			@glview.redraw
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
			GL.Begin( GL::LINES )
				col = [0,0,0]
				@verticals.each do |line| 
					GL.Color3f( col[0], col[1], col[2] )
					GL.Vertex( line.pos1.x, line.pos1.y, line.pos1.z )
					GL.Vertex( line.pos2.x, line.pos2.y, line.pos2.z )
					col.map!{|c| c + 0.05 }
				end
				col = [0,0,0]
				@horizontals.each do |line| 
					GL.Color3f( col[0], col[1], col[2] )
					GL.Vertex( line.pos1.x, line.pos1.y, line.pos1.z )
					GL.Vertex( line.pos2.x, line.pos2.y, line.pos2.z )
					col.map!{|c| c + 0.05 }
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
	end
end


class Sketch
	attr_accessor :name, :parent, :op, :selection_pass, :visible, :selected, :glview
	attr_reader :plane, :displaylist, :segments
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
	
	def chain( segment )
		chain = [segment]
		last_seg = segment
		pos = segment.pos2
		changed = true
		runs = 0
		while (not pos == segment.pos1) and changed and runs <= @segments.size
		  runs += 1
			changed = false
			for seg in @segments
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
	end
end


class Face
  include Selectable
	attr_accessor :bound_segments
	def initialize
		@bound_segments = []
		@selection_pass_color = [1.0, 1.0, 1.0]
	end
end

class PlanarFace < Face
	attr_reader :plane
	def initialize
		@plane = Plane.new
	end
end

class CircularFace < Face
	def initialize
		@axis = Line.new
	end
end


class Solid
	attr_reader :faces
	def initialize
		@faces = []
	end
	
	def add_face f
	  f.solid = self
	  @faces.push f
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
		@solid = @previous ? Marshal.load(Marshal.dump(@previous.solid)) : Solid.new
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
	attr_reader :information
	def name
	  information[:name]
	end
	
	def clean_up
	  GL.DeleteLists( @displaylist, 1 )
	  GL.DeleteLists( @wire_displaylist, 1 )
	end
end


class Part < Component
  attr_accessor :manager
	attr_reader :component_id, :operators, :working_planes, :displaylist, :wire_displaylist, :unused_sketches, :solid
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

	def build( from_op )
		@operators.index( from_op ).upto( @history_limit - 1 ){|i| @operators[i].operate; yield if block_given? } # update progressbar
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

	def build_displaylist( type=:normal)
		# generate mesh and write to displaylist
	  GL.NewList( @displaylist, GL::COMPILE)
	    # draw shaded faces
		  @solid.faces.each do |face|
			  normal = face.plane.normal_vector
			  GL.Normal( -normal.x, -normal.y, -normal.z )
			  #col = @information[:material].color
			  #GL.Color4f(col[0], col[1], col[2], @information[:material].opacity)
			  c = face.selection_pass_color
			  GL.Color3f( c[0],c[1],c[2] ) if type == :select_faces
				GL.Begin( GL::POLYGON )
				face.bound_segments.each do |seg|
          #GL.TexCoord2f(0.995, 0.005)
					GL.Vertex( seg.pos1.x, seg.pos1.y, seg.pos1.z )
				end
				GL.End
			end
		GL.EndList
		build_wire_displaylist
	end
	
	def build_wire_displaylist
	  GL.NewList( @wire_displaylist, GL::COMPILE)
  		all_segs = @solid.faces.map{|face| face.bound_segments }.flatten
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
	
	def display_contact_set
		dia = Gtk::Dialog.new( "Contact set for #{@name}",
					nil,
					Gtk::Dialog::DESTROY_WITH_PARENT,
					[Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK]
		)
		dia.resizable = false
		# partlist
		listframe =  Gtk::Frame.new( 'Participating parts' )
		listframe.border_width = 3
		dia.vbox.add( listframe )
		hbox = Gtk::HBox.new(false)
		sw = Gtk::ScrolledWindow.new
		listview = Gtk::TreeView.new
		model = Gtk::ListStore.new( Gdk::Pixbuf, String )
		listframe.add( hbox )
		hbox.add( sw )
		sw.add( listview )
		sw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
		sw.set_size_request(200, 300)
		vbox = Gtk::VBox.new(false) 
		hbox.add( vbox )
		vbox.add( Gtk::Button.new("Add") )
		vbox.add( Gtk::Button.new("Remove") )
		vbox.add( Gtk::Button.new("Enabled") )
		# simulation options
		optionframe =  Gtk::Frame.new( 'Simulation options' )
		optionframe.border_width = 3
		dia.vbox.add( optionframe )
		vbox = Gtk::VBox.new(true)
		optionframe.add( vbox )
		# resolution
		hbox = Gtk::HBox.new(true)
		hbox.add( Gtk::Label.new("Samples per unit:") )
	        adjustment = Gtk::Adjustment.new( 5,          # initial
                                      		  1,          # min
                                        	  21,         # max
                                        	  1,          # step_inc (unused)
                                        	  1,          # page_inc (unused)
                                        	  1           # page_size (unused)
		)          
		sample_scale = Gtk::HScale.new( adjustment )
		hbox.add( sample_scale )
		sample_scale.signal_connect('value_changed') {  }
		vbox.add( hbox )
		# friction
		hbox = Gtk::HBox.new(true)
		hbox.add( Gtk::Label.new("Friction:") )
		#hbox.add( Gtk::CheckBox.new )
		hbox.add( Gtk::HScale.new )
		vbox.add( hbox )
		# resolution
		hbox = Gtk::HBox.new(true)
		hbox.add( Gtk::Label.new("Use bounding box:") )
		hbox.add( Gtk::HScale.new )
		vbox.add( hbox )
		# get response from dialog
		dia.signal_connect('response') do |w, r|
			case r
				when Gtk::Dialog::RESPONSE_OK
					dia.destroy
			end
		end
		dia.show_all
	end
end

class Instance
  include Selectable
  @@highest_id ||= 0
	attr_reader :parent, :position, :transparent, :component_id
	attr_accessor :visible, :real_component
	def initialize

	end
	def initialize( component, parent=nil )
		raise "Parts must have a parent" if component.class == Part and not parent
		@real_component = component
		@position = Vector[0,0,0]
		@parent = parent
		@transparent = false
		@visible = true
		@selection_pass_color = [1.0, 1.0, 1.0]
		@component_id = @@highest_id
		@@highest_id += 1
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




