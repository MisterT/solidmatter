#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'dbus'


class JoinProjectDialog
	def initialize
	  @glade = GladeXML.new( "../data/glade/join_project.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  @servers = {}
	  # create server list
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new GetText._("Servers on local network")
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@server_list = @glade['server_list']
		@server_list.append_column( column )
		# load bookmarks and search local network
	  update_combo
	  setup_zeroconf
  end
  
  def setup_zeroconf
    @listener = Thread.start do
      bus = DBus::SystemBus.instance
      p = bus.introspect("org.freedesktop.Avahi", "/")
      server = p["org.freedesktop.Avahi.Server"]
      browser = server.ServiceBrowserNew(-1, -1, "_workstation._tcp", "", 0)
      # register for signals
      mr = DBus::MatchRule.new
      mr.type = "signal"
      mr.interface = "org.freedesktop.Avahi.ServiceBrowser"
      mr.path = browser.first
      bus.add_match(mr) do |msg, first_param|
        if msg.params[2] and msg.params[2] == "SolidMatter"
          if msg.member == "ItemNew"
            resolver = server.ResolveService (-1, -1, msg.params[2], "_workstation._tcp", "", 0, 0)
            address = resolver[7]
            port = resolver[8]
            puts "#{address} : #{port}"
            @servers[address] = port
          elsif msg.member == "ItemRemove"
            #@servers.delete address
            #XXX servers going offline is not handled gracefully
          end
          Gtk.queue{ update_server_list }
        end
      end
      main = DBus::Main.new
      main << bus
      main.run
    end
  end
  
  def ok_handle( w )
    adress       = @glade['adress_entry'].text
    port         = @glade['port_entry'].text
    projectname  = @glade['project_combo'].active_iter[0]
    login        = @glade['login_entry'].text
    password     = @glade['password_entry'].text
    $manager.join_project( adress, port, projectname, login, password )
    @glade['join_project'].destroy
  end
  
  def cancel_handle( w )
    @listener.kill
    @glade['join_project'].destroy
  end
  
  def connect w
    adress = @glade['adress_entry'].text
    port   = @glade['port_entry'].text
    client = ProjectClient.new( adress, port )
    if client.working
      available = client.available_projects.map{|pr| pr.name }
      client.exit
      @glade['project_combo'].model.clear
      available.each{|name| @glade['project_combo'].append_text name }
      @glade['project_combo'].active = 0
      @glade['ok_button'].sensitive = true
      @glade['project_combo'].sensitive = true
    else
      @glade['ok_button'].sensitive = false
      @glade['project_combo'].sensitive = false
    end
  end
  
  def add_bookmark w
    bm = Bookmark.new( @glade['adress_entry'].text, @glade['port_entry'].text, @glade['login_entry'].text, @glade['password_entry'].text )
    $preferences[:bookmarks].push bm
    update_combo
  end
  
  def remove_bookmark w
    $preferences[:bookmarks].delete_at  @glade['bookmark_combo'].active
    update_combo
  end
  
  def bookmark_combo_changed w
    current_bm = $preferences[:bookmarks][w.active]
    if current_bm
      @glade['adress_entry'].text   = current_bm.adress  
      @glade['port_entry'].text     = current_bm.port.to_s    
      @glade['login_entry'].text    = current_bm.login   
      @glade['password_entry'].text = current_bm.password
    end
  end
  
  def update_combo
    @glade['bookmark_combo'].model.clear
    for bm in $preferences[:bookmarks]
      @glade['bookmark_combo'].append_text bm.adress
    end
    @glade['bookmark_combo'].active = $preferences[:bookmarks].size - 1
  end
  
  def update_server_list
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
    for addr in @servers.keys
		  iter = model.append
  		iter[0] = im
  		iter[1] = addr
		end
		@server_list.model = model
  end
end






