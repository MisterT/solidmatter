#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
            
class ExportDialog
	def initialize &block
	  @glade = GladeXML.new( "../data/glade/export_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
    @block = block
    @formats = ['STL', 'lxs']
    @glade['format_combo'].model.clear
    @formats.each{|f| @glade['format_combo'].append_text f }
    @glade['format_combo'].active = 0
  end
  
  def combo_changed
    
  end
  
  def ok
    @block.call( '.' + @formats[@glade['format_combo'].active].downcase, false )
    close
  end
	
  def close
    @glade['export_dialog'].destroy
  end
end

