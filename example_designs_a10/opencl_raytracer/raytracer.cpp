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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <errno.h>

// By default, SHARED_MEM is defined.
// On SoC systems, this enables shared DDR to take advantage of zero-cost sharing of data between 
// host and the kernel
#ifndef NO_SHARED_MEM
#define SHARED_MEM
#endif

// Enable if using X11 to send live video output to another machine.
// If disabled, host will process one frame, write it to a PPM file, and terminate.
#define USE_SDL2


#ifdef USE_SDL2
#include <SDL2/SDL.h>
#endif

#define COLOR_DEPTH 32

// ACL specific includes
#include "CL/opencl.h"
#include "aocl_utils.h"

using namespace aocl_utils;

struct ray
{
    cl_float3 orig, dir;
};

// cl_float3 has the same size as cl_float4 (by OpenCL standard).
// Instead of wasting space on padding, use .w component to store 
// an unrelated element. For example, 'material' struct stores 'spow'
// in the .w component, and sphere's position contains radiance in 
// .w component. Not as intuitive but saves memory!
struct material
{
    cl_float4 col;              /* color is float3, .w is spow */
};
struct sphere
{
    cl_float4 pos;              /* .w is rad */
    struct material mat;
};

struct spoint
{
    cl_float3 pos, normal, vref;        /* position, normal and view reflection */
    float dist;                 /* parametric distance of intersection along the ray */
};

struct camera
{
    cl_float3 pos, targ;
    float fov;
};


void render (int xres, int yres);
cl_float3 cross_product (cl_float3 v1, cl_float3 v2);
struct ray get_primary_ray (int x, int y);
cl_float3 get_sample_pos (int x, int y);
int ray_sphere (int sphere_num, struct ray ray, struct spoint *sp);
void load_scene (FILE * fp);
bool savePPM (const char *file, unsigned char *data, unsigned int w,
              unsigned int h);

#define MAX_LIGHTS    16        /* maximum number of lights in scene */
#define MAX_SPHERES    200      /* maximum number of spheres in scene */
#define RAY_MAG      1000.0     /* trace rays of this magnitude */
#define MAX_RAY_DEPTH    1      /* raytrace recursion limit */
#define ERR_MARGIN    1e-4      /* an arbitrary error margin to avoid surface acne */
#define FOV      0.78539816     /* field of view in rads (pi/4) */
#define HALF_FOV    (FOV * 0.5)
#define RSHIFT  16
#define GSHIFT  8
#define BSHIFT  0

/* some helpful macros... */
#define SQ(x)      ((x) * (x))
#define MAX(a, b)  ((a) > (b) ? (a) : (b))
#define MIN(a, b)  ((a) < (b) ? (a) : (b))
#define DOT(a, b)  ((a).x * (b).x + (a).y * (b).y + (a).z * (b).z)
#define NORMALIZE(a)  do {\
  float len = sqrt(DOT(a, a));\
  (a).x /= len; (a).y /= len; (a).z /= len;\
} while(0);

/* global state */
struct ray *rays;
struct ray *shadow_rays;
struct sphere *spheres;
struct spoint *temp_sps;
struct spoint *sps;
int *nearest_sp;
int *z;
int *flags;
char *in_shadow;
unsigned int *pixels1;
unsigned int *pixels2;
cl_float3 *ldir;
struct camera cam;
cl_float3 *lights;
float aspect = 1.333333;
int lnum = 0;
int snum = 0;
int target = 0;
int xres = 1024;
int yres = 768;
float xres_inv = 1.0f / 1024;
float yres_inv = 1.0f / 768;
float aspect_inv = 1.0f / 1.33333333;
const char *output_fname = NULL;
int demo_loop = 0;
int fullscreen_mode = 0;
int useDisplay = 1;

// ACL runtime configuration
//static cl_platform_id platform;
static cl_device_id device;
static cl_context context;
static cl_command_queue queue;
static cl_kernel kernel;
static cl_program program;
static cl_int status;
//cl_uint num_platforms;
//cl_uint num_devices;

static unsigned numDevices = 0;
static cl_platform_id thePlatform;
static scoped_array < cl_device_id > theDevices;

static cl_mem kernel_lights, kernel_spheres, kernel_pixels1, kernel_pixels2;

static const size_t workSize = 1;

static void
initializeVector (float *vector, int size)
{
    for (int i = 0; i < size; ++i)
    {
        vector[i] = rand () / (float) RAND_MAX;
    }
}

// free the resources allocated during initialization
void
cleanup ()
{
    if (kernel)
        clReleaseKernel (kernel);
    if (program)
        clReleaseProgram (program);
    if (queue)
        clReleaseCommandQueue (queue);
    if (context)
        clReleaseContext (context);
    if (kernel_lights)
        clReleaseMemObject (kernel_lights);
    if (kernel_spheres)
        clReleaseMemObject (kernel_spheres);
    if (kernel_pixels1)
        clReleaseMemObject (kernel_pixels1);
    if (kernel_pixels2)
        clReleaseMemObject (kernel_pixels2);
}

// Print error, cleanup, and terminate executable
static void
error_out (const char *str, cl_int status)
{
    fprintf (stderr, "%s\n", str);
    fprintf (stderr, "Error code: %d\n", status);
    cleanup ();
    exit (1);
}

