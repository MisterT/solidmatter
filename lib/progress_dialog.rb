#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'

class ProgressDialog
  def initialize
    @glade = GladeXML.new( "glade/progress.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
    self.fraction = 0.0
    Gtk::main_iteration while Gtk::events_pending?
  end
  
  def fraction
    @glade['progressbar'].fraction
  end
  
  def fraction= val
    @glade['progressbar'].fraction = val
    Gtk::main_iteration while Gtk::events_pending?
  end

  def cancel
    close
  end
  
  def close
    @glade['progress_dialog'].destroy
  end
end