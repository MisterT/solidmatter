#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-20.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'
require 'ui/new_project_dialog.rb'

class NewDialog
  def initialize
    @glade = GladeXML.new( "../data/glade/new_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
  end
  
  def new_project
    close
    NewProjectDialog.new
  end
  
  def new_assembly
    $manager.project.new_assembly
    close
  end
  
  def new_part
    $manager.project.new_part
    close
  end
  
  def close
    @glade['new_dialog'].destroy
  end
end
