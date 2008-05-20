#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'multi_user.rb'

class AccountEditor
  def initialize account
    @account = account
    @glade = GladeXML.new( "../data/glade/account_editor.glade", nil, 'openmachinist' ) {|handler| method(handler)}
    @glade['login_entry'].text    = @account.login 
    @glade['password_entry'].text = @account.password
    # ------- create server view ------- #
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new 'Projects on server'
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@sview = @glade['server_view']
		@sview.append_column( column )
		# ------- create user view ------- #
		column = Gtk::TreeViewColumn.new "User's projects"
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@uview = @glade['user_view']
		@uview.append_column column 
		@sview.selection.mode = Gtk::SELECTION_MULTIPLE
		@uview.selection.mode = Gtk::SELECTION_MULTIPLE
		update
  end
  
  def ok_handle
    @account.login    = @glade['login_entry'].text
    @account.password = @glade['password_entry'].text
    @account.server_win.update
    @glade['account_editor'].destroy
  end
  
  def move_to_user
    selected_server_projects.each{|pr| @account.registered_projects.push pr }
    update
  end
  
  def remove_from_user
    selected_user_projects.each{|pr| @account.registered_projects.delete pr }
    update
  end
  
  def selected_server_projects
    sel = []
    @sview.selection.selected_each do |model, path, iter|
      sel.push( (@account.server.projects - @account.registered_projects)[path.indices[0]] )
    end
    return sel
  end
  
  def selected_user_projects
    sel = []
    @uview.selection.selected_each do |model, path, iter|
      sel.push( @account.registered_projects[path.indices[0]] )
    end
    return sel
  end
  
  def update
    server_projects = @account.server.projects - @account.registered_projects
    # projects view
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/middle/user-home_middle.png').pixbuf
    for project in server_projects
		  iter = model.append
  		iter[0] = im
  		iter[1] = project.name
		end
		@sview.model = model
		# users view
		model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    for project in @account.registered_projects
		  iter = model.append
  		iter[0] = im
  		iter[1] = project.name
		end
		@uview.model = model
  end
end