#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'server_win.rb'

Gtk.init
ServerWin.new
Gtk::main