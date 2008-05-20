#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

                  
class ComponentBrowser
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "../data/glade/component_browser.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  #XXX this allows only selection of instances in project, not parts
	  @parts = {}
    @thumbs = @manager.all_parts.map do |part| 
      im = @manager.glview.image_of part
      if im 
        gtkim = native2gtk(im)
        @parts[gtkim] = part
        gtkim
      else
        nil 
      end
    end.compact
    @table = @glade['table']
    @glade['combo'].active = 0
  end
  
  def combo_changed
    rebuild
  end
  
	def insert part
	  close
    @manager.new_instance part
	end
	
	def rebuild
	  thumbs_per_row = (@glade['viewport'].allocation.width / ($preferences[:thumb_res] * 1.8)).to_i
	  num_rows = (@thumbs.size.to_f / thumbs_per_row).ceil    
	  buttons = @thumbs.map do |t| 
	    t.parent.remove t if t.parent
	    b = Gtk::Button.new
	    vbox = Gtk::VBox.new
	    vbox.add t
	    vbox.add Gtk::Label.new(@parts[t].name.ljust 17)
	    b.add vbox
	    b.signal_connect("clicked"){ insert @parts[t] }
	    b
    end
    vbox = Gtk::VBox.new
	 	num_rows.times do |y|
	 	    hbox = Gtk::HBox.new
	 	    vbox.pack_start( hbox, false )
  			for x in (0...thumbs_per_row)
  				b = buttons.pop
  				hbox.pack_start( (b ? b : Gtk::Label.new("")), false )
  			end
  	end
  	@glade['viewport'].remove @old_vbox if @old_vbox
  	@glade['viewport'].add vbox
  	@old_vbox = vbox
  	@glade['component_browser'].show_all
	end
	
  def close w=nil
    @glade['component_browser'].destroy
  end
end

def native2gtk im
	im.save "tmp/tmp.png"
	return Gtk::Image.new( "tmp/tmp.png" )
end
                  
