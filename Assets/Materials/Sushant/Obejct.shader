Shader "Custom/WireframeGlowWithFog"
{
    Properties
    {
        _MainColor     ("Main Color",      Color) = (0,0,0,1)
        _WireColor     ("Wire Color",      Color) = (0,0,1,1)
        _WireThickness ("Wire Thickness",  Range(0,0.1)) = 0.01
        _GlowIntensity ("Glow Intensity",  Range(0,10))  = 4
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            // --- CORE PRAGMAS ---
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            // --- APPDATA ---
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            // Vertex→Geom struct: carry clip‐pos, UV, and fogCoord
            struct v2g
            {
                float4 pos      : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float  fogCoord : TEXCOORD1; // will store fog factor
            };

            // Geometry→Frag struct: carry pos, UV, edge‐distances, plus fogCoord
            struct g2f
            {
                float4 pos      : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float3 dist     : TEXCOORD1;
                float  fogCoord : TEXCOORD2;
            };

            // Shader parameters
            float4 _MainColor;
            float4 _WireColor;
            float  _WireThickness;
            float  _GlowIntensity;

            // VERTEX: compute clip‐pos and fog factor
            v2g vert(appdata IN)
            {
                v2g OUT;
                OUT.pos      = UnityObjectToClipPos(IN.vertex);
                OUT.uv       = IN.uv;
                UNITY_TRANSFER_FOG(OUT, OUT.pos); // writes OUT.fogCoord
                return OUT;
            }

            // GEOMETRY: do your wireframe distance calc, copy fogCoord along
            [maxvertexcount(3)]
            void geom(triangle v2g IN[3], inout TriangleStream<g2f> stream)
            {
                // precompute screen‐space edge info
                float2 p0 = IN[0].pos.xy / IN[0].pos.w;
                float2 p1 = IN[1].pos.xy / IN[1].pos.w;
                float2 p2 = IN[2].pos.xy / IN[2].pos.w;
                float2 v0 = p2 - p1, v1 = p0 - p2, v2 = p1 - p0;
                float area = abs(v1.x*v2.y - v1.y*v2.x);

                // emit each vertex
                for (int i = 0; i < 3; ++i)
                {
                    g2f OUT;
                    OUT.pos      = IN[i].pos;
                    OUT.uv       = IN[i].uv;
                    OUT.fogCoord = IN[i].fogCoord; // copy from v2g

                    // choose the correct edge‐distance channel
                    if (i == 0)       OUT.dist = float3(area/length(v0), 0, 0);
                    else if (i == 1)  OUT.dist = float3(0, area/length(v1), 0);
                    else              OUT.dist = float3(0, 0, area/length(v2));

                    stream.Append(OUT);
                }
            }

            // FRAGMENT: blend main↔wire colors, then apply fog
            fixed4 frag(g2f IN) : SV_Target
            {
                float minDist  = min(min(IN.dist.x, IN.dist.y), IN.dist.z);
                float intensity= exp2(-4 * minDist / _WireThickness);
                fixed4 col     = lerp(_MainColor, _WireColor * _GlowIntensity, intensity);

                UNITY_APPLY_FOG(IN.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
