#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
require 'multi_user.rb'
require 'preferences'

# init translation framework
GetText.bindtextdomain 'openmachinist'

# run until we receice a exit signal
server = ProjectServer.new
DRb.thread.join


