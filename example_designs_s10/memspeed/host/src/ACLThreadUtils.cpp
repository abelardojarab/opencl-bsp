#include "ACLThreadUtils.h"
#include <assert.h>
#include <stdio.h>
#include <stdarg.h>

#ifdef _MSC_VER

#include <windows.h>
int acl_get_thread_id() { return (int)GetCurrentThreadId(); }

typedef HANDLE thread_ref_t;

#else

#include <pthread.h>
#include <linux/unistd.h>
#include <sys/syscall.h>
#include <unistd.h>
static inline pid_t gettid(void) { return syscall( __NR_gettid ); }
int acl_get_thread_id() { return (int)gettid(); }

typedef pthread_t thread_ref_t;

#endif

static ACL_TLS int      l_current_thread_num;
static thread_func_t    l_thread_func;
static int              l_num_threads;
static ACLThreadBarrier l_barrier;


#ifdef _MSC_VER
static DWORD WINAPI l_thread_entry(LPVOID thread_arg)
#else
static void* l_thread_entry(void* thread_arg)
#endif
{
    l_current_thread_num = *(static_cast<int*>(thread_arg));
    l_thread_func();
    return 0;
}

void acl_start_join_threads(int num_threads, thread_func_t thread_func)
{
    assert(thread_func);
    assert(num_threads >= 1);
    l_num_threads = num_threads;
    l_thread_func = thread_func;

    if (l_num_threads == 1) {
        l_current_thread_num = 0;
        l_thread_func();
    }
    else {
        l_barrier.setNumThreads(l_num_threads);

        int* thread_nums         = new int[l_num_threads];
        thread_ref_t* thread_ids = new thread_ref_t[l_num_threads];

        for (int i = 0; i < l_num_threads; ++i) {
            thread_nums[i] = i;
#ifdef _MSC_VER
            thread_ids[i] = CreateThread(NULL, 0, l_thread_entry,
                    &thread_nums[i], 0, NULL);
            assert(thread_ids[i]);
#else
            int ret = pthread_create(&thread_ids[i], NULL, l_thread_entry,
                    &thread_nums[i]);
            assert(ret == 0);
#endif
        }

        for (int i = 0; i < l_num_threads; ++i) {
#ifdef _MSC_VER
            DWORD ret = WaitForSingleObject(thread_ids[i], INFINITE);
            assert(ret == WAIT_OBJECT_0);
#else
            int ret = pthread_join(thread_ids[i], NULL);
            assert(ret == 0);
#endif
        }

        delete [] thread_nums;
        delete [] thread_ids;
    }
}


int acl_get_thread_num()
{
    return l_current_thread_num;
}

int acl_get_num_threads()
{
    return l_num_threads;
}

void acl_sync_threads()
{
    assert(l_num_threads >= 1);

    l_barrier.wait();
}

static ACLMutex l_printf_mutex;
ACLMutex& acl_get_printf_mutex()
{
    return l_printf_mutex;
}

void acl_thread_printf(const char* format, ...)
{
    ACLScopedLock lock(acl_get_printf_mutex());

    printf("(%d-%d) ", acl_get_thread_id(), acl_get_thread_num());

    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);

    printf("\n");
    fflush(stdout);
}

struct ACLMutex::Impl
{
#ifdef _MSC_VER
    CRITICAL_SECTION critical_section;
#else
    pthread_mutex_t pthread_mutex;
#endif
};

ACLMutex::ACLMutex()
{
    m_impl = new Impl;

#ifdef _MSC_VER
    InitializeCriticalSection(&(m_impl->critical_section));
#else
    int ret;
    pthread_mutexattr_t attr;

    ret = pthread_mutexattr_init(&attr);
    assert(ret == 0);

    ret = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    assert(ret == 0);

    ret = pthread_mutex_init(&(m_impl->pthread_mutex), &attr);
    assert(ret == 0);

    ret = pthread_mutexattr_destroy(&attr);
    assert(ret == 0);
#endif
}

ACLMutex::~ACLMutex()
{
#ifdef _MSC_VER
    DeleteCriticalSection(&(m_impl->critical_section));
#else
    int ret = pthread_mutex_destroy(&(m_impl->pthread_mutex));
    assert(ret == 0);
#endif
    delete m_impl;
}