const char *usage = {
    "Usage: raytracer [options]\n"
        "  Reads a scene file from stdin, writes the image to stdout, and stats to stderr.\n\n"
        "Options:\n"
        "  -s WxH     where W is the width and H the height of the image\n"
        "  -i <file>  read from <file> instead of stdin\n"
        "  -o <file>  write to <file> instead of stdout\n"
        "  -h         this help screen\n"
        "  -l         loop demo\n"
	"  -f         fullscreen\n"
        "  -c         computation on CPU\n"
        "  -a         computation on FPGA\n"
};



int
acl_ray_sphere (int xsz, int ysz)
{
    int start_time, rend_time, h;

    size_t vectorSize[2] = { xsz, ysz };

    // pre-compute camera-specific work-item invariant values
    // This saves area on the FPGA
    //  float8  camera_m,
    //  float   camera_m8, // {camera_m, camera_m8} is a single 9-element matrix
    //  float3  dir_z_portion,
    //  float3  camera_pos,
    cl_float3 camera_k;

    camera_k.x = cam.targ.x - cam.pos.x;
    camera_k.y = cam.targ.y - cam.pos.y;
    camera_k.z = cam.targ.z - cam.pos.z;
    NORMALIZE (camera_k);

    cl_float3 i, j = { 0, 1, 0, 0 }, k;
    cl_float8 m;
    cl_float m8;
    k = camera_k;

    i = cross_product (j, k);
    j = cross_product (k, i);
    m.s0 = i.x;
    m.s1 = j.x;
    m.s2 = k.x;
    m.s3 = i.y;
    m.s4 = j.y;
    m.s5 = k.y;
    m.s6 = i.z;
    m.s7 = j.z;
    m8 = k.z;

    cl_float3 dir_z_portion;
    // dir_z_portion = dir.z * m.s2/5/8 + camera_pos.s0/1/2
    float dir_z = 1.0f / HALF_FOV * RAY_MAG;
    dir_z_portion.x = dir_z * m.s2 + cam.pos.x;
    dir_z_portion.y = dir_z * m.s5 + cam.pos.y;
    dir_z_portion.z = dir_z * m8 + cam.pos.z;


    // Setting pre-frame arguments here.
    status = clSetKernelArg (kernel, 4, sizeof (cl_float8), (void *) &m);
    if (status != CL_SUCCESS)
    {
        error_out ("Failed to set arg 4.", status);
    }

    status =
        clSetKernelArg (kernel, 5, sizeof (cl_float3),
                        (void *) &dir_z_portion);
    if (status != CL_SUCCESS)
    {
        error_out ("Failed to set arg 6.", status);
    }

    status =
        clSetKernelArg (kernel, 6, sizeof (cl_float3), (void *) &(cam.pos));
    if (status != CL_SUCCESS)
    {
        error_out ("Failed to set arg 7.", status);
    }

    // launch kernel
    status =
        clEnqueueNDRangeKernel (queue, kernel, 2, NULL,
                                (const size_t *) vectorSize, NULL, 0, NULL,
                                NULL);
    if (status != CL_SUCCESS)
    {
        error_out ("Failed to launch kernel.", status);
    }

// Don't wait for kernel to finish here. The caller will do that
// (to enable double-buffering to work effectively).

    return 0;
}


int
parse_arguments (int argc, char **argv, FILE ** infile)
{
    // Default argument values.
    xres = 1024;
    yres = 768;
    target = 2;                 // FPGA

    for (int i = 1; i < argc; i++)
    {
        if (argv[i][0] == '-' && argv[i][2] == 0)
        {
            char *sep;
            switch (argv[i][1])
            {
            case 's':
                if (!isdigit (argv[++i][0]) || !(sep = strchr (argv[i], 'x'))
                    || !isdigit (*(sep + 1)))
                {
                    fputs
                        ("-s must be followed by something like \"640x480\"\n",
                         stderr);
                    return EXIT_FAILURE;
                }
                xres = atoi (argv[i]);
                yres = atoi (sep + 1);
                aspect = (float) xres / (float) yres;

                xres_inv = 1.0f / xres;
                yres_inv = 1.0f / yres;
                aspect_inv = 1.0f / aspect;
                break;

            case 'i':
                if (!(*infile = fopen (argv[++i], "r")))
                {
                    fprintf (stderr, "failed to open input file %s: %s\n",
                             argv[i], strerror (errno));
                    return EXIT_FAILURE;
                }
                break;

            case 'o':
                output_fname = argv[++i];
                break;

            case 'h':
                fputs (usage, stdout);
                return EXIT_FAILURE;

            case 'c':
                target = 1;
                break;

            case 'a':
                target = 2;
                break;

            case 'l':
                demo_loop = 1;
                break;
                
            case 'f':
                fullscreen_mode = 1;
                break;

            default:
                fprintf (stderr, "unrecognized argument: %s\n", argv[i]);
                fputs (usage, stderr);
                return EXIT_FAILURE;
            }
        }
        else
        {
            fprintf (stderr, "unrecognized argument: %s\n", argv[i]);
            fputs (usage, stderr);
            return EXIT_FAILURE;
        }
    }
    return 0;
}

