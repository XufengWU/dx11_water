//--------------------------------------------------------------------------------------
// File: skybox.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
Texture2D txDiffuse : register( t0 );
SamplerState samLinear : register( s0 );
TextureCube txCube : register(t1);

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
    float4 vMeshColor;
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
	float4 PosL : POSITION;
    float2 Tex : TEXCOORD0;
	float4 NormW : NORMAL0;
};

struct PS_OUTPUT
{
	float4 Color : SV_Target0;
	// ColorTx.xyz == color, ColorTx.w == depth
	float4 ColorTx : SV_Target1;
};

static matrix mIdentity = {
	1, 0, 0, 0,
	0, 1, 0, 0,
	0, 0, 1, 0,
	0, 0, 0, 1
};


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS( VS_INPUT input )
{
    PS_INPUT output = (PS_INPUT)0;
	//input.Pos.w = 1;
	output.PosL = mul(input.Pos, mIdentity);
	input.Pos.x *= 300;
	input.Pos.y *= 300;
	input.Pos.z *= 300;
	output.Pos = mul(input.Pos, World);
	//output.PosL = output.Pos;
    output.Pos = mul( output.Pos, View );
    output.Pos = mul( output.Pos, Projection );
	output.Pos.z = output.Pos.w * 0.9;
    output.Tex = input.Tex;
	float4 normW = { mul(input.Norm, World).xyz, 0 };
	output.NormW = normalize(normW);
    
    return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

//float4 PS( PS_INPUT input) : SV_Target
//{
//	float4 c = txCube.Sample(samLinear, input.PosL);
//	return c;
//}

PS_OUTPUT PS(PS_INPUT input)
{
	PS_OUTPUT pOut;

	float4 c = txCube.Sample(samLinear, input.PosL);
	pOut.Color = c;
	pOut.ColorTx = c;
	pOut.ColorTx.w = input.Pos.z; // 1 - input.Pos.z / input.Pos.w;
	return pOut;
}
