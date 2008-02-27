#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'lib/join_project_dialog.rb'


class OpenProjectDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/open_project.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def ok_handle( w )
    @glade['open_project'].destroy
    @manager.open_file if @choice == 'local_radio'
    JoinProjectDialog.new @manager if @choice == 'multi_radio'
  end
  
  def cancel_handle( w )
    @glade['open_project'].destroy
  end
  
  def radio_changed( w )
    @choice = w.name if w.active?
  end
end