int
main (int argc, char **argv)
{

    int i, j, l;
    float k;
    int step_sign = 1;
    float step_size = 0.17;
    int rend_time, start_time;
    FILE *infile = stdin, *outfile = stdout;

    // set current dir to exe's location. Will help find aocx
    if (!setCwdToExeDir ())
    {
        return EXIT_FAILURE;
    }

    if (parse_arguments (argc, argv, &infile) == EXIT_FAILURE)
    {
        return EXIT_FAILURE;
    }
    
    // Initialize SDL to show video
    if (SDL_Init (useDisplay ? SDL_INIT_VIDEO : 0) != 0)
    {
        printf ("Unable to initialize SDL: %s\n", SDL_GetError ());
        SDL_Quit ();
        exit (1);
    }
    
    if(fullscreen_mode && useDisplay)
    {
    	if(SDL_GetNumVideoDisplays() == 0)
    	{
    		printf ("Unable to get SDL video mode\n");
		SDL_Quit ();
		exit (1);
    	}
    	    
	// Get current display mode for first display
	//just assume there is only 1 display
	SDL_DisplayMode current;
	int status = SDL_GetCurrentDisplayMode(0, &current);
	if(status)
	{
		printf ("Unable to get SDL video mode\n");
		SDL_Quit ();
		exit (1);
    	}
    	
    	xres = current.w;
    	yres = current.h;
	aspect = (float) xres / (float) yres;
	
	xres_inv = 1.0f / xres;
	yres_inv = 1.0f / yres;
	aspect_inv = 1.0f / aspect;
    }

    lights = (cl_float3 *) malloc (sizeof (cl_float3) * MAX_LIGHTS);
    load_scene (infile);
    fprintf (stdout,
             "(CPU) : Scene loaded and consists of %d spheres and %d lights\n",
             snum, lnum);
    fprintf (stdout, "(CPU) : Resolution set to %d by %d\n", xres, yres);

    rays = (struct ray *) alignedMalloc (xres * yres * sizeof (*rays));
    pixels1 =
        (unsigned int *) alignedMalloc (xres * yres * sizeof (*pixels1));
    pixels2 =
        (unsigned int *) alignedMalloc (xres * yres * sizeof (*pixels2));

    //if (target == 2)
    {

        fprintf (stdout, "(FPGA): Kernel initialization is started\n");

        thePlatform = findAnyPlatform ();
        if (thePlatform == NULL)
        {
            printf ("Found no platforms!\n");
            cleanup ();
            exit (1);
            return -1;
        }

        // Set up the device(s)
        theDevices.
            reset (getDevices (thePlatform, CL_DEVICE_TYPE_ALL, &numDevices));

        // Print the name of the platform being used
        printf ("Using platform: %s\n",
                getPlatformName (thePlatform).c_str ());
        printf ("Using %d devices:\n", numDevices);
        for (unsigned i = 0; i < numDevices; ++i)
        {
            printf ("  %s\n", getDeviceName (theDevices[i]).c_str ());
        }
        device = theDevices[0];

        // create a context
        context =
            clCreateContext (0, 1, &device, &oclContextCallback, NULL,
                             &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateContext.", status);
        }

        // create a command queue
        queue =
            clCreateCommandQueue (context, device, CL_QUEUE_PROFILING_ENABLE,
                                  &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateCommandQueue.", status);
        }

#ifdef SHARED_MEM
        // To use shared memory, first allocate buffers with CL_MEM_ALLOC_HOST_PTR argument.
        // This will allocate the buffers in shared (HPS) DDR.
        kernel_lights =
            clCreateBuffer (context, CL_MEM_ALLOC_HOST_PTR,
                            sizeof (cl_float3) * lnum, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        kernel_spheres =
            clCreateBuffer (context, CL_MEM_ALLOC_HOST_PTR,
                            sizeof (*spheres) * snum, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        kernel_pixels1 =
            clCreateBuffer (context, CL_MEM_ALLOC_HOST_PTR,
                            sizeof (*pixels1) * xres * yres, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        kernel_pixels2 =
            clCreateBuffer (context, CL_MEM_ALLOC_HOST_PTR,
                            sizeof (*pixels2) * xres * yres, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        // Now map cl_mem objects that correspond to shared buffers to normal pointers that the host can use
        struct sphere *s =
            (struct sphere *) clEnqueueMapBuffer (queue, kernel_spheres,
                                                  CL_TRUE,
                                                  CL_MAP_WRITE | CL_MAP_READ,
                                                  0, sizeof (*spheres) * snum,
                                                  0, NULL, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clEnqueueMapBuffer.", status);
        }

        cl_float3 *l =
            (cl_float3 *) clEnqueueMapBuffer (queue, kernel_lights, CL_TRUE,
                                              CL_MAP_WRITE | CL_MAP_READ, 0,
                                              sizeof (cl_float3) * lnum, 0,
                                              NULL, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clEnqueueMapBuffer.", status);
        }

        unsigned int *p1 =
            (unsigned int *) clEnqueueMapBuffer (queue, kernel_pixels1,
                                                 CL_TRUE,
                                                 CL_MAP_WRITE | CL_MAP_READ,
                                                 0,
                                                 sizeof (*pixels1) * xres *
                                                 yres, 0, NULL, NULL,
                                                 &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clEnqueueMapBuffer.", status);
        }

        unsigned int *p2 =
            (unsigned int *) clEnqueueMapBuffer (queue, kernel_pixels2,
                                                 CL_TRUE,
                                                 CL_MAP_WRITE | CL_MAP_READ,
                                                 0,
                                                 sizeof (*pixels2) * xres *
                                                 yres, 0, NULL, NULL,
                                                 &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clEnqueueMapBuffer.", status);
        }

        // Copy setup data and initialize output data to 0.
        memcpy (l, lights, sizeof (cl_float3) * lnum);
        memcpy (s, spheres, sizeof (*spheres) * snum);
        memset (p1, 0, sizeof (*pixels1) * xres * yres);
        memset (p2, 0, sizeof (*pixels1) * xres * yres);
        lights = l;
        spheres = s;
        pixels1 = p1;
        pixels2 = p2;

#else
        // If not using shared memory, allocate buffers normally (with CL_MEM_READ/WRITE_ONLY attributes)
        // and later enqueue their writing/reading.
        // Note that one 1-DDR SoC systems, the only DDR system is shared, so doing this is a true waste of
        // time. This code is here to allow running the host unmodified on non-SoC systems.

        // create the input buffer
        kernel_lights =
            clCreateBuffer (context, CL_MEM_READ_ONLY,
                            sizeof (cl_float3) * lnum, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        // create the input buffer
        kernel_spheres =
            clCreateBuffer (context, CL_MEM_READ_ONLY,
                            sizeof (*spheres) * snum, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        kernel_pixels1 =
            clCreateBuffer (context, CL_MEM_WRITE_ONLY,
                            sizeof (*pixels1) * xres * yres, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }

        kernel_pixels2 =
            clCreateBuffer (context, CL_MEM_WRITE_ONLY,
                            sizeof (*pixels2) * xres * yres, NULL, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateBuffer.", status);
        }
#endif

        const char *kernel_name = "ray_sphere";
        size_t kernel_name_length = strlen (kernel_name);

        // Load pre-compiled binary and create program based on it
        if (isAlteraPlatform (thePlatform))
        {
            //Create the program using the binary aocx file
            std::string binary_file =
                getBoardBinaryFile ("raytracer", theDevices[0]);
            program =
                createProgramFromBinary (context, binary_file.c_str (),
                                         theDevices, numDevices);
        }
        else
        {
            std::string binary_file = "raytracer.cl";
            printf ("Using source: %s\n", binary_file.c_str ());
            program =
                createProgramFromSource (context, binary_file.c_str (),
                                         theDevices, numDevices,
                                         "-DDONT_USE_PRAGMA");
        }

        // build the program
        status = clBuildProgram (program, 0, NULL, "", NULL, NULL);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clBuildProgram.", status);
        }

        // create the kernel
        kernel = clCreateKernel (program, kernel_name, &status);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed clCreateKernel.", status);
        }

        // Set the arguments that will never change.
        // Camera-related arguments and output buffer will change for every frame and
        // will be set later.
        status =
            clSetKernelArg (kernel, 0, sizeof (cl_mem),
                            (void *) &kernel_spheres);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 1.", status);
        }

        status =
            clSetKernelArg (kernel, 1, sizeof (cl_mem),
                            (void *) &kernel_lights);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 0.", status);
        }

        status = clSetKernelArg (kernel, 2, sizeof (cl_int), (void *) &snum);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 2.", status);
        }

        status = clSetKernelArg (kernel, 3, sizeof (cl_int), (void *) &lnum);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 3.", status);
        }

        // Resolution-related work-item invariant values.
        status =
            clSetKernelArg (kernel, 7, sizeof (cl_float), (void *) &xres_inv);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 8.", status);
        }

        status =
            clSetKernelArg (kernel, 8, sizeof (cl_float), (void *) &yres_inv);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 9.", status);
        }

        status =
            clSetKernelArg (kernel, 9, sizeof (cl_float),
                            (void *) &aspect_inv);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to set arg 10.", status);
        }

