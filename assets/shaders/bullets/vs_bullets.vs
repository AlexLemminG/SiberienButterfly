$input a_position, a_normal, a_tangent, a_texcoord0, i_data0, i_data1, i_data2
$output v_wpos, v_normal, v_texcoord0

/*
 * Copyright 2011-2021 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "../common/common.sh"

void main()
{	
	mat4 model = mtxFromRows(i_data0, i_data1, i_data2, vec4(0,0,0,1));


	v_wpos = mul(model, vec4(a_position, 1.0) ).xyz;

	gl_Position = mul(u_viewProj, vec4(v_wpos, 1.0) );

	vec3 wnormal = mul(model, vec4(a_normal.xyz, 0.0) ).xyz;
	vec3 wtangent = mul(model, vec4(a_tangent.xyz, 0.0) ).xyz;

	v_normal = normalize(wnormal);
	//v_tangent = normalize(wtangent);
	//v_bitangent = cross(v_normal, v_tangent) * a_tangent.w;
	

	v_texcoord0 = a_texcoord0;
}
