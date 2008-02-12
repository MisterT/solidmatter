#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-12.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

class WaitForSaveDialog
  def initialize
    @glade = GladeXML.new( "glade/wait_for_save.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
    @glade['wait_for_save'].signal_connect('destroy'){ @t.kill }
    @t = Thread.new do
      @glade['progressbar'].pulse
      Gtk::main_iteration while Gtk::events_pending?
      sleep 0.1
    end
  end

  def cancel
    @glade['wait_for_save'].destroy
  end
  
  def close
    cancel
  end
end