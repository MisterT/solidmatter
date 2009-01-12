#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.

require 'libglade2'

class ProgressDialog
  def initialize title=nil
    @glade = GladeXML.new( "../data/glade/progress.glade", nil, 'solidmatter' ) {|handler| method(handler)}
    @glade['title_label'].markup = title if title
    self.fraction = 0.0
    @block = Proc.new if block_given?
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
    @block.call if @block
  end
  
  def close
    @glade['progress_dialog'].destroy
  end
end
