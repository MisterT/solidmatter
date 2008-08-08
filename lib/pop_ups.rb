#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.


class BackgroundMenu < Gtk::Menu
  def initialize manager
    super()
    items = [
			Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(GetText._("_Return")).set_image( Gtk::Image.new(Gtk::Stock::UNDO, Gtk::IconSize::MENU) )
		]
		items[0].sensitive = manager.clipboard ? true : false
		items[2].sensitive = (manager.work_sketch or 
												 manager.work_operator or 
												 manager.work_component != manager.main_assembly) ? true : false
		# paste
		items[0].signal_connect("activate") do
			manager.paste_from_clipboard
		end
		# return
		items[2].signal_connect("activate") do
			manager.working_level_up
		end
		items.each{|i| append i }
		show_all
  end
end


class ComponentMenu < Gtk::Menu
  def initialize( manager, part, location )
    super()
    items = [
			Gtk::MenuItem.new( GetText._("Duplicate instance")),
			Gtk::MenuItem.new( GetText._("Duplicate original")),
			Gtk::ImageMenuItem.new(Gtk::Stock::CUT),
			Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
			Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE),
			Gtk::SeparatorMenuItem.new,
			Gtk::CheckMenuItem.new( GetText._("Visible")),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::PROPERTIES)
		]
		items[4].sensitive = manager.clipboard ? true : false
		items[7].active = part.visible
		# duplicate instance
		items[0].signal_connect("activate") do
      manager.duplicate_instance
		end
		# duplicate original
		items[1].signal_connect("activate") do
      # dupli orig
		end
		# cut
		items[3].signal_connect("activate") do
			manager.cut_to_clipboard
		end
		# copy
		items[3].signal_connect("activate") do
			manager.copy_to_clipboard
		end
		# paste
		items[4].signal_connect("activate") do
			manager.paste_from_clipboard
		end
		# delete
		items[5].signal_connect("activate") do
			manager.delete_op_view_selected if location == :op_view
			manager.delete_selected 				if location == :glview
		end
		# visible
		items[7].signal_connect("activate") do
      part.visible = items[7].active?
      manager.glview.redraw
		end
		# properties
		items[9].signal_connect("activate") do
			part.display_properties
		end
		items.each{|i| append i }
		show_all
  end
end

class OperatorMenu < Gtk::Menu
  def initialize( manager, operator )
    super()
    items = [
			Gtk::MenuItem.new( GetText._("Edit dimensions")),
			Gtk::ImageMenuItem.new(GetText._("Edit operator")).set_image( Gtk::Image.new('../data/icons/small/wheel_small.png') ),
			Gtk::ImageMenuItem.new(GetText._("Edit sketch")).set_image( Gtk::Image.new('../data/icons/small/sketch_small.png') ),
			Gtk::SeparatorMenuItem.new,
			Gtk::CheckMenuItem.new( GetText._("Enabled")),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
		]
		# edit dimensions
		items[0].signal_connect("activate") do
		  sk = operator.settings[:sketch]
		  dims = (operator.dimensions + (sk ? sk.dimensions : [])).flatten
		  dims.each{|d| d.visible = true }
		  $manager.glview.redraw
		end
		# edit operators
		items[1].signal_connect("activate") do
		  $manager.exit_current_mode
      $manager.operator_mode operator
		end
		# edit sketch
		items[2].signal_connect("activate") do
		  sk = operator.settings[:sketch]
		  $manager.exit_current_mode
      $manager.sketch_mode sk
		end
		# enable/disable
		items[4].active = operator.enabled
		items[4].signal_connect("activate") do
      manager.enable_operator operator
		end
		# delete
		items[5].signal_connect("activate") do
      manager.delete_object operator
		end
		items.each{|i| append i }
		show_all
  end
end