#ifndef SHARED_MEM
        status =
            clEnqueueWriteBuffer (queue, kernel_lights, CL_TRUE, 0,
                                  sizeof (cl_float3) * lnum, lights, 0, NULL,
                                  NULL);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to enqueue buffer kernel_lights.", status);
        }

        status =
            clEnqueueWriteBuffer (queue, kernel_spheres, CL_TRUE, 0,
                                  sizeof (*spheres) * snum, spheres, 0, NULL,
                                  NULL);
        if (status != CL_SUCCESS)
        {
            error_out ("Failed to enqueue buffer kernel_spheres.", status);
        }

        clFinish (queue);
#endif
        fprintf (stderr, "(FPGA): Kernel initialization is completed\n\n");
    }


#ifdef USE_SDL2
    SDL_Window *theWindow;
    SDL_Surface *theWindowSurface;
    SDL_Surface *theFrames[2];  // double buffer of frames
    void *thePixels[2] = { pixels1, pixels2 };  // actual pixel data
    cl_mem kernel_pixels[2] = { kernel_pixels1, kernel_pixels2 };
    SDL_Event theEvent;

    // Set current frame to start at frame 0
    unsigned int theCurrentFrame = 0;

    if (useDisplay)
    {
        // Create the SDL Window
        theWindow = SDL_CreateWindow ("raytracer",
                                      //SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                      0, 0, xres, yres,
                                      //SDL_WINDOW_FULLSCREEN);
                                      fullscreen_mode ? SDL_WINDOW_FULLSCREEN_DESKTOP : SDL_WINDOW_SHOWN);

        // Make sure the window was created successfully
        if (theWindow == NULL)
        {
            printf ("SDL_CreateWindow failed: %s\n", SDL_GetError ());
            SDL_Quit ();
            exit (1);
        }

        SDL_ShowCursor (0);

        // Get the surface of the window
        theWindowSurface = SDL_GetWindowSurface (theWindow);

        // Make sure the window surface was retrieved successfully
        if (theWindowSurface == NULL)
        {
            printf ("SDL_GetWindowSurface failed: %s\n", SDL_GetError ());
            SDL_Quit ();
            exit (1);
        }
    }

    // Create the 2 surfaces (double buffer)
    unsigned int thePitch = xres * (COLOR_DEPTH/8);  // pitch size in bytes
    theFrames[0] = SDL_CreateRGBSurfaceFrom(thePixels[0], xres, yres, COLOR_DEPTH, thePitch, 0, 0, 0, 0);
    theFrames[1] = SDL_CreateRGBSurfaceFrom(thePixels[1], xres, yres, COLOR_DEPTH, thePitch, 0, 0, 0, 0);


