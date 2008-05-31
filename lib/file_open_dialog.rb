#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'component_browser'

class FileOpenDialog < Gtk::FileChooserDialog
  def initialize save=false
    super( save ? GetText._("Save project as..") : GetText._("Choose project file"),
           nil,
           save ? Gtk::FileChooser::ACTION_SAVE : Gtk::FileChooser::ACTION_OPEN,
           nil,
           [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
           [save ? Gtk::Stock::SAVE : Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT] )
    set_property('do-overwrite-confirmation', true) 
    # add file filter
    filter = Gtk::FileFilter.new
    filter.name = GetText._("Open Machinst project")
    filter.add_pattern("*.omp")
    add_filter filter
    filter = Gtk::FileFilter.new
    filter.name = GetText._("All filetypes")
    filter.add_pattern("*")
    add_filter filter
    # add preview widget
    signal_connect("update-preview") do
      filename = self.preview_filename
      begin
        image = nil
        File::open( filename ) do |file|
					scene = Marshal::restore file 
          image = scene[0]
				end
				gtkim = native2gtk image.to_native
				self.preview_widget = gtkim
        self.preview_widget_active = true
      rescue
        self.preview_widget_active = false
      end
    end
  end
end

	