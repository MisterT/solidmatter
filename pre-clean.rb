#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-05-19.
#  Copyright (c) 2008. All rights reserved.

Dir.glob("data/**/*.mo").each do |file|
    File.delete(file)
end