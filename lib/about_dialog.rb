#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

def show_about_dialog
  GladeXML.new( "glade/about.glade", nil, nil, nil, GladeXML::FILE ) #{|handler| method(handler)}
end