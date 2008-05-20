#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-01.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'multi_user.rb'

class ServerWin
  attr_accessor :server
  def initialize( server=nil )
    @glade = GladeXML.new( "../data/glade/server_win.glade", nil, 'openmachinist' ) {|handler| method(handler)}
    unless server
      @server = ProjectServer.new self
      @glade['server_win'].signal_connect('destroy'){Gtk.main_quit}
      @glade['server_win'].title = GetText._("Open Machinist dedicated server")
    end
    # ------- create projects view ------- #
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new GetText._('Projects')
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@pview = @glade['projects_view']
		@pview.append_column( column )
		# ------- create users view ------- #
		column = Gtk::TreeViewColumn.new GetText._('Users')
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@uview = @glade['users_view']
		@uview.append_column( column )
		update
  end
  
  def add_project
    @server = ProjectServer.new unless @server
    @server.add_project
    update
  end
  
  def remove_project
    @server.remove_project selected_project
    update
  end
  
  def edit_project
    selected_project.display_properties if selected_project
  end
  
  def selected_project
    @pview.selection.selected_each do |model, path, iter|
      return @server.projects[path.indices[0]]
    end
    return nil
  end
  
  def add_user
    user = UserAccount.new self
    @server.accounts.push user
    update
  end
  
  def remove_user
    @server.accounts.delete selected_user
    update
  end
  
  def edit_user
    selected_user.display_properties if selected_user
  end
  
  def selected_user
    @uview.selection.selected_each do |model, path, iter|
      return @server.accounts[path.indices[0]]
    end
    return nil
  end
  
  def update
    # projects view
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/middle/user-home_middle.png').pixbuf
    for project in @server.projects
		  iter = model.append
  		iter[0] = im
  		iter[1] = project.name
		end
		@pview.model = model
		# users view
		model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/middle/system-users_middle.png').pixbuf
    for acc in @server.accounts
		  iter = model.append
  		iter[0] = im
  		iter[1] = acc.login
		end
		@uview.model = model
  end
end