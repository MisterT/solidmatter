#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-10.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class CloseProjectConfirmation
  def initialize manager
    @block = Proc.new if block_given?
    @glade = GladeXML.new( "glade/close_project_confirmation.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
    @glade['main_label'].markup = "<b>Save changes to '#{manager.project_name}'?</b>"
    if manager.has_been_changed
      @glade['close_project_confirmation'].show_all
    else
      @block.call :close
      cancel
    end
  end
  
  def save
    @block.call :save
    @glade['close_project_confirmation'].destroy
  end

  def cancel
    @glade['close_project_confirmation'].destroy
  end
  
  def close
    @glade['close_project_confirmation'].destroy
    @block.call :close
  end
end