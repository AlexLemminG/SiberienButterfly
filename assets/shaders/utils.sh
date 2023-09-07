
float GetClipDepthAtWorldPos(vec3 worldPos){
	vec4 proj = mul(u_viewProj, vec4(worldPos, 1.0) );
	vec3 clip;
	clip.xy = (proj.xy / proj.w + 1.0) / 2.0;
	#if BGFX_SHADER_LANGUAGE_SPIRV
	clip.y = 1.0 -clip.y;//TODO
	#endif
	clip.z = (proj.z / proj.w);
	return clip.z;
}
float GetDepthAtWorldPos(vec3 worldPos){
	vec4 proj = mul(u_viewProj, vec4(worldPos, 1.0) );
	vec3 clip;
	clip.xy = (proj.xy / proj.w + 1.0) / 2.0;
	#if BGFX_SHADER_LANGUAGE_SPIRV
	clip.y = 1.0 -clip.y;//TODO
	#endif
	clip.z = (proj.z / proj.w);
	float deviceDepth = texture2D(s_depthPrepass, clip.xy).x;
 	float depth       = toClipSpaceDepth(deviceDepth);
	return depth;
}
vec3 GetDepthWorldPos(vec3 worldPos){
	vec4 view = mul(u_view, vec4(worldPos, 1.0) );
	vec4 proj = mul(u_viewProj, vec4(worldPos, 1.0) );
	proj = proj/proj.w;
	vec3 clip;
	clip.xy = (proj.xy / proj.w + 1.0) / 2.0;
	#if BGFX_SHADER_LANGUAGE_SPIRV
	clip.y = 1.0 -clip.y;//TODO
	#endif
	clip.z = (proj.z / proj.w);
	float deviceDepth = texture2D(s_depthPrepass, clip.xy).x;
 	float clipDepth       = toClipSpaceDepth(deviceDepth);

	vec4 clipSpacePos = vec4(clip.x *2.0-1.0, clip.y*2.0-1.0, clipDepth, 1.0);
	clipSpacePos.y = -clipSpacePos.y;
	vec4 viewSpacePosition = mul(u_projInv, clipSpacePos);
	viewSpacePosition /= viewSpacePosition.w;
	vec4 worldSpacePosition = mul(u_viewInv, viewSpacePosition);

	vec4 view2 = mul(u_projInv, proj);
	vec4 view3 = viewSpacePosition;

	clip = clip *2.0 - 1.0;
	return worldSpacePosition.xyz;
}

float SSShadow(vec3 worldPos, vec3 lightDir)
{
	float thisDepth = GetDepthAtWorldPos(worldPos);
	vec3 sampleDir = -lightDir;//vec3(0.3,0.1,0.3);
	sampleDir = sampleDir / length(sampleDir);
	float sampleOffsetLength = 0.1;
	vec3 sampleOffset = sampleDir * sampleOffsetLength;
	vec3 samplePos = worldPos;
	float maxShadowLength = 5.4;
	float maxShadow = 1.0;
	for(int i = 0; i < maxShadowLength / sampleOffsetLength; i++){
		samplePos += sampleOffset;
		vec3 sampleRealPos = GetDepthWorldPos(samplePos);


		float depthAtPos = GetDepthAtWorldPos(samplePos);
		float f = -GetDepthAtWorldPos(samplePos) + GetClipDepthAtWorldPos(samplePos);
		float minRange = 0.0005;
		float maxRange = 0.1;
		float fNorm = (f - minRange) / (maxRange - minRange);
		if(f > 0.000 ){
			float cosAngle = dot(sampleRealPos - worldPos, sampleDir) / length(sampleRealPos - worldPos);
			if(length(sampleRealPos - worldPos) < maxShadowLength ){
				return 0.0;
			}
		}
	}
	return 1.0;
}
