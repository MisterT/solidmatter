#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'


class MakePublicDialog
	def initialize
	  @block = Proc.new if block_given?
	  @glade = GladeXML.new( "../data/glade/make_public_dialog.glade", nil, 'openmachinist' ) {|handler| method(handler)}
	  update_combo
  end
  
  def ok_handle w 
    adress   = @glade['adress_entry'].text
    port     = @glade['port_entry'].text
    login    = @glade['login_entry'].text
    password = @glade['password_entry'].text
    adress, port = 'localhost', 2222 if @glade['local_radio'].active?
    @block.call( adress, port)
    @glade['make_public_dialog'].destroy
  end
  
  def cancel_handle w
    @glade['make_public_dialog'].destroy
  end
  
  def add_bookmark w
    bm = Bookmark.new( @glade['adress_entry'].text, @glade['port_entry'].text, @glade['login_entry'].text, @glade['password_entry'].text )
    $preferences[:bookmarks].push bm
    update_combo
  end
  
  def remove_bookmark w
    $preferences[:bookmarks].delete_at @glade['bookmark_combo'].active
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
  
  def radio_changed w
  	
  end
end

