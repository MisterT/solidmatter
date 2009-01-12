#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
require 'multi_user.rb'
require 'preferences'

# init translation framework
GetText.bindtextdomain 'solidmatter'

server = ProjectServer.new

# register server on the local network
Thread.start{ `avahi-publish-service "SolidMatter" _workstation._tcp #{$preferences[:server_port]}` }

# run until we receice an exit signal
DRb.thread.join
`killall avahi-publish-service`
