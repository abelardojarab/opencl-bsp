#ifndef ACL_THREAD_UTILS_H
#define ACL_THREAD_UTILS_H

#ifdef _MSC_VER
// windows
#define ACL_TLS __declspec(thread)
#else
// linux
#define ACL_TLS __thread
#endif

class ACLMutex;

typedef void (*thread_func_t)(void);
void acl_start_join_threads(int num_threads, thread_func_t thread_func);
int acl_get_thread_num();
int acl_get_thread_id();
int acl_get_num_threads();
void acl_sync_threads();
ACLMutex& acl_get_printf_mutex();
void acl_thread_printf(const char* format, ...);

class ACLMutex
{
public:
    ACLMutex();
    ~ACLMutex();

    void lock();
    void unlock();

private:
    // non-copyable class
    ACLMutex(const ACLMutex&);
    const ACLMutex& operator=(const ACLMutex&);

    struct Impl;
    Impl* m_impl;
};

class ACLScopedLock
{
public:
    ACLScopedLock(ACLMutex& mutex) : m_mutex(mutex)
    {
        m_mutex.lock();
    }

    ~ACLScopedLock()
    {
        m_mutex.unlock();
    }

private:
    // non-copyable class
    ACLScopedLock(const ACLScopedLock&);
    const ACLScopedLock& operator=(const ACLScopedLock&);

    ACLMutex& m_mutex;
};

class ACLThreadBarrier
{
public:
    ACLThreadBarrier();
    explicit ACLThreadBarrier(int numThreads);
    ~ACLThreadBarrier();

    int numThreads();
    void setNumThreads(int numThreads);
    void wait();

private:
    // non-copyable
    ACLThreadBarrier(const ACLThreadBarrier&);
    const ACLThreadBarrier& operator=(const ACLThreadBarrier&);

    struct Impl;
    Impl* m_impl;
};

#endif // ACL_THREAD_UTILS_H
