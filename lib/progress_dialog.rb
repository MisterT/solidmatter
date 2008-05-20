#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'

class ProgressDialog
  def initialize
    @glade = GladeXML.new( "../data/glade/progress.glade", nil, 'openmachinist' ) {|handler| method(handler)}
    self.fraction = 0.0
  end
  
  def fraction
    @glade['progressbar'].fraction
  end
  
  def fraction= val
    @glade['progressbar'].fraction = val
    @glade['progressbar'].text = (val * 100).round.to_s + "%"
    Gtk::main_iteration while Gtk::events_pending?
  end
  
  def text= txt
  	@glade['message_label'].text = txt
  	Gtk::main_iteration while Gtk::events_pending?
  end

  def cancel
    close
  end
  
  def close
    @glade['progress_dialog'].destroy
  end
end
