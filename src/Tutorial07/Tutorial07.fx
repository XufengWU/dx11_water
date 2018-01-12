//--------------------------------------------------------------------------------------
// File: Tutorial07.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
Texture2D txDiffuse : register( t0 );
SamplerState samLinear : register( s0 );
TextureCube txCube : register(t1);
Texture2D txNormal	: register( t2 );
Texture2D txSSR : register( t3 );

cbuffer cbNeverChanges : register( b0 )
{
    //matrix View;
};

cbuffer cbChangeOnResize : register( b1 )
{
    matrix Projection;
};

cbuffer cbChangesEveryFrame : register( b2 )
{
    matrix World;
	matrix View;
	float4 gEye;
    float4 vMeshColor;
	float4 gTime;
	float gNoise;
};


//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
	float4 Norm : NORMAL0;
};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
	float4 PosW : POSITION;
    float2 Tex : TEXCOORD0;
	float4 NormW : NORMAL0;
};


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS( VS_INPUT input )
{
    PS_INPUT output = (PS_INPUT)0;
	
	input.Pos.x *= 2;
	input.Pos.z *= 2;

	float t = gTime.x;
	
	//input.Pos.y += 0.1 * sin(2 * input.Pos.x + 2 * t);// + 0.2 * sin(at.x + 3 * t) + sin(5 * t + length(at - wave_s)) * length(at - wave_s) / 80;
	//input.Pos.x += 0.2 * cos(2 * input.Pos.x + 2 * t);
	
	//input.Pos.y -= 2 + sin(gTime.x) * 0.1;
	//input.Pos.y += 0.2 * sin(2 * gTime.x + input.Pos.x * 5);
	output.Pos = mul(input.Pos, World);
	output.PosW = output.Pos;
    output.Pos = mul( output.Pos, View );
    output.Pos = mul( output.Pos, Projection );
	// output.Pos.z = output.Pos.w * 0.999;
	//input.Tex.x += gTime.x;
    output.Tex = input.Tex;
	float4 normW = { mul(input.Norm, World).xyz, 0 };
	output.NormW = normalize(normW);
    
    return output;
}

// SSR ray march
// xyz == color, w == intersection flag (0 == false)
// NDC space
float4 RayMarch(float4 start, float4 end) 
{
	float4 res = {0, 0, 0, 0};
	float3 dir = normalize(end - start).xyz;
	float3 curPoint = start.xyz;
	while (curPoint.x > -1 && curPoint.x < 1 && curPoint.y > -1 && curPoint.y < 1 && curPoint.z < 1) {
		float2 tex = { (curPoint.x + 1) / 2, (1 - curPoint.y) / 2 };
		float4 ssrColor = txSSR.Sample(samLinear, tex);
		if (ssrColor.w - curPoint.z < 0.001 || curPoint.z < ssrColor.w) {
			res.xyz = ssrColor.xyz;
			res.w = 1;
			break;
		}
		curPoint += dir * 1;
	}
	return res;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS( PS_INPUT input) : SV_Target
{
	float4 f = abs(input.NormW);

	float2 tex1 = input.Tex + float2(gTime.x * 0.7, gTime.x * 0.5);
	float2 tex2 = input.Tex + float2(gTime.x * 0.4, gTime.x * 0.8);

	float4 c = txDiffuse.Sample(samLinear, tex1); // *vMeshColor;
	float4 c2 = txNormal.Sample(samLinear, tex2);
	float3 eye = gEye.xyz; //{ 0, 2, -10 };
	float3 at = input.PosW.xyz;
	float t = gTime.x;
	float3 wave_s = {-10, at.y, 10};
	float noise = gNoise.x;
	
	//at.y += 0.2 * sin(2 * at.x + 2 * t);// + 0.2 * sin(at.x + 3 * t) + sin(5 * t + length(at - wave_s)) * length(at - wave_s) / 80;
	
	//at.x += 0.2 * cos(2 * at.x + 2 * t);
	//at.y += sin(3 * t + at.x * 1 * (1));
	float3 viewTo = normalize(at - eye);
	float3 normal = input.NormW.xyz;

	/*input.NormW.x = 0 - 2 * cos(2 * at.x + 2 * t);
	input.NormW.y = 1 - 0.2 * 2 * sin(2 * at.x + 2 * t);
	input.NormW.z = 0;
	input.NormW = normalize(input.NormW);*/
	
	normal.x = 2 * c.x - 1;
	normal.y = 2 * c.z - 1;
	normal.z = 2 * c.y - 1;

	float3 normal2;
	normal2.x = 2 * c2.x - 1;
	normal2.y = 2 * c2.z - 1;
	normal2.z = 2 * c2.y - 1;

	normal = lerp(normal, normal2, 0.5);
	normal = lerp(normal, input.NormW.xyz, 1);// 0.85);
	
	normal = normalize(normal);
	
	float3 ref = reflect(viewTo, normal);
	float3 refr = (viewTo + normal) * 0.6 - normal;
	float ref_frac = 1 + dot(normal, viewTo);
	ref_frac = pow(ref_frac, 2);
	float4 water_c = {0.0, 0.2, 0.3, 0};

	// convert reflect vector to NDC space
	float4 dirNDC;
	float4 reflectToW = {ref - input.PosW.xyz, 1};
	float4 reflectToNDC = mul(reflectToW, View);
	reflectToNDC = mul(reflectToNDC, Projection);
	reflectToNDC.x /= reflectToNDC.w;
	reflectToNDC.y /= reflectToNDC.w;
	reflectToNDC.z /= reflectToNDC.w;
	reflectToNDC.w = 1;
	RayMarch(input.Pos, reflectToNDC);
	

	float4 reflect_color = txCube.Sample(samLinear, ref);
	if (reflect_color.w == 0)
		ref_frac = 0;

	c = reflect_color * ref_frac + txCube.Sample(samLinear, refr) * (1 - ref_frac) * 0.4 + water_c * (1 - ref_frac) * 0.6;
	/*c.x = c.x > 1 ? 1 : c.x;
	c.y = c.y > 1 ? 1 : c.y;
	c.z = c.z > 1 ? 1 : c.z;*/
	//c = txCube.Sample(samLinear, input.PosW);
	/*c.x = 0; c.y = 0; c.z = 0;
	c.y = txSSR.Sample(samLinear, tex1).w;*/
	return c;
}
