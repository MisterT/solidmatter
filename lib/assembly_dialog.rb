#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-04.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class AssemblyInformationDialog
	def initialize( information, manager )
	  @info = information
    @manager = manager
	  @return_handler = Proc.new
	  @glade = GladeXML.new( "../data/glade/assembly_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @glade['name_entry'].text     = @info[:name]
	  @glade['author_entry'].text   = @info[:author]
	  @glade['approved_entry'].text = @info[:approved]
	  @glade['version_entry'].text  = @info[:version]
  end
  
  def ok_handle( w )
    info = @info.dup
    # read and return info from window
    info[:name]     = @glade['name_entry'].text
    info[:author]   = @glade['author_entry'].text
    info[:approved] = @glade['approved_entry'].text
    info[:version]  = @glade['version_entry'].text
    @manager.has_been_changed = true
    @glade['assembly_dialog'].destroy
    @return_handler.call info
  end
  
  def update_physical_info( w )
    
  end
end