void ACLMutex::lock()
{
#ifdef _MSC_VER
    EnterCriticalSection(&(m_impl->critical_section));
#else
    int ret = pthread_mutex_lock(&(m_impl->pthread_mutex));
    assert(ret == 0);
#endif
}

void ACLMutex::unlock()
{
#ifdef _MSC_VER
    LeaveCriticalSection(&(m_impl->critical_section));
#else
    int ret = pthread_mutex_unlock(&(m_impl->pthread_mutex));
    assert(ret == 0);
#endif
}

struct ACLThreadBarrier::Impl
{
#ifdef _MSC_VER
    HANDLE enterSem;
    HANDLE exitSem;
    LONG volatile enterCount;
    LONG volatile exitCount;
#else
    pthread_barrier_t pthread_barrier;
#endif
    int numThreads;
};

ACLThreadBarrier::ACLThreadBarrier()
{
    m_impl = new Impl;
#ifdef _MSC_VER
    m_impl->enterSem = CreateSemaphore(NULL, 0, LONG_MAX, NULL);
    m_impl->exitSem = CreateSemaphore(NULL, 0, LONG_MAX, NULL);
    m_impl->enterCount = 0;
    m_impl->exitCount = 0;
#endif
    m_impl->numThreads = 0;
}

ACLThreadBarrier::ACLThreadBarrier(int numThreads)
{
    m_impl = new Impl;
#ifdef _MSC_VER
    m_impl->enterSem = CreateSemaphore(NULL, 0, LONG_MAX, NULL);
    m_impl->exitSem = CreateSemaphore(NULL, 0, LONG_MAX, NULL);
    m_impl->enterCount = 0;
    m_impl->exitCount = 0;
#else
    if (numThreads > 1) {
        int ret = pthread_barrier_init(&(m_impl->pthread_barrier), NULL, numThreads);
        assert(ret == 0);
    }
#endif
    m_impl->numThreads = numThreads;
}

ACLThreadBarrier::~ACLThreadBarrier()
{
#ifdef _MSC_VER
    CloseHandle(m_impl->enterSem);
    CloseHandle(m_impl->exitSem);
#else
    if (m_impl->numThreads > 1) {
        int ret = pthread_barrier_destroy(&(m_impl->pthread_barrier));
        assert(ret == 0);
    }
#endif
    delete m_impl;
}

int ACLThreadBarrier::numThreads()
{
    return m_impl->numThreads;
}

void ACLThreadBarrier::setNumThreads(int numThreads) {
#ifndef _MSC_VER
    if (m_impl->numThreads > 1) {
        int ret = pthread_barrier_destroy(&(m_impl->pthread_barrier));
        assert(ret == 0);
    }
    if (numThreads > 1) {
        int ret = pthread_barrier_init(&(m_impl->pthread_barrier), NULL, numThreads);
        assert(ret == 0);
    }
#endif
    m_impl->numThreads = numThreads;
}

void ACLThreadBarrier::wait()
{
    assert(m_impl->numThreads > 0);

    if (m_impl->numThreads > 1) {

#ifdef _MSC_VER
        // wait for all threads to enter the barrier
        if (InterlockedIncrement(&m_impl->enterCount) < m_impl->numThreads) {
            while (WaitForSingleObject(m_impl->enterSem, INFINITE) != WAIT_OBJECT_0);
        } else {
            m_impl->exitCount = 0;
            BOOL ret = ReleaseSemaphore(m_impl->enterSem, m_impl->numThreads-1, NULL);
            assert(ret);
        }

        // wait for all threads to exit the barrier
        if (InterlockedIncrement(&m_impl->exitCount) < m_impl->numThreads) {
            while (WaitForSingleObject(m_impl->exitSem, INFINITE) != WAIT_OBJECT_0);
        } else {
            m_impl->enterCount = 0;
            BOOL ret = ReleaseSemaphore(m_impl->exitSem, m_impl->numThreads-1, NULL);
            assert(ret);
        }
#else
        int ret = pthread_barrier_wait(&(m_impl->pthread_barrier));
        assert(ret == 0 || ret == PTHREAD_BARRIER_SERIAL_THREAD);
#endif

    }
}

