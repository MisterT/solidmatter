#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff and Philip Silva on 19.12.2008.
#  Copyright (c) 2008. All rights reserved.


Force = Struct.new( :origin, :direction )

class FEMSolver
  def initialize( part, forces )
    @mesh = part.tesselate
    @forces = forces
  end
  
  def neighboors point
    @cache ||= {}
    unless @cache[point]
      #checked = []
      #my_tris = @mesh.select{|t| t.include? point }
      #@cache[point] = my_tris.flatten.uniq - [point]
      @mesh.flatten.sort_by{|p| p.distance_to point }
    end
    @cache[p]
  end
  
  def solve samples
    samples.times do
      
    end
  end
end

