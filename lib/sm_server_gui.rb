#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

debug = false

pid = fork unless debug
if not debug and not pid
  # create actuall server in seperate process, as running with Gtk has side effects
  `ruby om_server.rb`  
else
  require 'rubygems'
  require 'drb'
  require 'multi_user.rb'
  require 'ui/server_win.rb'
  require 'ui/about_dialog'
  require 'preferences'
  require 'gtk_threadsafe.rb'
  
  server = debug ? ProjectServer.new : DRbObject.new_with_uri("druby://:#{$preferences[:server_port]}")
  
  # init translation framework and Gtk
  GetText.bindtextdomain 'solidmatter'
  Gtk.init
  
  # create tray icon
  si = Gtk::StatusIcon.new
  si.file = '../data/icons/middle/part_middle.png'
  si.tooltip = "Solid|matter dedicated server"
  si.visible = true
  si.blinking = true
  GtkThread.start do
    sleep 4
    Gtk.queue{ si.blinking = false }
  end
  # create ServerWindow
  win = ServerWin.new server
  $main_win = win.real_win
  si.signal_connect('activate') do
    if win.destroyed
      win = ServerWin.new server
      $main_win = win.real_win
    else
      win.active? ? win.destroy : win.present
    end
  end
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
end
