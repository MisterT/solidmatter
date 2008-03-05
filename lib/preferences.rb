#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


Bookmark = Struct.new( :adress, :port, :login, :password )

$preferences = { 
	:bookmarks => [ Bookmark.new( 'localhost', 2222, 'synthetic', 'bla' ) ],
	:anti_aliasing => false,
	:stencil_transparency => false
}
                  
class PreferencesDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/preferences.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def close w 
    @glade['preferences'].destroy
  end
  
  def preference_changed w
		$preferences[:anti_aliasing] = @glade['antialiasing_check'].active?
		$preferences[:stencil_transparency] = @glade['stencil_check'].active?
		$preferences[:manage_gc] = @glade['gc_check'].active?
		@manager.glview.render_style :regular
		@manager.glview.redraw
  end
end
                  
