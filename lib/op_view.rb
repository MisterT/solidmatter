#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'operators.rb'
require 'pop_ups.rb'

def icon_for_op( op )
	klass = op.class
	case klass
		when ExtrudeOperator then return  '../data/icons/extrude.png'
	end
	return nil
end

class OpView < Gtk::ScrolledWindow
	attr_accessor :manager, :base_component
	def initialize
		super
		@manager = nil
		@base_component = nil
		self.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
		# set up view
		pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		@column = Gtk::TreeViewColumn.new(GetText._('Operators'))
		@column.reorderable = true
		@column.pack_start(pix,false)
		@column.set_cell_data_func(pix) do |column, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		@column.pack_start(text, true)
		@column.set_cell_data_func(text) do |column, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@tv = Gtk::TreeView.new
		@tv.reorderable = true
		#@tv.hover_selection = true
		@tv.append_column( @column )
		@tv.set_size_request(100,0)
		self.add( @tv )
		# define pop-up menus
		@tv.signal_connect("button_press_event") do |widget, event|
		  # right click
			if event.button == 3 
			  @tv.event(Gdk::EventButton.new(Gdk::Event::BUTTON_PRESS)) # XXX
			  sel = self.selections[0]
			  menu = case sel
		    when Operator
		      OperatorMenu.new(@manager, sel)
	      when Instance
	        ComponentMenu.new(@manager, sel, :op_view)
        when Sketch
          SketchMenu.new(@manager, sel)
		    end
			  menu.popup(nil, nil, event.button, event.time) if menu
			end
		end
	   @tv.signal_connect('row_activated') do 
	   	sel = self.selections[0]
	   	@manager.exit_current_mode
	   	if sel.is_a? Sketch
	   		@manager.sketch_mode sel 
	   	elsif sel.is_a? Operator
	   		@manager.operator_mode sel
	   	else
	   		@manager.change_working_level sel 
	   	end
	   end
	end
	
	def selections
		sels = []
		@tv.selection.selected_each do |model, path, iter|
			# dive down hierarchy to real selection
			comps = [@base_component]
			sel = nil
			path.indices.each do |i|
				sel = comps[i]
				comps = sel.components if sel.class == Assembly
				comps = (sel.operators + sel.unused_sketches) if sel.class == Part
				comps = [sel.settings[:sketch]] if sel.is_a? Operator and sel.settings[:sketch]
			end
			sels.push( sel )
		end
		return sels
	end

	def update
		if @base_component
			if @base_component.class == Part
				@column.title = GetText._('Operators')
				model = Gtk::TreeStore.new(Gdk::Pixbuf, String)
				base_iter = model.append(nil)
				base_iter[0] = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
				base_iter[1] = @base_component.information[:name]
				@base_component.operators.each do |op|
					op_iter = model.append( base_iter )
					op_iter[0] = Gtk::Image.new('../data/icons/small/wheel_small.png').pixbuf
					op_iter[1] = op.name
					sketch = op.settings[:sketch]
					if sketch
					  sketch_iter = model.append op_iter
					  sketch_iter[0] = Gtk::Image.new('../data/icons/small/sketch_small.png').pixbuf
					  sketch_iter[1] = sketch.name
				  end
				#	sketch_iter[0] = render_icon(Gtk::Stock::NEW, Gtk::IconSize::MENU, "icon1")
				end
				@base_component.unused_sketches.each do |sketch|
					sketch_iter = model.append( base_iter )
					sketch_iter[0] = Gtk::Image.new('../data/icons/small/sketch_small.png').pixbuf
					sketch_iter[1] = sketch.name
				end
				@tv.model = model
				@tv.expand_all
			elsif @base_component.class == Assembly
				# recursively visualize assemblies
				@column.title = 'Parts'
				model = Gtk::TreeStore.new(Gdk::Pixbuf, String)
				base_iter = model.append(nil)
				base_iter[0] = Gtk::Image.new('../data/icons/small/assembly_small.png').pixbuf
				base_iter[1] = @base_component.information[:name]
				recurse_visualize( model, base_iter, @base_component.components )
				@tv.model = model
				@tv.expand_all
			end
		end
	end
	
	def recurse_visualize( model, base_iter, comps )
		comps.each do |comp|
			iter = model.append( base_iter )
			if comp.class == Assembly
				iter[0] = Gtk::Image.new('../data/icons/small/assembly_small.png').pixbuf
				iter[1] = comp.information[:name]
				recurse_visualize( model, iter, comp.components )
			else
				iter[0] = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
				iter[1] = comp.information[:name]
			end
		end
	end
	
	def set_base_component( comp )
		@base_component = comp
		update
	end
end












