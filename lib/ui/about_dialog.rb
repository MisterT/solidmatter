#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'

class AboutDialog
  def initialize
    @glade = GladeXML.new( "../data/glade/about.glade", nil, 'openmachinist' ) {|handler| method(handler)}
    @glade['aboutdialog'].transient_for = $main_win unless $main_win.destroyed?
  end
  
  def close
    @glade['aboutdialog'].destroy
  end
end
