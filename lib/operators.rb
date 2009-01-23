#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'geometry.rb'
require 'vector.rb'
require 'widgets.rb'
require 'components.rb'

class ExtrudeOperator < Operator
  def initialize part
    @name = "extrusion"
    @settings = {}
    @settings[:depth] = 0.2
    @settings[:type] = :add
    @settings[:direction] = :up
    super
  end
  
  def real_operate
    @new_faces = []
    segments = @settings[:segments]
    if segments and @solid
      # take the most appropriate chain from the sketch
      sketch = segments.first.sketch
      segments = sketch.all_chains.select{|ch| segments.any?{|s| ch.include? s } }.first
      if not segments
        @solid = nil
        return []
      end
      @settings[:segments] = segments
      # create face in extrusion direction for every segment
      direction = segments.first.sketch.plane.normal_vector * @settings[:depth] * (@settings[:direction] == :up ? 1 : -1)
      # make sure we are in part coordinate space
      sketch = segments.first.sketch
      origin = sketch.plane.origin
      segments.each do |seg|
        case seg
        when Line
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
        when Arc
          face = CircularFace.new( direction, seg.radius, seg.center + origin, @settings[:depth], seg.start_angle, seg.end_angle )
        end
        @solid.add_face face
        @new_faces << face
      end
      # build caps
      segments = segments.map{|s| s.dup }.flatten
      #segments = segments.map{|s| s.tesselate }.flatten
      lower_cap = PlanarFace.new
      lower_cap.plane.u_vec = sketch.plane.u_vec
      lower_cap.plane.v_vec = sketch.plane.v_vec
      lower_cap.segments = segments.map{|s| s + origin } #Line.new(s.pos1 + origin, s.pos2 + origin) }
      lower_cap.plane.origin = origin.dup #lower_cap.segments.first.snap_points.first.dup
      @solid.add_face lower_cap
      @new_faces << lower_cap
      upper_cap = PlanarFace.new
      upper_cap.plane.u_vec = sketch.plane.u_vec.invert
      upper_cap.plane.v_vec = sketch.plane.v_vec
      upper_cap.segments = segments.map{|s| s + (origin + direction) } #Line.new(s.pos1 + origin + direction, s.pos2 + origin + direction) }
      upper_cap.plane.origin = origin + direction #upper_cap.segments.first.snap_points.first.dup
      @solid.add_face upper_cap
      @new_faces << upper_cap
    end
    return @new_faces
  end
  
  def fill_toolbar bar
    # sketch selection
    sketch_button = Gtk::ToggleToolButton.new
    sketch_button.icon_widget = Gtk::Image.new('../data/icons/middle/sketch_middle.png').show
    sketch_button.label = GetText._("Sketch")
    sketch_button.signal_connect("clicked") do |b| 
      if sketch_button.active?
        $manager.activate_tool("region_select", true) do |segments|
          if segments
            @settings[:segments] = segments
            sketch = segments.first.sketch
            if @settings[:sketch]
              @part.unused_sketches.push @settings[:sketch]
              @settings[:sketch].op = nil
            end
            @settings[:sketch] = sketch
            sketch.op = self
            @part.unused_sketches.delete sketch
            $manager.op_view.update
            show_changes
          end
          sketch_button.active = false
        end
      end
    end
    bar.append( sketch_button )
    bar.append( Gtk::SeparatorToolItem.new )
    # type button
    type_button = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/tools.png'), GetText._("Type") )
    bar.append( type_button )
    type_button.signal_connect("clicked") do |b| 
      if @settings[:type] == :add
        @settings[:type] = :subtract
        type_button.icon_widget = Gtk::Image.new('../data/icons/zoom.png').show
      elsif @settings[:type] == :subtract
        @settings[:type] = :add
        type_button.icon_widget = Gtk::Image.new('../data/icons/return.png').show
      end
      show_changes
    end
    # direction button
    direction_button = Gtk::ToolButton.new( Gtk::Image.new('../data/icons/up.png'), GetText._("Direction") )
    bar.append( direction_button )
    direction_button.signal_connect("clicked") do |b| 
      if @settings[:direction] == :up
        @settings[:direction] = :down
        direction_button.icon_widget = Gtk::Image.new('../data/icons/down.png').show
      elsif @settings[:direction] == :down
        @settings[:direction] = :up
        direction_button.icon_widget = Gtk::Image.new('../data/icons/up.png').show
      end
      show_changes
    end
    bar.append( Gtk::SeparatorToolItem.new )
    # extrusion limit selection
    vbox = Gtk::VBox.new 
    mode_combo = Gtk::ComboBox.new
    mode_combo.focus_on_click = false
    mode_combo.append_text GetText._("Constant depth")
    mode_combo.append_text GetText._("Up to selection")
    mode_combo.active = 0
    vbox.pack_start( mode_combo, true, false )
    vbox.add Gtk::Label.new GetText._("Extrusion limit")
    bar.append( vbox )
    bar.append( Gtk::SeparatorToolItem.new )
    # constant depth
    entry = MeasureEntry.new GetText._("Depth")
    entry.value = @settings[:depth]
    entry.on_change_value{|val| @settings[:depth] = val; show_changes}
    bar.append entry
  end
end


Force = Struct.new( :faces, :magnitude, :plane )

class FEMOperator < Operator
  def initialize part
    @name = "FEM"
    @settings = {}
    @settings[:fixed] = []
    @settings[:forces] = []
    @settings[:show_tension] = true
    @settings[:show_deformation] = true
    super
  end
  
  def real_operate
    []
  end
  
  def fill_toolbar bar
    glade = GladeXML.new( "../data/glade/fem_toolbar.glade", nil, 'solidmatter' ) {|handler| method(handler)}
    glade['hbox'].parent.remove glade['hbox']
    bar.append glade['hbox']
    # fixed faces selection
    glade['fixed_toggle'].signal_connect("clicked") do |b| 
      if glade['fixed_toggle'].active?
        $manager.activate_tool("face_select", true) do |faces|
          @settings[:fixed] = faces if faces
          glade['fixed_toggle'].active = false
        end
      end
    end
    # add force
    glade['force_combo'].remove_text 0
    glade['add_force_btn'].signal_connect("clicked") do |b|
      @settings[:forces] << Force.new( [], 1, nil )
      glade['force_combo'].append_text GetText._("Force #{@settings[:forces].size}")
      glade['force_combo'].active = @settings[:forces].size - 1
      glade['remove_force_btn'].sensitive = true
    end
    # remove force
    glade['remove_force_btn'].signal_connect("clicked") do |b|
      combo = glade['force_combo'] ; i = glade['force_combo'].active
      @settings[:forces].delete_at i
      combo.remove_text i
      combo.active = [i, i - 1].find{|e| (-1...@settings[:forces].size).include? e } 
      glade['remove_force_btn'].sensitive = false if @settings[:forces].empty?
    end
  end
  
  def draw_gl_interface
    super
  end
end