#endif

    /* loop through different camera positions */
    // Have two pixel buffers for double-buffering */
    cl_mem cur_kernel_pixels = kernel_pixels1;
    unsigned int *cur_pixels = pixels1;

    int theProgramRunning = 1;
    k = -17.0;
    l = 0;
// Poll event so long as it isn't returning QUIT
    while (theProgramRunning)
    {
        // Handle events.
        if (SDL_PollEvent (&theEvent))
        {
            // If we have a quit event
            if (theEvent.type == SDL_QUIT)
                theProgramRunning = false;
            // If we have a keyboard event
            else if(theEvent.type == SDL_KEYDOWN)
            {
            	SDL_KeyboardEvent* aKeyboardEvent = (SDL_KeyboardEvent*)&theEvent;
                switch(aKeyboardEvent->keysym.sym)
                {
                    // Program exit case
                    case SDLK_ESCAPE:
                    case SDLK_q:
                        // Exit event pushed to the queue when requested
                        SDL_Event anExitEvent;
                        anExitEvent.type = SDL_QUIT;
                        SDL_PushEvent(&anExitEvent);
                        break;

		    // Switch between hardware and software calculation
		    case SDLK_s:
		    case SDLK_h:
		        target = (target == 1) ? 2 : 1;
		        break;
		    default:
		    	break;
		}
            }
        }
        else
        {
            if (k >= 17.0)
            {
                k = -17.0;
                l++;
                step_sign = -1.0 * step_sign;
            }
            if (l >= 4)
            {
                l = 0;
                if (!demo_loop)
                    break;
            }
            //for(l=0;l<4;l++) 
            {
                //for(k=-17.0;k<17.0;k=k+step_size) 
                {
                    double start_time = getCurrentTimestamp ();
                    unsigned char *image32;
                    cam.pos.x = (float) step_sign *k;
                    cam.pos.z = -(float) step_sign *sqrt (289 - (k * k));
                    fprintf (stdout,
                             "(CPU) : Set camera x,z position to (%.2f,%.2f)\n",
                             cam.pos.x, cam.pos.z);

                    if (target == 1)
                    {           // CPU computation
                        /* initialize primary rays */
                        for (j = 0; j < yres; j++)
                        {
                            for (i = 0; i < xres; i++)
                                rays[j * xres + i] = get_primary_ray (i, j);
                        }

                        /* render scene. output will go to pixels1 buffer. */
                        render (xres, yres);

                        /* output image to screen */
                        //image32 = (unsigned char *)alignedMalloc(xres*yres*4);
                        unsigned char *p = (unsigned char *) cur_pixels;
                        for (i = 0; i < xres * yres; i++)
                        {
                            *p++ = (pixels1[i] >> BSHIFT) & 0xff;
                            *p++ = (pixels1[i] >> GSHIFT) & 0xff;
                            *p++ = (pixels1[i] >> RSHIFT) & 0xff;
                            p++;
                        }
                    }
                    else
                    {           // FPGA computation
                        status =
                            clSetKernelArg (kernel, 10, sizeof (cl_mem),
                                            (void *) &cur_kernel_pixels);
                        if (status != CL_SUCCESS)
                        {
                            error_out ("Failed Set arg 11.", status);
                            cleanup ();
                            return 1;
                        }
                        acl_ray_sphere (xres, yres);

#ifndef SHARED_MEM
                        // read the output sps
                        status =
                            clEnqueueReadBuffer (queue, cur_kernel_pixels,
                                                 CL_FALSE, 0,
                                                 sizeof (*pixels1) * xres *
                                                 yres, cur_pixels, 0, NULL,
                                                 NULL);
                        if (status != CL_SUCCESS)
                        {
                            error_out
                                ("Failed to enqueue buffer kernel_pixels.",
                                 status);
                            cleanup ();
                            return 1;
                        }
#endif
                        image32 = (unsigned char *) cur_pixels; //prev_pixels;
                    }

#ifdef USE_SDL2
                    // Display the current frame on the surface
                    if (SDL_BlitSurface
                        (theFrames[theCurrentFrame], NULL, theWindowSurface,
                         NULL) != 0)
                        printf ("Unable to SDL_BlitSurface: %s\n",
                                SDL_GetError ());

                    // Update the window surface
                    if (SDL_UpdateWindowSurface (theWindow) != 0)
                        printf ("Unable to SDL_UpdateWindowSurface: %s\n",
                                SDL_GetError ());

                    clFinish (queue);
                    double elapsed_time = getCurrentTimestamp () - start_time;
                    fprintf (stdout, "Calculating one frame took %.1f ms\n",
                             elapsed_time * 1000.0);
                    // swap output buffers and corresponding cl_mem objects.
                    // Swap frames
                    theCurrentFrame ^= 1;
                    cur_pixels = (unsigned int *) thePixels[theCurrentFrame];
                    cur_kernel_pixels = kernel_pixels[theCurrentFrame];

#if 0
                    // In X11 mode, display previous frame while still computing the current frame.
                    ximage =
                        XCreateImage (display, visual, 24, ZPixmap, 0,
                                      (char *) image32, xres, yres, 32, 0);
                    XPutImage (display, window, DefaultGC (display, 0),
                               ximage, 0, 0, 0, 0, xres, yres);
                    clFinish (queue);
                    double elapsed_time = getCurrentTimestamp () - start_time;
                    fprintf (stdout, "Calculating one frame took %.1f ms\n",
                             elapsed_time * 1000.0);
                    // swap output buffers and corresponding cl_mem objects.
                    unsigned int *tp = prev_pixels;
                    prev_pixels = cur_pixels;
                    cur_pixels = tp;
                    cl_mem tk = prev_kernel_pixels;
                    prev_kernel_pixels = cur_kernel_pixels;
                    cur_kernel_pixels = tk;
#endif
#else
                    clFinish (queue);
                    double elapsed_time = getCurrentTimestamp () - start_time;
                    printf ("Calculating one frame took %.1f ms\n",
                            elapsed_time * 1000.0);
                    printf ("Throughput = %.2f FPS\n", 1.0 / elapsed_time);
                    if (output_fname)
                    {
                        savePPM (output_fname, (unsigned char *) cur_pixels,
                                 xres, yres);
                    }
                    exit (0);
#endif

                }               // k-loop
                //step_sign = -1.0 * step_sign;
            }                   // l-loop
            k = k + step_size;
        }
    }

    /* close files and display */
    if (infile != stdin)
        fclose (infile);
    if (outfile != stdout)
        fclose (outfile);

