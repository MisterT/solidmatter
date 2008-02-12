#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-20.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'
require 'lib/new_project_dialog.rb'

class NewDialog
  def initialize( manager )
    @manager = manager
    @glade = GladeXML.new( "glade/new_dialog.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def new_project
    close
    NewProjectDialog.new(@manager)
  end
  
  def new_assembly
    @manager.new_assembly
    close
  end
  
  def new_part
    @manager.new_part
    close
  end
  
  def close
    @glade['new_dialog'].destroy
  end
end