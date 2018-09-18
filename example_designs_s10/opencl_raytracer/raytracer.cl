// Copyright (C) 2013-2014 Altera Corporation, San Jose, California, USA. All rights reserved.
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
// whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// 
// This agreement shall be governed in all respects by the laws of the State of California and
// by the laws of the United States of America.

// Data structure definitions
// Match the ones in the host code
struct ray {
  float3 orig, dir;
};

struct material {
  float4 col;  /* color is float3, .w is spow */
};
struct sphere {
  float4 pos;  /* .w is rad */
  struct material mat;
};

struct spoint {
  float3 pos, normal, vref;  /* position, normal and view reflection */
  float dist;                /* parametric distance of intersection along the ray */
};

struct camera {
  float3 pos, targ;
  float fov;
};



#define DOT(a,b) ((a).x*(b).x + (a).y*(b).y + (a).z*(b).z)

// similar to fmin/fmax but no special NaN treatment, so a bit smaller.
#define MIN(a,b) ((a)<(b) ? (a) : (b))
#define MAX(a,b) ((a)>(b) ? (a) : (b))

// normalize given 3-vector in-place.
#define NORMALIZE(a)  do {\
  float len_inv = rsqrt(DOT(a, a));\
  (a).x *= len_inv; (a).y *= len_inv; (a).z *= len_inv;\
} while(0);


// Error margin to avoid surface acne. 
// Function of precision used by underlying data type (i.e. should be
// much smaller for 'double' computations).
#define ERR_MARGIN  1.0e-4f    
                                
// Handy macro for a lot of squaring
#define SQ(x)    ((x) * (x))

// bit-packing of RGB values into an integer.
// top-most 8 bits are unused.
#define RSHIFT      16
#define GSHIFT      8  
#define BSHIFT      0

// 1/(FOV/2), where FOV is field-of-view in radians (pi/4).
#define HALF_FOV_INV    (8.0f * (float)M_1_PI)

// trace rays of this magnitude
#define RAY_MAG      1000.0f


// Simpler and smaller version of pown.
// For this application, we know that 'b' will be at most 80 (by examining 
// the scene files). So having repeated multiple calls is sufficient. If 
// the range of 'b' were unknown, sticking to default implementation of pown() 
// would be better.
float my_pown (float a, short b) {
  float res = 1.0f;
  float ap = a;
  #pragma unroll
  for (int i = 0; i<= 7; i++) {
    if (b & 0x1) {
      res *= ap;
    }
    ap *= ap;
    b >>= 1;
  }
  return res;
}

/* determine the primary ray corresponding to the specified pixel (x, y) */
struct ray get_primary_ray (int x, int y, 
          float8 m,
          float4 dir_z_part,
          float4 camera_pos,
          float xres_inv, float yres_inv, float aspect_inv) {

  struct ray ray;
  float3 dir;
  
  dir.x =   ((float)x * xres_inv) - 0.5f;
  dir.y = -(((float)y * yres_inv) - 0.65f) * aspect_inv;
  dir.z = HALF_FOV_INV;
  dir *= RAY_MAG;

  ray.dir.x = dir.x * m.s0 + dir.y * m.s1 + dir_z_part.x;
  ray.dir.y = dir.x * m.s3 + dir.y * m.s4 + dir_z_part.y;
  ray.dir.z = dir.x * m.s6 + dir.y * m.s7 + dir_z_part.z;

  ray.orig.x = camera_pos.x;
  ray.orig.y = camera_pos.y;
  ray.orig.z = camera_pos.z;

  return ray;
}

struct ray get_shadow_ray (struct spoint const *cur_sp, __global float4 const *light)
{
  struct ray cur_ray;
  float3 sp_pos = cur_sp->pos;
  float3 ldir;
  ldir.x = light[0].x - sp_pos.x;
  ldir.y = light[0].y - sp_pos.y;
  ldir.z = light[0].z - sp_pos.z;
  
  cur_ray.orig = sp_pos;
  cur_ray.dir = ldir;
  
  return cur_ray;
}

int get_closest_sphere (
      struct ray const *cur_ray, __global struct sphere const *spheres,
      int numSpheres,
      float *min_dist_res,
      float3 *closest_sph_pos_res, float *closest_sph_rad_res,
      struct material *closest_sph_mat_res)
{
  float3  closest_sph_pos;
  float  closest_sph_rad;
  struct material closest_sph_mat;

  float min_dist = 1.0e+9f;
  int closest_sphere = -1;

  for(int i = 0; i < numSpheres; i++)
  {
    struct sphere cur_sph = spheres[i];
    float a, b, c;
    // Solve quadratic equation to find if given ray intersects current sphere
    a = SQ(cur_ray->dir.x) + SQ(cur_ray->dir.y) + SQ(cur_ray->dir.z);
    b = 2.0f *  (cur_ray->dir.x * (cur_ray->orig.x - cur_sph.pos.x) +
                 cur_ray->dir.y * (cur_ray->orig.y - cur_sph.pos.y) +
                 cur_ray->dir.z * (cur_ray->orig.z - cur_sph.pos.z));
    c = SQ(cur_sph.pos.x) + SQ(cur_sph.pos.y) + SQ(cur_sph.pos.z) +
        SQ(cur_ray->orig.x) + SQ(cur_ray->orig.y) + SQ(cur_ray->orig.z) +
        2.0f * (-cur_sph.pos.x * cur_ray->orig.x - 
                 cur_sph.pos.y * cur_ray->orig.y - 
                 cur_sph.pos.z * cur_ray->orig.z) -
        SQ(cur_sph.pos.w); // cur_sph.rad

    float d;
    if(!((d = SQ(b) - 4.0f * a * c) < 0.0f)) 
    {  
      float sqrt_d = sqrt(d);
      float two_a_inv = 0.5f / a;
      float t1 = (-b + sqrt_d) * two_a_inv;
      float t2 = (-b - sqrt_d) * two_a_inv;

      if(!((t1 < ERR_MARGIN && t2 < ERR_MARGIN) || (t1 > 1.0f && t2 > 1.0f))) 
      {
        if(t1 < ERR_MARGIN) t1 = t2;
        if(t2 < ERR_MARGIN) t2 = t1;
        float temp_dist = t1 < t2 ? t1 : t2;
        if(temp_dist < min_dist)
        {
          min_dist = temp_dist;   
          closest_sphere = i;
          closest_sph_pos = as_float3(cur_sph.pos);
          closest_sph_rad = cur_sph.pos.w; // cur_sph.rad;
          closest_sph_mat = cur_sph.mat;
        }
      }
    }
  }

