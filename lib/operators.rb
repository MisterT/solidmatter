#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'lib/geometry.rb'
require 'lib/vector.rb'
require 'lib/widgets.rb'

class ExtrudeOperator < Operator
	def initialize( part, manager )
		@name = "extrusion"
		@settings = {}
		@settings[:depth] = 0.2
		@settings[:type] = :add
		@settings[:direction] = :up
		super
	end
	
	def real_operate
	  segments = @settings[:segments]
		if segments
			# create face in extrusion direction for every segment
			direction = segments.first.sketch.plane.normal_vector * @settings[:depth] * (@settings[:direction] == :up ? 1 : -1)
			# make sure we are in part coordinate space
			origin = segments.first.sketch.plane.origin
			segments.each do |seg|
				corner1 = seg.pos1 + origin
				corner2 = seg.pos1 + direction + origin
				corner3 = seg.pos2 + direction + origin
				corner4 = seg.pos2 + origin
				segs = [ Line.new( corner1, corner2 ),
				         Line.new( corner2, corner3 ),
				         Line.new( corner3, corner4 ),
				         Line.new( corner4, corner1 ) ]
				face = PlanarFace.new
				face.segments = segs
				face.plane.u_vec = corner1.vector_to( corner2 ).normalize
				face.plane.v_vec = corner1.vector_to( corner4 ).normalize
				face.plane.origin = corner1
				@solid.faces.push( face )
			end
			# build caps
			lower_cap = PlanarFace.new
			lower_cap.segments = segments
			lower_cap.plane.u_vec = segments.first.sketch.plane.u_vec
			lower_cap.plane.v_vec = segments.first.sketch.plane.v_vec
			lower_cap.plane.origin = segments[0].pos1 + origin
			@solid.faces.push( lower_cap )
			upper_cap = PlanarFace.new
			upper_cap.segments = segments.map{|s| se = s.dup; [se.pos1, se.pos2].each{|p| p.add direction } ; se }
			upper_cap.plane.u_vec = segments.first.sketch.plane.u_vec.invert
			upper_cap.plane.v_vec = segments.first.sketch.plane.v_vec
			upper_cap.plane.origin = segments[0].pos1 + origin + direction
			@solid.faces.push( upper_cap )
		end
	end
	
	def fill_toolbar 
		# sketch selection
		sketch_button = Gtk::ToggleToolButton.new
		sketch_button.icon_widget = Gtk::Image.new('icons/middle/sketch_middle.png').show
		sketch_button.label = "Sketch"
		sketch_button.signal_connect("clicked") do |b| 
		  if sketch_button.active?
  			@manager.activate_tool("region_select", true) do |segments|
  			  if segments
    				@settings[:segments] = segments
    				sketch = segments.first.sketch
    				@settings[:sketch] = sketch
    				sketch.op = self
    				@part.unused_sketches.delete sketch
    				@manager.op_view.update
    				show_changes
  			  end
  			  sketch_button.active = false
  			end
			end
		end
		@toolbar.append( sketch_button )
		@toolbar.append( Gtk::SeparatorToolItem.new )
		# type button
		type_button = Gtk::ToolButton.new( Gtk::Image.new('icons/tools.png'), "Type" )
		@toolbar.append( type_button )
		type_button.signal_connect("clicked") do |b| 
			if @settings[:type] == :add
				@settings[:type] = :subtract
				type_button.icon_widget = Gtk::Image.new('icons/zoom.png').show
			elsif @settings[:type] == :subtract
				@settings[:type] = :add
				type_button.icon_widget = Gtk::Image.new('icons/return.png').show
			end
			show_changes
		end
		# direction button
		direction_button = Gtk::ToolButton.new( Gtk::Image.new('icons/up.png'), "Direction" )
		@toolbar.append( direction_button )
		direction_button.signal_connect("clicked") do |b| 
			if @settings[:direction] == :up
				@settings[:direction] = :down
				direction_button.icon_widget = Gtk::Image.new('icons/down.png').show
			elsif @settings[:direction] == :down
				@settings[:direction] = :up
				direction_button.icon_widget = Gtk::Image.new('icons/up.png').show
			end
			show_changes
		end
		@toolbar.append( Gtk::SeparatorToolItem.new )
		# extrusion limit selection
		vbox = Gtk::VBox.new 
		mode_combo = Gtk::ComboBox.new
		mode_combo.focus_on_click = false
		mode_combo.append_text "Constant depth"
		mode_combo.append_text "Up to selection"
		mode_combo.active = 0
		vbox.pack_start( mode_combo, true, false )
		vbox.add Gtk::Label.new "Extrusion limit"
		@toolbar.append( vbox )
		@toolbar.append( Gtk::SeparatorToolItem.new )
		# constant depth
		entry = MeasureEntry.new "Depth"
		entry.value = @settings[:depth]
		entry.on_change_value{|val| @settings[:depth] = val; show_changes}
		@toolbar.append entry
	end
	
	def draw_gl_interface
		
	end
end







