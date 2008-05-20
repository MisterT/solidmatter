#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gnome2'

class SearchEntry < Gtk::ToolItem 
	def initialize( manager )
		super()
		no_show_all = true
		@manager = manager
		@icon = Gtk::Image.new( Gtk::Stock::FIND, Gtk::IconSize::SMALL_TOOLBAR )
		@entry = Gtk::ComboBoxEntry.new
		@label = Gtk::Label.new GetText._("Search") 
		entry_box = Gtk::HBox.new false
		entry_box.pack_start( @icon, false, false, 6 )
		entry_box.pack_start( @entry, false )
		vbox = Gtk::VBox.new false
		vbox.pack_start( entry_box, false, false, 3 )
		#vbox.pack_start( @label)
		add vbox
		set_mode
		@entry.signal_connect("changed"){|w| select_matching_objects( w.active_text ) }
		signal_connect("toolbar-reconfigured"){|w| set_mode }
	end
	
	def set_mode
		if [Gtk::Toolbar::BOTH_HORIZ, Gtk::Toolbar::ICONS, Gtk::Toolbar::TEXT].any?{|style| style == toolbar_style }
			@label.hide
		else
			@label.show
		end
	end
	
	def select_matching_objects( str )
	  str.downcase!
	  if @manager.work_component.class == Assembly
  		@manager.selection.deselect_all
  		unless str.empty?
  			comps_to_check = [@manager.work_component]
  			while not comps_to_check.empty?
  				new_comps = []
  				comps_to_check.each do |c|
  					@manager.selection.add c if c.information[:name].downcase.include? str
  					new_comps += c.components if c.class == Assembly
  				end
  				comps_to_check = new_comps
  			end
  		end
  		@manager.glview.zoom_selection
  		@manager.glview.redraw
	  end
	end
end

class MeasureEntry < Gtk::VBox
	def initialize( label )
		super false
		@entry = Gtk::SpinButton.new( 0, 10, 0.05 )
		@btn = Gtk::Button.new
		@btn.image = Gtk::Image.new('../data/icons/small/preferences-system_small.png')
		@btn.relief = Gtk::RELIEF_NONE
		@entry.set_size_request( 60, -1 )
		@btn.set_size_request( 30, 30 )
		hbox = Gtk::HBox.new
		add hbox
		hbox.add @entry
		hbox.add @btn
		@label = Gtk::Label.new label
		add @label
		# create popup menu
		menu = Gtk::Menu.new
		[Gtk::MenuItem.new(GetText._("Measure value")),
		 Gtk::MenuItem.new(GetText._("Bind to measured value"))
		].each{|i| menu.append(i)}
		menu.show_all
		@btn.signal_connect("button_press_event"){|w,e| menu.popup(nil, nil, 3, e.time)}
	end
	
	def value
	 @entry.value
	end
	
	def value=( val )
	 @entry.value = val
	end
	
	def on_change_value
	 @entry.signal_connect('value_changed'){|w| yield w.value }
	end
end





