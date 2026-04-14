// Optimized for Mobile / Retro Arcade Style
shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx, unshaded;

instance uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const float nudge = 0.739513;   
const float normalizer = 1.0 / sqrt(1.0 + nudge*nudge);   

varying vec3 global_pos;

float SpiralNoiseC(vec3 p) {
    float n = 0.0; 
    float iter = 1.0;
    
    // OPTIMIZATION 1: Reduced from 8 to 4 iterations. 
    // This halves the cost of the noise generation immediately.
    for (int i = 0; i < 4; i++) { 
        n += -abs(sin(p.y*iter) + cos(p.x*iter)) / iter;    
        p.xy += vec2(p.y, -p.x) * nudge; 
        p.xy *= normalizer;
        p.xz += vec2(p.z, -p.x) * nudge; 
        p.xz *= normalizer;
        iter *= 1.733733; 
    }
    return n;
}

float NebulaNoise(vec3 p) {
    float final = p.y + 4.5;
    final -= SpiralNoiseC(p.xyz);   
    
    // OPTIMIZATION 2: Removed the second expensive SpiralNoiseC call.
    // Instead, we use a single, ultra-cheap sine wave for large scale variance.
    final += sin(p.z * 0.5 + 100.0) * 2.0; 
    return final;
}

float myMap(vec3 p) {
    // Adjusted the divisor slightly to compensate for the simpler noise
    float NebNoise = abs(NebulaNoise(p/0.8) * 0.5) + 0.03;
    return NebNoise;
}

void vertex() {
    global_pos = NODE_POSITION_WORLD;
}

void fragment() {
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 ray_dir = normalize(world_pos - CAMERA_POSITION_WORLD);
    
    vec4 sum = vec4(0.0);
    float d = 1.0, t = 0.0;
    float td = 0.0;
    float min_dist = 0.0, max_dist = 100.0;
    
    ALPHA = 0.0;
    t = min_dist * step(t, min_dist);
    
    // OPTIMIZATION 3: Reduced raymarch steps from 30 to 12.
    const int MAX_STEPS = 12; 
    
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 pos = world_pos + t * ray_dir;
        
        if(td > 0.9 || d < 0.1 * t || t > 10.0 || sum.a > 0.99 || t > max_dist) break;
        
        d = myMap(pos);
        d = max(d, 0.08); 
        
        vec3 ldst = global_pos - pos; 
        
        // OPTIMIZATION 4: dot() is much cheaper than length() * length().
        // length() uses a square root, which is slow on mobile GPUs. dot() bypasses it.
        float lDistSq = max(dot(ldst, ldst), 0.001); 
        
        // Adjusted the divisor from 30.0 to 12.0 to match the new step count
        sum.rgb += (albedo.rgb / lDistSq) / float(MAX_STEPS); 
        
        td += 1.0 / 70.0;
        d = max(d, 0.04); 
        
        // Slightly increased the minimum step size (0.02 to 0.05) to push the ray faster
        t += max(d * 0.1 * max(min(length(ldst), length(world_pos)), 1.0), 0.05); 
    }
    
    ALBEDO = sum.rgb; 
	ALBEDO *= t;
    ALPHA = ALBEDO.r; 
}