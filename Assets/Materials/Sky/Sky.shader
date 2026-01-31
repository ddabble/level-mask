Shader "Custom/Sky"
{
    Properties
    {
        // =========================
        // Color
        // =========================
        _CloudColor ("Cloud Color", Color) = (0.8, 0.8, 0.8, 1)
        _TopColor ("Top Color", Color) = (0.026, 0.463, 0.76, 1)
        _HorizonColor ("Horizon Color", Color) = (0.786, 0.586, 0.698, 1)
        _BottomColor ("Bottom Color", Color) = (0.115, 0.123, 0.416, 1)
        _GroundHorizonColor ("Ground Horizon Color", Color) = (0.94, 0.589, 0.81, 1)

        // 

        // =========================
        // Cloud Parameters
        // =========================
        _CloudsEnabled ("Clouds Enabled", Float) = 1
        _CloudsStartHeight ("Clouds Start Height", Float) = 200
        _CloudsEndHeight ("Clouds End Height", Float) = 240
        _MinMarchSteps ("Min March Steps", Float) = 70
        _MaxMarchSteps ("Max March Steps", Float) = 120
        _LightMarchSteps ("Light March Steps", Float) = 5
        _DensityFactor ("Density Factor", Float) = 1
        _BeersInputFactor ("Beers Input Factor", Float) = 0.1
        _BeersOutputFactor ("Beers Output Factor", Float) = 0.3
        _ErosionFactor ("Erosion Factor", Float) = 0.4
        _LightBoost ("Light Boost", Float) = 40
        _WindSpeed ("Wind Speed", Vector) = (-0.4, 0, 0, 0)

        // =========================
        // Other Parameters
        // =========================
        _Creepiness ("Creepiness", Float) = 0

        // =========================
        // Noise Volumes
        // =========================
        _PerlinVolume ("Perlin Volume", 3D) = "" {}
        _WorleyVolumeFBM ("Worley FBM Volume", 3D) = "" {}
        _WorleyVolumeEroder ("Worley Eroder Volume", 3D) = "" {}

        // LIGHT
        _PlayerPosition ("Player Position", Vector) = (0, 0, 0)

    }

    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
            };

            // =========================
            // Uniforms
            // =========================

            float4 _CloudColor;
            float4 _TopColor;
            float4 _HorizonColor;
            float4 _BottomColor;
            float4 _GroundHorizonColor;

            float _CloudsEnabled;
            float _CloudsStartHeight;
            float _CloudsEndHeight;
            float _MinMarchSteps;
            float _MaxMarchSteps;
            float _LightMarchSteps;
            float _DensityFactor;
            float _BeersInputFactor;
            float _BeersOutputFactor;
            float _ErosionFactor;
            float _LightBoost;
            float4 _WindSpeed;

            float _Creepiness;
            float3 _PlayerPosition;

            TEXTURE3D(_PerlinVolume);
            SAMPLER(sampler_PerlinVolume);
            TEXTURE3D(_WorleyVolumeFBM);
            SAMPLER(sampler_WorleyVolumeFBM);
            TEXTURE3D(_WorleyVolumeEroder);
            SAMPLER(sampler_WorleyVolumeEroder);

            #define TIME _Time.y

            // =========================
            // Vertex
            // =========================

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.viewDir = v.vertex.xyz;
                o.pos = TransformObjectToHClip(v.vertex);

                return o;
            }

            // =========================
            // Utility
            // =========================

            // Maps x from range [fromMin, fromMax] to [toMin, toMax]
            float remap(float x, float fromMin, float fromMax, float toMin, float toMax)
            {
                return (((x - fromMin) / (fromMax - fromMin)) * (toMax - toMin)) + toMin;
            }

            // =========================
            // Fragment
            // =========================

            float3 gamma_correct(float3 color)
            {
                return pow(color, float3(1,1,1)/2.2);
            }


            #ifdef RUNTIME_NOISE
            float cloud_density(float3 original_point)
            {
                float3 p = original_point * .01;
                p.xz += TIME*_WindSpeed*.1;
                p.y += TIME*.005;

                float perlin = perlin_3d_noise(p, 1., 3, .5, 2.);

                float worley = 1. - worley_3D(p, float3(.2), 1.,TIME*.01);
                float perlin_worley = remap(perlin, 0., 1., worley*.7, 1.) - worley_3D(p+float3(13,19,15), float3(.15), 1.,TIME*.03)*_ErosionFactor;
                // Cloud height shape
                float cloud_layer_height = _CloudsEndHeight - _CloudsStartHeight;
                perlin_worley *= smoothstep(_CloudsEndHeight, _CloudsStartHeight + cloud_layer_height*.1, original_point.y);
                return clamp(perlin_worley, 0.0, 1.0);
            }
            #else
            float cloud_density(float3 original_point)
            {
                float3 p = original_point * .001;
                p.xz += TIME*_WindSpeed*.1;
                p.y += TIME*.005;

                // TODO erstatt tex3D()-kall med SampleLevel likevel...
                // Combine perlin and worley noise for cauliflower-esque cloud shape
                float perlin = _PerlinVolume.SampleLevel(sampler_PerlinVolume, p, 0).r;
                float worley = 1. - _WorleyVolumeFBM.SampleLevel(sampler_WorleyVolumeFBM, p, 0).r;
                float density = remap(perlin, 0., 1., worley*.7, 1.);

                // Erode with other, lower detail worley noise
                density -= _WorleyVolumeEroder.SampleLevel(sampler_WorleyVolumeEroder, p*.2+float3(.1,.2,0.+.001*TIME), 0).r*_ErosionFactor;

                // Cloud height shape
                // TODO better shape, smoothstep doesn't cut it -_-
                float cloud_layer_height = _CloudsEndHeight - _CloudsStartHeight;
                density *= smoothstep(_CloudsEndHeight, _CloudsStartHeight + cloud_layer_height*.1, original_point.y);
                return clamp(density, 0.0, 1.0);
            }
            #endif

            // Phase function figured out by giants
            float henyey_greenstein(float dotlight, float g)
            {
                const float one_over_4pi = 0.0795774715459; // 1 / (4pi)
                return one_over_4pi * (1.0 - g*g) / (pow(1.0 + g*g - 2.0*g * dotlight, 1.5));
            }

            // Better phase function than pure henyey-greenstein
            float phase(float dotlight, float c, float mix_factor)
            {
                return lerp(henyey_greenstein(dotlight, -c), henyey_greenstein(dotlight, c), mix_factor);
            }

            float beers_powder(float d)
            {
                d = d*_BeersInputFactor;
                float beers = exp(-d);
                float powder = 1.0 - exp(-2.0*d);
                return beers*powder*_BeersOutputFactor;
            }

            float beers(float d)
            {
                return exp(-d);
            }

            // Simple gradient atmosphere
            // TODO improve atmosphere :/
            float3 render_background(float3 ray_dir)
            {
                float dotup = dot(float3(0, 1, 0), ray_dir) + .5;
                return lerp(_HorizonColor, _TopColor, smoothstep(.01, .55, dotup*dotup));
            }

            // Multi-octave scattering thingy from some paper
            float light_scatter(float light_density, float dotlight)
            {
                const float attenuation = 0.2;
                const float contribution = 0.4;
                const float phase_attenuation = 0.1;
                float a = 1., b = 1., c = 1., g = 0.85;

                float luminance = 0.0;
                for (int i = 0; i < 4; i++)
                {
                    float p = phase(dotlight, c, g);
                    float beers = beers_powder(light_density * a);
                    luminance += b * p * beers;
                    a *= attenuation;
                    b *= contribution;
                    c *= 1. - phase_attenuation;
                }
                return luminance;
            }

            float4 march_clouds(float3 ray_origin, float3 ray_dir, int steps, float step_size)
            {
                // Raytrace to sky threshold
                float distance_to_sky = float(ray_origin.y < _CloudsStartHeight) * (_CloudsStartHeight - ray_origin.y)/ray_dir.y;
                float3 p = ray_origin + distance_to_sky*ray_dir;

                // Setup light parameters
                float cloud_layer_height = _CloudsEndHeight - _CloudsStartHeight;
                float light_step = cloud_layer_height / 30.;
                float distant_light_step = cloud_layer_height * .3;
                int light_steps = int(_LightMarchSteps);

                Light sun = GetMainLight();

                // Phase stuff
                float3 ld = sun.direction;
                float dotlight = dot(ray_dir, ld);
                float ray_phase = phase(dotlight, .4, .1);

                // Other setup
                float dist = 0.;
                float4 color = float4(0,0,0,0);
                float transmittance = 1.;

                [loop]
                for (int i = 0; i < steps; i++)
                {
                    // No need to continue at max alpha
                    if (color.a >= 1.)
                        break;

                    // Step onwards!
                    // TODO try stepping fast when outside cloud and slow inside (backtrack when inside)
                    //   -> tried once, was unsuccessful
                    p += step_size * ray_dir;
                    dist += step_size;

                    // Sample clouds!
                    float density = cloud_density(p);

                    // Diminish transmittance (applies to both color and alpha gain)
                    // Don't ask me how I came up with the factors here lol
                    float transmittance_step = beers_powder(density*dist);
                    transmittance = transmittance_step;

                    // Step onwards immediately if not inside cloud
                    if (density < 0.)
                        continue;

                    // Sample light!
                    float3 lp = p;
                    float light_density = 0.;
                    for (int j = 0; j < light_steps; j++)
                    {
                        // TODO should jitter direction
                        // Final sample is distant
                        lp += (j < light_steps - 1 ? light_step : distant_light_step) * ld;
                        light_density += 1. - cloud_density(p);
                    }

                    // TODO had to boost light with configurable factor since it didn't do much
                    float luminosity = light_scatter(light_density, dotlight);
                    float3 light_contribution = sun.color * luminosity * ray_phase * color.a * _LightBoost;

                    color.rgb += (_CloudColor + light_contribution) * transmittance * _DensityFactor * density;
                    color.a += transmittance * (1. - color.a);
                }

                // Post-process the cloud color a little (otherwise it turns weird)
                return float4(gamma_correct(color.rgb), color.a);
            }

            // Add to color
            float3 render_sun(float dotsun)
            {
                float sharpsun = smoothstep(.9997, 1., dotsun);
                float blurrysun = smoothstep(.99, 1., dotsun);
                float3 sun = GetMainLight().color;
                return (
                    sun * 100. * sharpsun +
                    sun * .5 * blurrysun*blurrysun*blurrysun
                );
            }

            // Add to color
            float3 render_creepy_stuff(float dotsun)
            {
                float3 creepy = float3(2,2,2) * min(-.3, dotsun*.4);
                return lerp(float3(0,0,0), creepy, _Creepiness);
            }

            float3 render_sky(float3 pos, float3 eyedir)
            {
                Light sun = GetMainLight();
                // TODO correct dir???
                float3 sun_direction = sun.direction;
                float dotsun = dot(sun_direction, eyedir);
                if (eyedir.y < 0.01)
                    return render_background(eyedir) + render_sun(dotsun) + render_creepy_stuff(dotsun);

                float3 background = render_background(eyedir);
                float3 color;

                // TODO ideally this should be done via preprocessor directives
                // but godot doesn't support setting #defines dynamically AFAIK
                // so we'll have to do some custom shenanigans to achieve the same non-branching result :/
                // Probably negligible compared to doing full steps.
                if (_CloudsEnabled)
                {
                    float dotup = dot(float3(0, 1, 0), eyedir);
                    float steps = lerp(_MinMarchSteps, _MaxMarchSteps, smoothstep(.9, .4, dotup));
                    // Trig for step size (TODO: replace when we disk)
                    float height_to_sample = _CloudsEndHeight - _CloudsStartHeight;
                    float sample_distance = height_to_sample/dotup;
                    float step_size = sample_distance/steps;

                    float4 clouds = march_clouds(pos, eyedir, int(steps), step_size);

                    // Mix clouds onto background based on both cloud alpha and horizion angle
                    // Current mix method works much better than before 😅
                    float3 sky_color = background + clouds.rgb*clouds.a;
                    color = lerp(background, sky_color, smoothstep(.01, .15, dotup));
                }
                else
                {
                    color = background;
                }

                color += render_sun(dotsun);
                color += render_creepy_stuff(dotsun);

                return color;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 dir = normalize(i.viewDir);
                // TODO må sende inn spillerposisjonen
                float3 pos = _PlayerPosition;
                // return float4(i.uv, 0, 1);
                // return float4(i.viewDir, 1);

                // TODO half res stuff???
                // if (AT_CUBEMAP_PASS)
                // {
                //     // Avoid rendering clouds for reflections
                //     COLOR = render_background(EYEDIR);
                //     ALPHA = 1.0;
                // }
                // // TODO considering having another shader variant for quarter res
                // //   -> should look better than reducing step count
                // else if (AT_HALF_RES_PASS && !AT_CUBEMAP_PASS)
                // {
                //     // Render clouds at half resolution
                    // COLOR = render_sky(EYEDIR);
                    // ALPHA = 1.0;
                // }
                // else
                // {
                //     // Then use result at full
                //     COLOR = HALF_RES_COLOR.rgb;
                // }

                return float4(render_sky(pos, dir), 1);
            }
            ENDHLSL
        }
    }
}