#ifdef USE_SDL2
    // Free Surfaces
    SDL_FreeSurface (theFrames[0]);
    SDL_FreeSurface (theFrames[1]);

    // Free Window
    SDL_DestroyWindow (theWindow);
#endif

    // free the resources allocated
    cleanup ();

    fprintf (stderr, "done\n");
    exit (0);
    return 0;
}


int
cpu_ray_sphere (int xsz, int ysz)
{
    int h, i, j;
    double start_time = getCurrentTimestamp ();

    for (j = 0; j < ysz; j++)
    {
        for (i = 0; i < xsz; i++)
        {
            for (h = 0; h < snum; h++)
            {
                flags[(j * xsz + i) * snum + h] =
                    ray_sphere (h, rays[j * xsz + i],
                                &temp_sps[(j * xsz + i) * snum + h]);
            }
        }
    }

    for (j = 0; j < ysz; j++)
    {
        for (i = 0; i < xsz; i++)
        {
            z[j * xsz + i] = -1;
            for (h = 0; h < snum; h++)
            {
                if (flags[(j * xsz + i) * snum + h] == 1 &&
                    (z[j * xsz + i] == -1
                     || temp_sps[(j * xsz + i) * snum + h].dist <
                     temp_sps[nearest_sp[j * xsz + i]].dist))
                {
                    z[j * xsz + i] = h;
                    sps[j * xsz + i] = temp_sps[(j * xsz + i) * snum + h];
                    nearest_sp[j * xsz + i] = (j * xsz + i) * snum + h;
                };
            };
        }
    }

    double elapsed_time = getCurrentTimestamp () - start_time;
    fprintf (stdout, "(CPU) : Calculate intersections took %.1f ms\n",
             elapsed_time * 1000.0);

    return 0;
}

