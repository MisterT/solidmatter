#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'

class AboutDialog
  def initialize
    @glade = GladeXML.new( "glade/about.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def close
    @glade['aboutdialog'].destroy
  end
end