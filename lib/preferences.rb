#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


Bookmark = Struct.new( :adress, :port, :login, :password )

$preferences = { 
	:bookmarks => [ Bookmark.new( 'localhost', 2222, 'synthetic', 'bla' ) ],
	:anti_aliasing => false,
	:stencil_transparency => true,
	:manage_gc => true,
	:first_light_position => [0.5, 1.0, 1.0, 0.0],
	:second_light_position => [-0.8, -0.8, 0.35, 0.0],
	:first_light_color => [0.5, 0.5, 1.0, 0.0],
	:second_light_color => [1.0, 0.7, 0.5, 0.0],
	:view_transitions => true,
	:transition_duration => 60
}
                  
class PreferencesDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/preferences.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
	  @react_to_changes = false
	  @glade['antialiasing_check'].active=	$preferences[:anti_aliasing]
		@glade['stencil_check'].active= $preferences[:stencil_transparency]
		@glade['gc_check'].active = $preferences[:manage_gc]
		@glade['transition_check'].active = $preferences[:view_transitions]
		@glade['transition_scale'].value = $preferences[:transition_duration] / 10.0
		@react_to_changes = true
  end
  
  def close w 
    @glade['preferences'].destroy
  end
  
  def preference_changed w
  	if @react_to_changes
			$preferences[:anti_aliasing] = @glade['antialiasing_check'].active?
			$preferences[:stencil_transparency] = @glade['stencil_check'].active?
			$preferences[:manage_gc] = @glade['gc_check'].active?
			$preferences[:view_transitions] = @glade['transition_check'].active?
			$preferences[:transition_duration] = @glade['transition_scale'].value * 10
			@manager.glview.realize
			@manager.glview.redraw
		end
  end
end
                  