/* render a frame of xres/yres dimensions into the provided framebuffer */
void
render (int xres, int yres)
{

    int f, g, h, i, j;
    int start_time, rend_time;
    float rval, gval, bval;
    float ispec, idiff;
    cl_float3 col;

    temp_sps =
        (struct spoint *) malloc (xres * yres * snum * sizeof (*temp_sps));
    sps = (struct spoint *) malloc (xres * yres * sizeof (*sps));
    z = (int *) malloc (xres * yres * sizeof (*z));
    shadow_rays =
        (struct ray *) malloc (xres * yres * lnum * sizeof (*shadow_rays));

    in_shadow = (char *) malloc (xres * yres * lnum * sizeof (*in_shadow));
    ldir = (cl_float3 *) malloc (xres * yres * lnum * sizeof (*ldir));

    nearest_sp = (int *) malloc (xres * yres * sizeof (*nearest_sp));

    flags = (int *) malloc (xres * yres * snum * sizeof (*flags));

    /* calculate all intersections and nearest intersection */
    cpu_ray_sphere (xres, yres);

    for (g = 0; g < lnum; g++)
    {
        /* set up shadow rays */
        for (j = 0; j < yres; j++)
        {
            for (i = 0; i < xres; i++)
            {
                ldir[(j * xres + i) * lnum + g].x =
                    lights[g].x - sps[j * xres + i].pos.x;
                ldir[(j * xres + i) * lnum + g].y =
                    lights[g].y - sps[j * xres + i].pos.y;
                ldir[(j * xres + i) * lnum + g].z =
                    lights[g].z - sps[j * xres + i].pos.z;

                shadow_rays[(j * xres + i) * lnum + g].orig =
                    sps[j * xres + i].pos;
                shadow_rays[(j * xres + i) * lnum + g].dir =
                    ldir[(j * xres + i) * lnum + g];
            }
        }

        /* shoot shadow rays */
        for (j = 0; j < yres; j++)
        {
            for (i = 0; i < xres; i++)
            {
                in_shadow[(j * xres + i) * lnum + g] = 0;
                for (f = 0; f < snum; f++)
                {
                    if (ray_sphere
                        (f, shadow_rays[(j * xres + i) * lnum + g], 0))
                    {
                        in_shadow[(j * xres + i) * lnum + g] = 1;
                        break;
                    }
                }
            }
        }
    }

    /* perform shading */
    for (j = 0; j < yres; j++)
    {
        for (i = 0; i < xres; i++)
        {
            /*  perform shading calculations */
            col.x = col.y = col.z = 0.0f;

            /* for all lights ... */
            for (g = 0; g < lnum; g++)
            {
                /* and if we're not in shadow, calculate direct illumination with the phong model. */
                if (!in_shadow[(j * xres + i) * lnum + g])
                {
                    NORMALIZE (ldir[(j * xres + i) * lnum + g]);
                    idiff =
                        MAX (DOT
                             (sps[j * xres + i].normal,
                              ldir[(j * xres + i) * lnum + g]), 0.0f);
                    float spow = spheres[z[j * xres + i]].mat.col.w;
                    ispec =
                        spow >
                        0.0f ?
                        pow (MAX
                             (DOT
                              (sps[j * xres + i].vref,
                               ldir[(j * xres + i) * lnum + g]), 0.0f),
                             spow) : 0.0;
                    col.x +=
                        idiff * spheres[z[j * xres + i]].mat.col.x + ispec;
                    col.y +=
                        idiff * spheres[z[j * xres + i]].mat.col.y + ispec;
                    col.z +=
                        idiff * spheres[z[j * xres + i]].mat.col.z + ispec;
                }
            }

            rval = col.x;
            gval = col.y;
            bval = col.z;

            pixels1[j * xres + i] =
                ((unsigned int) (MIN (rval, 1.0) *
                                 255.0) & 0xff) << RSHIFT | ((unsigned
                                                              int) (MIN (gval,
                                                                         1.0)
                                                                    *
                                                                    255.0) &
                                                             0xff) << GSHIFT |
                ((unsigned int) (MIN (bval, 1.0) * 255.0) & 0xff) << BSHIFT;
        }
    }

    /* clean up memory */
    free (temp_sps);
    free (sps);
    free (z);
    free (shadow_rays);
    free (in_shadow);
    free (ldir);
    free (nearest_sp);
    free (flags);
}



cl_float3
cross_product (cl_float3 v1, cl_float3 v2)
{

    cl_float3 res;
    res.x = v1.y * v2.z - v1.z * v2.y;
    res.y = v1.z * v2.x - v1.x * v2.z;
    res.z = v1.x * v2.y - v1.y * v2.x;
    return res;
}



/* determine the primary ray corresponding to the specified pixel (x, y) */
struct ray
get_primary_ray (int x, int y)
{

    struct ray ray;
    float m[3][3];
    cl_float3 i, j = { 0, 1, 0 }, k, dir, orig, foo;

    k.x = cam.targ.x - cam.pos.x;
    k.y = cam.targ.y - cam.pos.y;
    k.z = cam.targ.z - cam.pos.z;
    NORMALIZE (k);

    i = cross_product (j, k);
    j = cross_product (k, i);
    m[0][0] = i.x;
    m[0][1] = j.x;
    m[0][2] = k.x;
    m[1][0] = i.y;
    m[1][1] = j.y;
    m[1][2] = k.y;
    m[2][0] = i.z;
    m[2][1] = j.z;
    m[2][2] = k.z;

    ray.orig.x = ray.orig.y = ray.orig.z = 0.0;
    ray.dir = get_sample_pos (x, y);
    ray.dir.z = 1.0 / HALF_FOV;
    ray.dir.x *= RAY_MAG;
    ray.dir.y *= RAY_MAG;
    ray.dir.z *= RAY_MAG;

    dir.x = ray.dir.x + ray.orig.x;
    dir.y = ray.dir.y + ray.orig.y;
    dir.z = ray.dir.z + ray.orig.z;
    foo.x = dir.x * m[0][0] + dir.y * m[0][1] + dir.z * m[0][2];
    foo.y = dir.x * m[1][0] + dir.y * m[1][1] + dir.z * m[1][2];
    foo.z = dir.x * m[2][0] + dir.y * m[2][1] + dir.z * m[2][2];

    orig.x =
        ray.orig.x * m[0][0] + ray.orig.y * m[0][1] + ray.orig.z * m[0][2] +
        cam.pos.x;
    orig.y =
        ray.orig.x * m[1][0] + ray.orig.y * m[1][1] + ray.orig.z * m[1][2] +
        cam.pos.y;
    orig.z =
        ray.orig.x * m[2][0] + ray.orig.y * m[2][1] + ray.orig.z * m[2][2] +
        cam.pos.z;

    ray.orig = orig;
    ray.dir.x = foo.x + orig.x;
    ray.dir.y = foo.y + orig.y;
    ray.dir.z = foo.z + orig.z;

    return ray;
}



cl_float3
get_sample_pos (int x, int y)
{

    cl_float3 pt;
    float xsz = 2.0, ysz = xres / aspect;
    static float sf = 0.0;

    if (sf == 0.0)
    {
        sf = 2.0 / (float) xres;
    }

    pt.x = ((float) x / (float) xres) - 0.5;
    pt.y = -(((float) y / (float) yres) - 0.65) / aspect;

    return pt;
}



