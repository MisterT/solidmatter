#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-05-19.
#  Copyright (c) 2008. All rights reserved.

require 'gettext/rmsgfmt'
require 'gettext/utils'

GetText.update_pofiles("solidmatter", Dir.glob("{lib,data/glade}/**/*.{rb,rhtml,glade}"), "solidmatter 0.1")
GetText.create_mofiles
