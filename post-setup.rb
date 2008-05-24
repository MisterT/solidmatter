#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-05-19.
#  Copyright (c) 2008. All rights reserved.

require 'gettext/rmsgfmt'
require 'gettext/utils'

#GetText.update_pofiles("openmachinist", Dir.glob("{lib,bin,data/glade}/**/*.{rb,rhtml,glade}"), "openmachinist 0.0.2")
GetText.create_mofiles
