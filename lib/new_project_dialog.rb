#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class NewProjectDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/new_project.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def ok_handle( w )
    @glade['new_project'].destroy
	  @manager.new_project{ @manager.make_project_public if @choice == 'multi_radio' }
  end
  
  def cancel_handle( w )
    @glade['new_project'].destroy
  end
  
  def radio_changed( w )
    @choice = w.name if w.active?
  end
end