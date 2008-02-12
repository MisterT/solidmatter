#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-12.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class SaveRequestDialog
  def initialize client
    @client = client
    @glade = GladeXML.new( "glade/close_project_confirmation.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
  end
  
  def delay
    @glade['close_project_confirmation'].destroy
  end

  def cancel
    @glade['close_project_confirmation'].destroy
    @client.cancel_save_request
  end
  
  def save_now
    @client.accept_save_request
  end
  
  def close
    cancel
  end
end