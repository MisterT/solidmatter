#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-12.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'

class WaitForSaveDialog
  def initialize client
    @client = client
    @glade = GladeXML.new( "../data/glade/wait_for_save.glade", nil, 'solidmatter' ) {|handler| method(handler)}
    @glade['wait_for_save'].signal_connect('destroy'){ @t.kill }
    progressbar = @glade['progressbar']
    @t = GtkThread.start do
      loop do
        progressbar.pulse
        sleep 0.01
      end
    end
  end

  def cancel
    @glade['wait_for_save'].destroy
    @client.cancel_save_request
  end
  
  def close
    cancel
  end
end