#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-05.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class ProjectInformationDialog
	def initialize manager 
    @manager = manager
	  @glade = GladeXML.new( "../data/glade/project_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @glade['name_entry'].text   = @manager.name  
	  @glade['author_entry'].text = @manager.author
  end
  
  def ok_handle( w )
    @manager.name   = @glade['name_entry'].text    
    @manager.author = @glade['author_entry'].text  
    @manager.server_win.update if @manager.server_win
    @manager.correct_title
    @manager.has_been_changed = true
    @glade['project_dialog'].destroy
  end
end