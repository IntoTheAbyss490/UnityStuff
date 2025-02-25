Shader "Custom/OptimizedWater_VR"
{
    Properties
    {
        _WaveSize ("Wave Size", Range(0.01, 2)) = 0.5
        _WaveHeight ("Wave Height", Range(0, 2)) = 0.5
        _WaveSpeed ("Wave Speed", Range(0, 5)) = 1.0

        _ReflectionIntensity ("Reflection Intensity", Range(0, 1)) = 0.5
        _FogColor ("Fog Color", Color) = (0.2, 0.4, 0.6, 1)
        _FogDensity ("Fog Density", Range(0, 1)) = 0.2

        _DissolveAmount ("Dissolve Amount", Range(0,1)) = 0.0
        _DissolveTexture ("Dissolve Texture", 2D) = "white" {}

        [Toggle] _UseGeneratedNoise ("Use Generated Noise", Float) = 1
        _NoiseTexture ("Noise Texture", 2D) = "white" {}
        _RandomSeed ("Noise Seed", Float) = 0.5

        [Toggle] _WaterVisibility ("Water Visibility", Float) = 1
        [Toggle] _UseReflections ("Use Reflections", Float) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Cull Off
            ZWrite On
            ZTest LEqual

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO

            #include "UnityCG.cginc"

            sampler2D _NoiseTexture, _DissolveTexture;
            #if defined(UNITY_SINGLE_PASS_STEREO) || defined(UNITY_PASS_FORWARDBASE)
            sampler2D _CameraOpaqueTexture;
            #endif

            float _WaveSize, _WaveHeight, _WaveSpeed;
            float _ReflectionIntensity, _FogDensity;
            float _DissolveAmount, _RandomSeed;
            float _UseGeneratedNoise;
            float _WaterVisibility, _UseReflections;
            float4 _FogColor;

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
            };

            v2f vert (appdata_t v)
            {
                v2f o;
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));

                // Apply wave displacement
                float noise = 0.0;
                if (_UseGeneratedNoise > 0.5) 
                {
                    noise = tex2Dlod(_NoiseTexture, float4(o.uv * _WaveSize, 0, 0)).r;
                    noise = noise * 2.0 - 1.0;
                }
                v.vertex.y += noise * _WaveHeight;

                o.pos = UnityObjectToClipPos(v.vertex);
                
                // Adjust screen position for VR
                o.screenPos = ComputeGrabScreenPos(o.pos);
                o.screenPos.xy = UnityStereoScreenSpaceUVAdjust(o.screenPos.xy, o.screenPos.w);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                if (_WaterVisibility < 0.5) return fixed4(0, 0, 0, 1); // Hide water by rendering black

                // Dissolve effect
                float dissolveNoise = tex2D(_DissolveTexture, i.uv).r;
                float dissolveFactor = smoothstep(_DissolveAmount, _DissolveAmount + 0.1, dissolveNoise);

                // Depth-based fog blending
                float depthFactor = saturate(i.worldPos.y * _FogDensity);
                fixed4 baseColor = lerp(_FogColor, fixed4(0.0, 0.5, 1.0, 1.0), depthFactor);
                baseColor.rgb *= dissolveFactor;

                // Reflections (only if enabled)
                if (_UseReflections > 0.5)
                {
                    float2 screenUV = i.screenPos.xy / i.screenPos.w;
                    float4 reflectionColor = tex2D(_CameraOpaqueTexture, screenUV);
                    
                    // Fresnel effect for reflection intensity
                    float fresnel = pow(1.0 - saturate(dot(i.viewDir, float3(0,1,0))), 3.0);
                    float reflectionFactor = fresnel * _ReflectionIntensity;
                    baseColor = lerp(baseColor, reflectionColor, reflectionFactor);
                }

                return baseColor;
            }
            ENDCG
        }
    }

    FallBack "Diffuse"
}
