#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 19-03-07.
#  Copyright (c) 2008. All rights reserved.

def distance( from , to)
		Math::sqrt(
			(from.x - to.x)**2 + 
			(from.y - to.y)**2 + 
			(from.z - to.z)**2
		)
end

