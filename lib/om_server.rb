#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
require 'server_win.rb'
require 'about_dialog'
require 'preferences'
require 'gtk_threadsafe.rb'

# init translation framework and Gtk
GetText.bindtextdomain 'openmachinist'
Gtk.init

# create tray icon
si = Gtk::StatusIcon.new
si.file = '../data/icons/middle/part_middle.png'
si.tooltip = "Open Machinist dedicated server"
si.visible = true
si.blinking = true
Thread.start do
  sleep 4
  Gtk.queue{ si.blinking = false }
end
# create ServerWindow. This also starts the actual server
win = ServerWin.new
server = win.server
si.signal_connect('activate'){ win.destroyed ? win = ServerWin.new(server) : win.destroy }
# create pop-up menu for tray icon
m = Gtk::Menu.new
items = [
	Gtk::ImageMenuItem.new(GetText._("_Manage users and projects")).set_image( Gtk::Image.new('../data/icons/small/preferences-system_small.png') ),
	Gtk::ImageMenuItem.new(GetText._("_Run")).set_image( Gtk::Image.new(Gtk::Stock::EXECUTE, Gtk::IconSize::MENU) ),
	Gtk::ImageMenuItem.new(Gtk::Stock::STOP),
	Gtk::ImageMenuItem.new(Gtk::Stock::ABOUT),
	Gtk::SeparatorMenuItem.new,
	Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
]
items[0].signal_connect("activate") do
	si.activate
end
items[3].signal_connect("activate") do
	AboutDialog.new
end
items[5].signal_connect("activate") do
	server.stop
	Gtk.main_quit
end
items.each{|i| m.append i }
m.show_all
# connect menu to icon
si.signal_connect('popup-menu'){|w,btn,time| m.popup(nil, nil, 3,  time) }
Gtk.main_with_queue 100
