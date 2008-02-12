#!/usr/local/bin/ruby -w
#########################################################################################
### widgets.rb                     - additional Gtk widgets                           ###
#########################################################################################
### creation date: 08.03.04  by Björn Breitgoff                                       ###
### last changed : 08.03.04  by Björn Breitgoff                                       ###
#########################################################################################
require 'gnome2'

class SearchEntry < Gtk::VBox 
	def initialize( manager )
		super( false )
		@manager = manager
		@entry = Gnome::Entry.new
		@label = Gtk::Label.new("Search") 
		self.pack_start( @entry )
		self.pack_start( @label)
		@entry.signal_connect("changed"){|w| select_matching_objects( w.gtk_entry.text ) }
	end
	
	def icon_mode
		@label.hide
	end
	
	def full_mode
		@label.show
	end
	alias text_mode full_mode
	
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
  		@manager.glview.redraw
	  end
	end
end

class MeasureEntry < Gtk::VBox
	def initialize( label )
		super false
		@entry = Gtk::SpinButton.new( 0, 10, 0.05 )
		@btn = Gtk::Button.new
		@btn.image = Gtk::Image.new('icons/small/preferences-system_small.png')
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
		[Gtk::MenuItem.new("Measure value"),
		 Gtk::MenuItem.new("Bind to measured value")
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





