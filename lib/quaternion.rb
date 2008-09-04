#!/usr/bin/env ruby
#
#  Created by Philip Silva on 2.9.2008.
#  Copyright (c) 2008. All rights reserved.

require 'vector.rb'
require 'matrix4x4.rb'


class Quaternion
  include Math
  def Quaternion.rotation( rot_axis, angle )
    angle = angle * 2.0 * PI / 360
    rot_axis = rot_axis.normalize
    w = cos( angle/2.0 )
    x = rot_axis.x * sin( angle/2.0 )
    y = rot_axis.y * sin( angle/2.0 )
    z = rot_axis.z * sin( angle/2.0 )
    Quaternion.new(w,x,y,z)
  end

  attr_accessor :w, :x, :y, :z
  def initialize( *values )
    @w, @x, @y, @z = values.flatten
    @w, @x, @y, @z = [0.0] + @w.to_a if @w.is_a? Vector
    @w, @x, @y, @z = 0.0, 1.0, 1.0, 1.0
  end
  
  def * q
    case q
    when Quaternion
      p_s = w
      p_v = Vector[@x,@y,@z]
      q_s = q.w
      q_v = Vector[q.x, q.y, q.z]
      return Quaternion.new( [p_s * q_s - p_v.dot_product(q_v)] +  
                             (q_v * p_s + p_v * q_s + p_v.cross_product(q_v)).to_a )
    when Numeric
      return Quaternion.new( w/q, x/q, y/q, z/q )
    end
  end
  
  def / x
    self * (1.0 / x)
  end
  
  def transform_vector v
    v = Quaternion.new v
    (self * v * self.inverse).to_vec
  end
  
  def conjugate
    Quaternion.new( @w, -@x, -@y, -@z )
  end
  
  def abs2
    @w**2 + @x**2 + @y**2 + @z**2
  end
  
  def inverse
    raise "abs2 == 0" unless abs2 != 0
    conjugate / abs2
  end
  
  def to_mat
    angle = acos( @w ) * 2.0
    Matrix4x4.euler_rotation( Vector[@x, @y, @z], angle )
  end
  
  def to_vec
    Vector[@x, @y, @z]
  end
  
  def to_s
    "Quaternion [#{@w}, #{@x}, #{@y}, #{@z}]"
  end
end


=begin
v = Vector[8.4575475470, 1.045675475, 15.754746767]
r = Quaternion.rotation( Vector[0.0, 1.0, 0.0], 360.0/10000 )

t = Time.now
vec = r.transform_vector v
9999.times do
  vec = r.transform_vector vec
end
puts "Abweichung: #{v.distance_to vec}"
puts Time.now - t


t = Time.now
R = Matrix4x4.euler_rotation( Vector[0.0, 1.0, 0.0], 2*PI/10000 )
vec = (R * v.vec4).vec3!
9999.times do 
  vec = (R * vec.vec4).vec3!
end
puts "Abweichung: #{v.distance_to vec}"
puts Time.now - t
=end