  *min_dist_res = min_dist;
  *closest_sph_pos_res = closest_sph_pos;
  *closest_sph_rad_res = closest_sph_rad;
  *closest_sph_mat_res = closest_sph_mat;
  return closest_sphere;
}


struct spoint get_spoint (struct ray *cur_ray, float min_dist, 
        float3 closest_sph_pos, float closest_sph_rad)
{
  struct spoint cur_sp;
  cur_sp.pos = cur_ray->orig + cur_ray->dir * min_dist;

  float cur_sph_rad_inv = 1.0f / closest_sph_rad;
  cur_sp.normal = (cur_sp.pos - closest_sph_pos) * cur_sph_rad_inv;

  float dotp = 2.0f * DOT(cur_ray->dir, cur_sp.normal);
  cur_sp.vref = -(dotp * cur_sp.normal - cur_ray->dir);

  NORMALIZE(cur_sp.vref);
  return cur_sp;
}

// convert given float to integer in [0,255] range
unsigned int convert_to_range (float x)
{
  return (unsigned int)(MIN(x, 1.0f) * 255.0f) & 0xff;
}


__kernel void ray_sphere (
  // input data
  __global struct sphere const * restrict spheres,
  __global float4 const * restrict lights,
  int numSpheres,
  int numLights,
  
  /* pre-computed work-item invariant values */
  float8  camera_m,
  float4  dir_z_portion,
  float4 camera_pos,
  float xres_inv,    // 1/xres
  float yres_inv,    // 1/yres
  float aspect_inv,  // yres/xres
  
  // output
  __global unsigned int * restrict pixels_out)
{

  // linearized index
  int idx = get_global_id(1) * get_global_size(0) + get_global_id(0);

  // (x,y) get primary ray
  struct ray cur_ray = get_primary_ray(get_global_id(0), get_global_id(1),
               camera_m, dir_z_portion, camera_pos,
               xres_inv, yres_inv, aspect_inv);

  // The purpose of the iShare loop is to share call to get_closest_sphere().
  // What complicates things is that on first iteration it is called only once.
  // On second iteration (for shadow rays), it is called numLights times.
  float3 col;  
  col.x = col.y = col.z = 0.0f;
  struct spoint  cur_sp;
  struct material closest_sph_mat;
  #pragma unroll 1
    for (int iLight = 0; iLight < numLights+1; iLight++) {
      int iShare = iLight;
    	
      // (x,y) primary ray -> sps, sphere[z].mat
      float3  closest_sph_pos;
      float  closest_sph_rad;
      
      float  min_dist;
      
      int closest_sphere;
      struct ray cur_shadow_ray;
      
      struct ray ray_to_use;
      struct material mat_to_use;
    	
      if (iShare == 0) {
        ray_to_use = cur_ray;
      } else {
        // (x,y, l) sps, lights -> shadow ray
        cur_shadow_ray = get_shadow_ray (&cur_sp, lights + iLight-1);
        ray_to_use = cur_shadow_ray;
      }
    
      closest_sphere = get_closest_sphere (
            &ray_to_use, spheres, numSpheres,
            &min_dist, &closest_sph_pos, &closest_sph_rad,
            &mat_to_use);

      if (iShare == 0) {
        // primary ray logic
        closest_sph_mat = mat_to_use;
        cur_sp = get_spoint (&cur_ray, min_dist, closest_sph_pos, closest_sph_rad);
      } else {
        // shadow ray logic
      
        // (x,y, l) shadow ray -> in_shadow
        char in_shadow = (closest_sphere != -1);
    
        // (x,y, l) in_shadow, sps, spheres[z].mat -> pixels
        if (!in_shadow) {
          float3 cur_ldir = cur_shadow_ray.dir;
          NORMALIZE(cur_ldir);
          float idiff = MAX(DOT(cur_sp.normal, cur_ldir), 0.0f);
          float ispec = 0.0f;
          float spow = closest_sph_mat.col.w; // closest_sph_mat.spow;
          float3 color = as_float3(closest_sph_mat.col); // closest_sph_mat.col; 
          if (spow > 0.0f) {
            float dotp = DOT(cur_sp.vref, cur_ldir);
            float dotp2 = MAX(dotp, 0.0f);
            ispec = my_pown(dotp2, (int)spow);
          }
          col += idiff * color + ispec;
        }
      }
    }
  pixels_out[idx] = (convert_to_range (col.x) << RSHIFT) |
        (convert_to_range (col.y) << GSHIFT) |
        (convert_to_range (col.z) << BSHIFT);
}

