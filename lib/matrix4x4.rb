#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'matrix'
include Math

module Matrix4x4
	def Matrix4x4.mult(vec,mat)
		if vec.kind_of? Vector and mat.square? and mat.row_size == 4
			# create 3x3 matrix without transforms
			m = Matrix[*
				(0..2).collect do |i|
					(0..2).collect do |j|
						mat[i,j]
					end
				end
			]
			# multiply vector with matrix and add transforms
			new_vec = (Matrix.row_vector(vec) * m).row(0)
			transformation = Vector[*(0..2).collect{|i| mat.column(3)[i]}]
			#puts new_vec, transformation,new_vec + transformation
			return new_vec + transformation
		else
			raise "use his method only for multiplying 3D vectors with 4x4 transformation matrices"
		end
	end

	def Matrix4x4.null_matrix
		Matrix[
		 [0,0,0,0],
		 [0,0,0,0],
		 [0,0,0,0],
		 [0,0,0,0]
		]
	end

	def Matrix4x4.neutral_matrix
		Matrix[
		 [1,0,0,0],
		 [0,1,0,0],
		 [0,0,1,0],
		 [0,0,0,1]
		]
	end

	def Matrix4x4.translation_matrix(trans_vec)
		Matrix[
		 [1,0,0,trans_vec[0]],
		 [0,1,0,trans_vec[1]],
		 [0,0,1,trans_vec[2]],
		 [0,0,0,     1      ]
		]
	end

	def Matrix4x4.scale_matrix(scale_vec)
		Matrix[
		 [scale_vec[0],       0,             0,        0],
		 [     0,        scale_vec[1],       0,        0],
		 [     0,             0,        scale_vec[2],  0],
		 [     0,             0,             0,        1]
		]
	end

	def Matrix4x4.rotation_matrix(point, axis, angle)
		# make point alligned at origin
		origin_mat = Matrix[
			 [1, 0, 0, -point.x],
			 [0, 1, 0, -point.y],
			 [0, 0, 1, -point.z],
			 [0, 0, 0,     1   ]
			]
		# rotate around z to align with xz plane
		v = sqrt((axis[0])**2 + (axis[1])**2)
		xz_mat = Matrix[
			 [ axis[0]/v, axis[1]/v, 0, 0],
			 [-axis[1]/v, axis[0]/v, 0, 0],
			 [     0,        0,    0, 0],
			 [     0,        0,    0, 0]
			]
		# rotate around y to align with z axis
		w = sqrt(v**2 + axis[2])
		z_mat = Matrix[
			 [axis[2]/w, 0,   -v/w,   0],
			 [    0,    1,     0,    0],
			 [   v/w,   0, axis[2]/w, 0],
			 [    0,    0,     0,    1]
			]
		# rotate around z axis
		z_rot_mat = z_rotation_matrix(angle)
		# revert all previous operations
		rot_mat = origin_mat.inverse * xz_mat.inverse * z_mat.inverse *
		          z_rot_mat * z_mat * xz_mat * origin_mat
		return rot_mat
	end

	def Matrix4x4.euler_rotation(axis, angle)
		c = cos(angle)
		s = sin(angle)
		t = 1 - c
		x,y,z = axis[0], axis[1], axis[2]
		Matrix[
		 [t*x**2+c , t*x*y-s*z, t*x*z+s*y, 0],
		 [t*x*y+s*z, t*y**2+c , t*y*z-s*x, 0],
		 [t*x*z-s*y, t*y*z+s*z, t*z**2+c , 0],
		 [    0    ,     0    ,     0    , 1]
		]
	end

	def Matrix4x4.x_rotation_matrix(angle)
		Matrix[
		 [1,      0,          0,       0],
		 [0,  cos(angle),-sin(angle),  0],
		 [0,  sin(angle), cos(angle),  0],
		 [0,      0,          0,       1]
		]
	end

	def Matrix4x4.y_rotation_matrix(angle)
		Matrix[
		 [cos(angle),   0,  sin(angle),  0],
		 [     0,       1,      0,       0],
		 [-sin(angle),  0,  cos(angle),  0],
		 [     0,       0,      0,       1]
		]
	end

	def Matrix4x4.z_rotation_matrix(angle)
		Matrix[
		 [cos(angle),  -sin(angle),  0,  0],
		 [sin(angle),   cos(angle),  0,  0],
		 [    0,            0,       1,  0],
		 [    0,            0,       0,  1]
		]
	end
end

