#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'
require 'units.rb'


class PartInformationDialog
  include Units
	def initialize part
	  @part = part
	  @info = part.information
	  @return_handler = Proc.new
	  @glade = GladeXML.new( "../data/glade/part_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  # feed entries with part information
	  @glade['name_entry'].text     = @info[:name]
	  @glade['author_entry'].text   = @info[:author]
	  @glade['approved_entry'].text = @info[:approved]
	  @glade['version_entry'].text  = @info[:version]
	  # load materials into combo box
	  combo = @glade['material_combo']
	  combo.remove_text 0
	  $manager.materials.each{|m| combo.append_text m.name }
	  index = $manager.materials.index @info[:material]
	  combo.active = index if index
	  # set multi-user status
	  @glade['part_dialog'].transient_for = $manager.main_win
  end
  
  def ok_handle w 
    info = @info.dup
    # read and return info from window
    info[:name]     = @glade['name_entry'].text
    info[:author]   = @glade['author_entry'].text
    info[:approved] = @glade['approved_entry'].text
    info[:version]  = @glade['version_entry'].text
    info[:material] = $manager.materials[ @glade['material_combo'].active ]
    @glade['part_dialog'].destroy
    $manager.has_been_changed = true
    @return_handler.call info
  end
  
  def cancel_handle w 
    # return unmodified information
    @glade['part_dialog'].destroy
    @return_handler.call nil
  end
  
  def use_part_clicked w
    
  end
  
  def material_changed w
    
  end
  
  def update_solid_info w 
    GC.enable # make sure the garbage collector is still on
    @glade['area_label'].text = enunit(@part.area, 2)
    vol = @part.volume
    @glade['volume_label'].text = enunit(vol, 3)
    @glade['mass_label'].text   = enunit(@part.mass vol)
  end
end
