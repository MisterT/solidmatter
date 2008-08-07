#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'matrix'

class Vector
  attr_accessor :elements
	alias dot_product inner_product
	alias length r
	
	def vec4
	  Vector[ self[0], self[1], self[2], 1 ]
	end
	
	def vec3!
	  @elements.delete_at 3
	  self
  end
  
	def x
		self[0]
	end
	
	def y
		self[1]
	end
	
	def z
		self[2]
	end
	
	def x=(v)
		@elements[0] = v
	end

	def y=(v)
		@elements[1] = v
	end
	
	def z=(v)
		@elements[2] = v
	end
	
	def add( v )
	  @elements[0] += v.x
	  @elements[1] += v.y
	  @elements[2] += v.z
  end
	
	def /( value )
		Vector[x/value, y/value, z/value]
	end
	
	def cross_product(vec)
		Vector[
			(self[1] * vec[2]) - (self[2] * vec[1]),
			(self[2] * vec[0]) - (self[0] * vec[2]),
			(self[0] * vec[1]) - (self[1] * vec[0])
		]
	end
	
	def length=(new_len)
		new_vec = self * (new_len / self.length )
		3.times{|i| @elements[i] = new_vec[i]}
		self
	end
	
	def normalize!
		self.length = 1
		return self
	end
	
	def normalize
		new_vec = self.dup
		new_vec.normalize!
		return new_vec
	end

	def reverse!
		3.times{|i| @elements[i] = -@elements[i] }
		return self
	end
	alias invert! reverse!
	
	def reverse
		new_vec = self.dup
		new_vec.reverse!
		return new_vec
	end
	alias invert reverse
	
	def angle( vec )
		dot = self.normalize.dot_product(vec.normalize)
		return (Math.acos( dot ) / (2 * Math::PI)) * 360
	end
	
	def vector_to( v )
		v - self
	end
	
	def distance_to v
	 (vector_to v).length
	end
	
	def near_to other
		distance_to(other) < $preferences[:merge_threshold]
	end
	
	def project_xy
	 Vector[ self[0], self[1], 0 ]
	end
	
	def project_xz
	 Vector[ self[0], 0, self[2] ]
	end
	
	def project_yz
	 Vector[ 0, self[1], self[2] ]
	end
	
	def dup
	  copy = super
	  copy.elements = @elements.dup
	  return copy
	end
end






