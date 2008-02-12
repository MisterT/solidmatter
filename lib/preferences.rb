#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

Bookmark = Struct.new( :adress, :port, :login, :password )


$om_preferences = { :bookmarks => [ Bookmark.new( 'localhost', 2222, 'synthetic', 'bla' ) ] 
                  }