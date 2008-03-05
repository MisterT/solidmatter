#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

                  
class InsertComponentDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/insert_component_dialog.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
	  @glade['part_combo'].model.clear
    @manager.all_parts.each{|p| @glade['part_combo'].append_text p.name }
    @glade['part_combo'].active = 0
	  @glade['assembly_combo'].model.clear
    @manager.all_assemblies.each{|p| @glade['assembly_combo'].append_text p.name }
    @glade['assembly_combo'].active = 0
  end
  
  def close w 
    @glade['insert_component_dialog'].destroy
  end
  
	def insert_part

	end
	
	def insert_assembly
		
	end
end
                  
