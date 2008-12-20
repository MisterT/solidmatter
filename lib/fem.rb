#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff and Philip Silva on 19.12.2008.
#  Copyright (c) 2008. All rights reserved.

class Array
  def each_combi_with_index
    size.times do |i|
      size.times do |j|
        yield [self[i], i, self[j], j] if i <= j
      end
    end
  end
end


Force = Struct.new( :origin, :direction )

class FEMSolver
  def initialize( part, forces )
    @mesh = unredundize part.tesselate
    @forces = forces
  end
  
  def unredundize tris
    tris.each_combo_with_index do |tri1, i1, tri2, i2|
      3.times do |pi1|
        3.times do |pi2|
          if tri1[pi1] == tri2[pi2]
            tri2[pi2] = tri1[pi1]
          end
        end
      end
    end
    tris
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

