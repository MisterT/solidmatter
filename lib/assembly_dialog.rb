#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-04.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'units.rb'


class AssemblyInformationDialog
  include Units
	def initialize assembly
	  @assembly = assembly
	  @return_handler = Proc.new
	  @glade = GladeXML.new( "../data/glade/assembly_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @glade['name_entry'].text     = @assembly.information[:name]
	  @glade['author_entry'].text   = @assembly.information[:author]
	  @glade['approved_entry'].text = @assembly.information[:approved]
	  @glade['version_entry'].text  = @assembly.information[:version]
  end
  
  def ok_handle( w )
    info = @assembly.information.dup
    # read and return info from window
    info[:name]     = @glade['name_entry'].text
    info[:author]   = @glade['author_entry'].text
    info[:approved] = @glade['approved_entry'].text
    info[:version]  = @glade['version_entry'].text
    $manager.has_been_changed = true
    @glade['assembly_dialog'].destroy
    @return_handler.call info
  end
  
  def update_physical_info( w )
    GC.enable # make sure the garbage collector is still on
    @glade['area_label'].text = enunit(@assembly.area, 2).to_s
    @glade['volume_label'].text = enunit(@assembly.volume, 3).to_s
    @glade['mass_label'].text = @assembly.mass.to_s
  end
end