/* Calculate ray-sphere intersection, and return {1, 0} to signify hit or no hit.
 * Also the surface point parameters like position, normal, etc are returned through
 * the sp pointer if it is not NULL.
 */
int
ray_sphere (int sphere_num, const struct ray ray, struct spoint *sp)
{

    float a, b, c, d, sqrt_d, t1, t2, dot;
    struct sphere *sph = &spheres[sphere_num];
    int flag;

    a = SQ (ray.dir.x) + SQ (ray.dir.y) + SQ (ray.dir.z);
    b = 2.0f * ray.dir.x * (ray.orig.x - sph->pos.x) +
        2.0f * ray.dir.y * (ray.orig.y - sph->pos.y) +
        2.0f * ray.dir.z * (ray.orig.z - sph->pos.z);
    c = SQ (sph->pos.x) + SQ (sph->pos.y) + SQ (sph->pos.z) +
        SQ (ray.orig.x) + SQ (ray.orig.y) + SQ (ray.orig.z) +
        2.0f * (-sph->pos.x * ray.orig.x - sph->pos.y * ray.orig.y -
                sph->pos.z * ray.orig.z) - SQ (sph->pos.w);

    if ((d = SQ (b) - 4.0f * a * c) < 0.0f)
    {
        if (sp)
            flag = 0;
        return 0;
    }

    sqrt_d = sqrt (d);
    t1 = (-b + sqrt_d) / (2.0f * a);
    t2 = (-b - sqrt_d) / (2.0f * a);

    if ((t1 < ERR_MARGIN && t2 < ERR_MARGIN) || (t1 > 1.0f && t2 > 1.0f))
    {
        if (sp)
            flag = 0;
        return 0;
    }

    if (sp)
    {
        if (t1 < ERR_MARGIN)
            t1 = t2;
        if (t2 < ERR_MARGIN)
            t2 = t1;
        sp->dist = t1 < t2 ? t1 : t2;

        sp->pos.x = ray.orig.x + ray.dir.x * sp->dist;
        sp->pos.y = ray.orig.y + ray.dir.y * sp->dist;
        sp->pos.z = ray.orig.z + ray.dir.z * sp->dist;

        sp->normal.x = (sp->pos.x - sph->pos.x) / sph->pos.w;
        sp->normal.y = (sp->pos.y - sph->pos.y) / sph->pos.w;
        sp->normal.z = (sp->pos.z - sph->pos.z) / sph->pos.w;

        /* inlined reflect(ray.dir, sp->normal) function */
        dot =
            ray.dir.x * sp->normal.x + ray.dir.y * sp->normal.y +
            ray.dir.z * sp->normal.z;
        sp->vref.x = -(2.0f * dot * sp->normal.x - ray.dir.x);
        sp->vref.y = -(2.0f * dot * sp->normal.y - ray.dir.y);
        sp->vref.z = -(2.0f * dot * sp->normal.z - ray.dir.z);

        NORMALIZE (sp->vref);
        flag = 1;
    }
    return 1;
}



/* Load the scene from scene description file */
#define DELIM  " \t\n"
void
load_scene (FILE * fp)
{
    char line[256], *ptr, type;

    int j = 0;
    spheres = (struct sphere *) malloc (MAX_SPHERES * sizeof (*spheres));

    while ((ptr = fgets (line, 256, fp)))
    {
        int i;
        cl_float3 pos, col;
        float rad, spow, refl;

        while (*ptr == ' ' || *ptr == '\t')
            ptr++;
        if (*ptr == '#' || *ptr == '\n')
            continue;

        if (!(ptr = strtok (line, DELIM)))
            continue;
        type = *ptr;

        for (i = 0; i < 3; i++)
        {
            if (!(ptr = strtok (0, DELIM)))
                break;
            *((float *) &pos.x + i) = atof (ptr);
        }

        if (type == 'l')
        {
            lights[lnum++] = pos;
            continue;
        }

        if (!(ptr = strtok (0, DELIM)))
            continue;
        rad = atof (ptr);

        for (i = 0; i < 3; i++)
        {
            if (!(ptr = strtok (0, DELIM)))
                break;
            *((float *) &col.x + i) = atof (ptr);
        }

        if (type == 'c')
        {
            cam.pos = pos;
            cam.targ = col;
            continue;
        }

        if (!(ptr = strtok (0, DELIM)))
            continue;
        spow = atof (ptr);

        if (!(ptr = strtok (0, DELIM)))
            continue;
        refl = atof (ptr);

        if (type == 's')
        {
            spheres[snum].pos = pos;
            spheres[snum].pos.w = rad;
            spheres[snum].mat.col = col;
            spheres[snum].mat.col.w = spow;
            snum++;
        }
        else
        {
            fprintf (stderr, "unknown type: %c\n", type);
        }
    }
}

// Given unsigned rgb<w> data, save it to file in PPM format.
// Can use GIMP, bcompare, 
bool
savePPM (const char *file, unsigned char *data, unsigned int w,
         unsigned int h)
{
    FILE *fh = fopen (file, "wb");
    if (fh == NULL)
    {
        fprintf (stderr, "savePPM: Couldn't open file %s for writing.\n",
                 file);
        return false;
    }

    // 3 channels => 'P6' magic string
    fprintf (fh, "P6\n%d\n%d\n0xff\n", w, h);

    for (int i = 0; i < w * h; i++)
    {
        fwrite (data, 1, 3, fh);
        data += 4;              // ignore the forth component of data
    }

    fflush (fh);
    fclose (fh);
    return true;
}
