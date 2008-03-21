#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-01-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class JoinProjectDialog
	def initialize manager
	  @manager = manager
	  @glade = GladeXML.new( "glade/join_project.glade", nil, nil, nil, GladeXML::FILE ) {|handler| method(handler)}
	  update_combo
  end
  
  def ok_handle( w )
    adress       = @glade['adress_entry'].text
    port         = @glade['port_entry'].text
    projectname  = @glade['project_combo'].active_iter[0]
    login        = @glade['login_entry'].text
    password     = @glade['password_entry'].text
    @manager.join_project( adress, port, projectname, login, password )
    @glade['join_project'].destroy
  end
  
  def cancel_handle( w )
    @glade['join_project'].destroy
  end
  
  def connect w
    adress = @glade['adress_entry'].text
    port   = @glade['port_entry'].text
    client = ProjectClient.new( adress, port, @manager )
    if client.working
      available = client.available_projects.map{|pr| pr.name }
      client.exit
      @glade['project_combo'].model.clear
      available.each{|name| @glade['project_combo'].append_text name }
      @glade['project_combo'].active = 0
      @glade['ok_button'].sensitive = true
    else
      @glade['ok_button'].sensitive = false
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
end