class OpViewOperatorMenu < Gtk::Menu
  def initialize( manager, operator )
    super()
    items = [
			Gtk::MenuItem.new( GetText._("Edit dimensions")),
			Gtk::ImageMenuItem.new(GetText._("Edit operator")).set_image( Gtk::Image.new('../data/icons/small/wheel_small.png') ),
			Gtk::ImageMenuItem.new(GetText._("Edit sketch")).set_image( Gtk::Image.new('../data/icons/small/sketch_small.png') ),
			Gtk::SeparatorMenuItem.new,
			Gtk::CheckMenuItem.new( GetText._("Enabled")),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
		]
		# edit dimensions
		items[0].signal_connect("activate") do
		  operator.show_dimensions
		end
		# edit operators
		items[1].signal_connect("activate") do
		  $manager.exit_current_mode
      $manager.operator_mode operator
		end
		# edit sketch
		items[2].signal_connect("activate") do
		  sk = operator.settings[:sketch]
		  $manager.exit_current_mode
      $manager.sketch_mode sk
		end
		# enable/disable
		items[4].active = operator.enabled
		items[4].signal_connect("activate") do
      manager.enable_selected_operator
		end
		# delete
		items[5].signal_connect("activate") do
      manager.delete_op_view_selected
		end
		items.each{|i| append i }
		show_all
  end
end


class SketchMenu < Gtk::Menu
  def initialize( manager, sketch )
    super()
    items = [
			Gtk::MenuItem.new( GetText._("Duplicate sketch")),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
		]
		# duplicate
		items[0].signal_connect("activate") do
		  manager.new_sketch sketch
		end
		# delete
		items[2].signal_connect("activate") do
      manager.delete_op_view_selected
		end
		items.each{|i| append i }
		show_all
  end
end

class SketchToolMenu < Gtk::Menu
  def initialize( manager, tool )
    super()
    items = [
			Gtk::CheckMenuItem.new( GetText._("Snap to points")),
			Gtk::CheckMenuItem.new( GetText._("Snap to grid")),
			Gtk::CheckMenuItem.new( GetText._("Use guides")),
			Gtk::CheckMenuItem.new( GetText._("Create reference geometry")),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::STOP)
		]
		items[0].active = manager.point_snap
		items[1].active = manager.grid_snap
		items[2].active = manager.use_sketch_guides
		items[3].active = tool.create_reference_geometry
		# snap points
		items[0].signal_connect("activate") do |w|
      manager.point_snap = w.active?
		end
		# snap grid
		items[1].signal_connect("activate") do |w|
      manager.grid_snap = w.active?
		end
		# guides
		items[2].signal_connect("activate") do |w|
			manager.use_sketch_guides = w.active?
		end
		# reference
		items[3].signal_connect("activate") do |w|
			tool.create_reference_geometry = w.active?
		end
		# stop
		items[5].signal_connect("activate") do |w|
      manager.cancel_current_tool
		end
		items.each{|i| append i }
		show_all
  end
end

class SketchSelectionToolMenu < Gtk::Menu
  def initialize manager
    super()
    items = [
			Gtk::CheckMenuItem.new( GetText._("Snap to points")),
			Gtk::CheckMenuItem.new( GetText._("Snap to grid")),
			Gtk::CheckMenuItem.new( GetText._("Use guides")),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::CUT),
			Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
			Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(GetText._("_Return")).set_image( Gtk::Image.new(Gtk::Stock::UNDO, Gtk::IconSize::MENU) )
		]
		items[0].active = manager.point_snap
		items[1].active = manager.grid_snap
		items[2].active = manager.use_sketch_guides
		items[4].sensitive = (not manager.selection.empty?)
		items[5].sensitive = (not manager.selection.empty?)
		items[6].sensitive = manager.clipboard ? true : false
		items[7].sensitive = manager.selection.empty? ? false : true
		items[9].sensitive = (manager.work_sketch or 
												  manager.work_operator or 
												  manager.work_component != manager.main_assembly) ? true : false
		# snap points
		items[0].signal_connect("activate") do |w|
      manager.point_snap = w.active?
		end
		# snap grid
		items[1].signal_connect("activate") do |w|
      manager.grid_snap = w.active?
		end
		# guides
		items[2].signal_connect("activate") do |w|
			manager.use_sketch_guides = w.active?
		end
		# cut
		items[4].signal_connect("activate") do |w|
      manager.cut_to_clipboard
		end
		# copy
		items[5].signal_connect("activate") do |w|
      manager.copy_to_clipboard
		end
		# paste
		items[6].signal_connect("activate") do |w|
      manager.paste_from_clipboard
		end
		# delete
		items[7].signal_connect("activate") do |w|
      manager.delete_selected
		end
		# return
		items[9].signal_connect("activate") do |w|
      manager.working_level_up
		end
		items.each{|i| append i }
		show_all
  end
end
