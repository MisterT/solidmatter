#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-05-19.
#  Copyright (c) 2008. All rights reserved.

require 'gettext/rmsgfmt'
require 'gettext/utils'

GetText.update_pofiles("openmachinist", Dir.glob("{lib,data/glade}/**/*.{rb,rhtml,glade}"), "openmachinist 0.0.2")
GetText.create_mofiles

ENV['GCONF_CONFIG_SOURCE'] = `gconftool-2 --get-default-source`.chomp
Dir["data/schemas/*.schemas"].each do |schema|
  system("gconftool-2 --makefile-install-rule '#{schema}'")
end
