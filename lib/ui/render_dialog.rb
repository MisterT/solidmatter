#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
            
class RenderDialog
	def initialize
	  @glade = GladeXML.new( "../data/glade/render_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
  end

  def ok
    close
  end
	
  def close
    @glade['render_dialog'].destroy
  end
end

