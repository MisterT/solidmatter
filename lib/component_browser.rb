#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

class String
  def shorten length
    size > length ? self[0...(length-3)] + "..." : self
  end
end
                  
class ComponentBrowser
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "../data/glade/component_browser.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @parts = {}
    # generate Radiobuttons for thumbnails
    @btn_width = $preferences[:thumb_res] + 65.0
    @old_width = nil
    build_buttons
    @table = @glade['table']
    @glade['combo'].active = 0
    @timeout = Gtk.timeout_add(1000){ rebuild ; true }
    @glade['component_browser'].signal_connect("destroy"){ Gtk.timeout_remove @timeout }
  end
  
  def build_buttons( regen_thumbs=false )
	  # generate Gtk::Images for all parts
    @thumbs = @manager.all_parts.dup.map do |part|
    	im = (regen_thumbs or not part.thumbnail) ? @manager.glview.image_of_parts( part ) : part.thumbnail
    	part.thumbnail = im
      gtkim = native2gtk(im)
      @parts[gtkim] = part
      gtkim
    end
	  prev_btn = nil    
	  @buttons = @thumbs.map do |t| 
	    b = prev_btn ? Gtk::RadioButton.new( prev_btn ) : Gtk::RadioButton.new
	    prev_btn = b
	    vbox = Gtk::VBox.new
	    t.parent.remove t if t.parent
	    vbox.add t
	    name = @parts[t].name
	    vbox.add Gtk::Label.new(name.shorten 13)
	    b.add vbox
	    b.set_size_request( @btn_width, 110 )
	    b.draw_indicator = true
	    @parts[b] = @parts[t]
	    b
    end
    rebuild
  end
  
  def combo_changed
    rebuild
  end
  
  def update_thumbs
  	build_buttons true
  end
  
  def add_selected
  	btn = @buttons.select{|b| b.active? }.first
  	insert @parts[btn] if btn
  end
  
  def remove_selected
  	btn = @buttons.select{|b| b.active? }.first
  	@manager.delete_object @parts[btn] if btn
  	build_buttons
  end
  
	def insert part
	  close
    @manager.new_instance part
	end
	
	def rebuild
	  width = @glade['viewport'].allocation.width
	  if width != @old_width
  	  @old_width = width
  	  thumbs_per_row = (width / @btn_width).to_i
  	  num_rows = (@thumbs.size.to_f / thumbs_per_row).ceil
  	  buttons = @buttons.dup
      vbox = Gtk::VBox.new
  	 	num_rows.times do |y|
   	    hbox = Gtk::HBox.new
   	    vbox.pack_start( hbox, false )
  			for x in (0...thumbs_per_row)
  				b = buttons.pop
  			 	b.parent.remove b if b and b.parent
  				hbox.pack_start( (b ? b : Gtk::Label.new("")), false )
  			end
    	end
    	@glade['viewport'].remove @old_vbox if @old_vbox
    	@glade['viewport'].add vbox
    	@old_vbox = vbox
    	@glade['component_browser'].show_all
  	end
	end
	
  def close w=nil
    @glade['component_browser'].destroy
  end
end

def native2gtk im
	im.save "tmp/tmp.png"
	return Gtk::Image.new( "tmp/tmp.png" )
end
                  
