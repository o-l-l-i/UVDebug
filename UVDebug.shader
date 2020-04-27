Shader "Unlit/UVDebug"
{

    // UV Debug shader by Olli S.

    Properties
    {
        [Header(Tiling)]
        [IntRange] TILE_COUNT ("Pattern Tiling", range(2,32)) = 8
        [IntRange] SUBTILE_COUNT ("Checker Subdivisions", range(2,16)) = 4
        [Header(Colorization)]
        _Hue ("Pattern Hue", range(0,1)) = 0
        _Saturation ("Pattern Saturation", range(0,1)) = 0.95
        _Value ("Pattern Value", range(0,1)) = 0.95
        [Header(Geometry Patterns)]
        [Toggle(TOGGLE_CORNERS)] _ToggleCorners ("Toggle Corners", float) = 1
        [Toggle(TOGGLE_GRID)] _ToggleGrid ("Toggle Grid", float) = 1
        [Toggle(TOGGLE_CIRCLE)] _ToggleCircle ("Toggle Circle", float) = 1
        [Toggle(TOGGLE_DIAMOND)] _ToggleDiamond ("Toggle Diamond", float) = 1
        [Toggle(TOGGLE_DIRECTION)] _ToggleDirection ("Toggle Direction", float) = 1
        [Header(Tweaks)]
        _FadeChecker ("Fade Checker", range(0,1)) = 0.2
        _Contrast ("Contrast", Range(0,5)) = 1.0
        _Gamma ("Gamma", Range(0,5)) = 1.0
    }


    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // make fog work
            #pragma multi_compile_fog

            #pragma multi_compile __ TOGGLE_CORNERS
            #pragma multi_compile __ TOGGLE_GRID
            #pragma multi_compile __ TOGGLE_CIRCLE
            #pragma multi_compile __ TOGGLE_DIAMOND
            #pragma multi_compile __ TOGGLE_DIRECTION

            #include "UnityCG.cginc"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };


            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };


            // Used by color conversions
            static const float Epsilon = 1e-10;


            // Used by polygon math
            #define PI 3.14159265359
            #define TWO_PI 6.28318530718


            // Variables
            uint TILE_COUNT;
            uint SUBTILE_COUNT;
            float _FadeChecker;
            float _Hue;
            float _Saturation;
            float _Value;
            float _Contrast;
            float _Gamma;


            float3 HUEtoRGB(in float H)
            {
                float R = abs(H * 6 - 3) - 1;
                float G = 2 - abs(H * 6 - 2);
                float B = 2 - abs(H * 6 - 4);
                return saturate(float3(R,G,B));
            }


            float3 HSVtoRGB(in float3 HSV)
            {
                float3 RGB = HUEtoRGB(HSV.x);
                return ((RGB - 1) * HSV.y + 1) * HSV.z;
            }


            float Bw(float3 col)
            {
                return float(col.r * 0.299 + col.g * 0.587 + col.b * 0.114);
            }


            float3 Contrast(float3 color, float contrast)
            {
                return saturate(lerp(float3(0.5, 0.5, 0.5), color.rgb, contrast));
            }


            float3 Gamma(float3 color, float gamma)
            {
                return color.rgb = pow(color.rgb, gamma);
            }


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                // Init color
                fixed4 col = 0;

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                // Scaled UVs, to fit tile size
                float2 scaledUV = i.uv * TILE_COUNT;

                // Inside tile UVs
                float2 tileUV = frac(i.uv * TILE_COUNT);

                // Generate checkerboard UV
                float2 checkerUV = floor(i.uv * TILE_COUNT * SUBTILE_COUNT);

                // Draw colorful tiles
                float2 tiled = floor(scaledUV);
                float pattern = (tiled.x + tiled.y) % TILE_COUNT;
                pattern /= TILE_COUNT;
                pattern = frac(pattern + _Hue);

                // Mix color tiles
                col.rgb = HSVtoRGB(float3(pattern, _Saturation, _Value));

                // Adjust contrast / gamma
                col.rgb = Contrast(col.rgb, _Contrast);
                col.rgb = Gamma(col.rgb, _Gamma);

            #ifdef TOGGLE_CORNERS
                // Top right white box
                float cornerTopRight = 1.0 - (step(TILE_COUNT-1, scaledUV.x) && step(TILE_COUNT-1, scaledUV.y));
                // Conditinally blend to the corner
                float3 cornerTopRightCol = lerp(col.rgb, 1, 1-cornerTopRight);
                col.rgb = cornerTopRightCol;

                // Bottom left grey box
                float cornerBotLeft = step(1, scaledUV.x) || step(1, scaledUV.y);
                // Conditinally blend to the corner
                float3 cornerBotLeftCol = lerp(col.rgb, 0.1, 1-cornerBotLeft);
                col.rgb = cornerBotLeftCol;

                // Top left tri
                float cornerTopLeft = step(1, scaledUV.x) || step(scaledUV.y, TILE_COUNT-1);
                int N = 3;
                float2 polyUVTri = tileUV - 0.5;
                float a = atan2(polyUVTri.x, polyUVTri.y) + PI;
                float r = TWO_PI/float(N);
                float d = cos(floor(0.5 + a/r) * r - a) * length(polyUVTri);
                float poly = smoothstep(0.2, 0.22, d);
                // Conditinally blend to the corner
                float3 cornerTopLeftCol = lerp(col.rgb, poly, 1.0-cornerTopLeft);
                col.rgb = cornerTopLeftCol;

                // Bottom right hex
                float2 polyUVHex = tileUV - 0.5;
                N = 6;
                a = atan2(polyUVHex.x, polyUVHex.y) + PI;
                r = TWO_PI/float(N);
                d = cos(floor(0.5 + a/r) * r - a) * length(polyUVHex);
                poly = smoothstep(0.25, 0.26, d);
                float cornerBotRight = 1 - (step(TILE_COUNT-1, scaledUV.x) && step(scaledUV.y, 1));
                // Colorize polygon
                float3 coloredPoly = lerp(float3(0,1,0), 0.1, poly);
                // Conditinally blend to the corner
                float3 cornerBotRightCol = lerp(col.rgb, coloredPoly, 1.0-cornerBotRight);
                col.rgb = cornerBotRightCol;
            #endif


                // Draw checker
                if (_FadeChecker > 0.0)
                {
                    float checker = (checkerUV.x + checkerUV.y) % 2;

                    // Mix checker
                    checker = lerp(1.0, checker, _FadeChecker);
                    col.rgb *= checker;
                }

                // Draw grid
            #ifdef TOGGLE_GRID
                float2 gridcell = frac(scaledUV.xy);
                float deltaGrid = min(fwidth(gridcell.x), fwidth(gridcell.y));
                float gt = 0.005;
                float gs = 0.005 + deltaGrid;
                float grid = smoothstep(gt, gt+gs, gridcell.x) * smoothstep(1.0-gt, 1.0-gt-gs, gridcell.x) *
                             smoothstep(gt, gt+gs, gridcell.y) * smoothstep(1.0-gt, 1.0-gt-gs, gridcell.y);

                // Mix grid
                col.rgb *= grid;
            #endif

                float2 tileCenter = float2(0.5, 0.5);

                // Draw circle
            #ifdef TOGGLE_CIRCLE
                float dist = distance(tileUV.xy, tileCenter);
                float deltaDist = fwidth(dist);
                float cr = 0.49;
                float ct = 0.004;
                float cs = 0.01 + deltaDist;
                float circleInner = smoothstep(cr-ct, cr-ct-cs, dist);
                float circleOuter = smoothstep(cr+ct+cs, cr+ct, dist);
                // Define ring
                float ring = saturate(1.0 + circleInner - circleOuter);

                // Mix ring
                col.rgb *= ring;
            #endif

                // Diamond
            #ifdef TOGGLE_DIAMOND
                float diamond = dot(abs(tileUV - tileCenter), 1.0);
                float deltaDiamond = fwidth(diamond);
                float dr = 0.45;
                float dt = 0.01;
                float ds = 0.01 + deltaDiamond;
                diamond = 1.0 - (smoothstep(dr-dt*2-ds, dr-dt, diamond) - smoothstep(dr-dt, dr+ds, diamond));

                // Mix diamond
                col.rgb *= diamond;
            #endif

                // Render arrows
            #ifdef TOGGLE_DIRECTION
                float abw = 0.45;
                float abt = 0.4;
                float abb = 0.2;
                float abh = 0.1;
                float as = 0.01;
                // Arrow body
                float arrowBody = max(
                                        max(smoothstep( abw+as, abw, tileUV.x), smoothstep(abw+as, abw, 1.0 - tileUV.x)),
                                        max(smoothstep( abb+as, abb, tileUV.y), smoothstep(abt+as, abt, 1.0 - tileUV.y))
                                     );
                // Arrow head
                float2 arrowUV = tileUV - 0.5;

                arrowUV.y -= 0.15;
                arrowUV.x *= 1.25;
                int _N = 3;
                float _a = atan2(arrowUV.x, arrowUV.y) + PI;
                float _r = TWO_PI/float(_N);
                float _d = cos(floor(0.5 + _a/_r) * _r - _a) * length(arrowUV);
                float _head = smoothstep(abh, abh+as, _d);
                // Combine body and head
                arrowBody *= _head;
                // Colorize arrow
                float3 arrowCol = lerp(float3(1,1,1), float3(0,0,0), smoothstep(0.505, 0.495, tileUV.x));

                // Combine to color
                col.rgb = lerp(arrowCol.rgb, col.rgb, arrowBody);
            #endif

                return col;

            }
            ENDCG
        }
    }

}
