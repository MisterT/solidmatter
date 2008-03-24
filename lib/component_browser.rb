#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

                  
class ComponentBrowser
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/component_browser.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
    @thumbs = @manager.all_parts.map{|part| native2gtk( @manager.glview.image_of part ) }.compact
    @glade['table'].resize( (@thumbs.size / 4.0).ceil, 4 ) unless @thumbs.empty?
    @glade['combo'].active = 0
  end
  
  def combo_changed
  	table = @glade['table']
  	table.n_rows.times do |y|
  			for x in (0..3)
  				thumb = @thumbs.pop
  				table.attach( thumb, x, x+1, y, y+1, Gtk::SHRINK, Gtk::SHRINK) if thumb
  			end
  	end
  	@glade['component_browser'].show_all
  end
  
	def insert

	end
	
  def close w 
    @glade['component_browser'].destroy
  end
end

def native2gtk im
	im.save "tmp/tmp.png"
	return Gtk::Image.new( "tmp/tmp.png" )
end
                  
