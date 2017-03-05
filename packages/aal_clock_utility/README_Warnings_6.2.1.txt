10-20-16:
5.0.2 had no warnings with -Wall.

5.0.3 generates warnings with -Wall.  Seems to be from AAL (Temp_Power_Monitor also has these three warnings, plus a few more from the application):

g++  -DENABLE_DEBUG=1 -D ASE_DEBUG=1 -DENABLE_ASSERT=1 -I/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include -D__AAL_USER__=1  -g -O0 -Wall -c -o aal_bdx-p_dual_10GBASE-SR.o aal_bdx-p_dual_10GBASE-SR.cpp
In file included from /home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/AASLib.h:55,
                 from /home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/AAL.h:52,
                 from aal_bdx-p_dual_10GBASE-SR.cpp:75:
/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/CAALEvent.h: In copy constructor ‘AAL::CReleaseRequestEvent::CReleaseRequestEvent(const AAL::CReleaseRequestEvent&)’:
/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/CAALEvent.h:449: warning: ‘AAL::CReleaseRequestEvent::m_Reason’ will be initialized after
/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/CAALEvent.h:448: warning:   ‘AAL::btUnsigned64bitInt AAL::CReleaseRequestEvent::m_Timeout’
/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/include/aalsdk/CAALEvent.h:441: warning:   when initialized here
g++ -g -O0 -Wall -o aal_bdx-p_dual_10GBASE-SR.bin aal_bdx-p_dual_10GBASE-SR.o  -L/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/lib -Wl,-rpath-link -Wl,/usr/local/lib -Wl,-rpath -Wl,/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/lib -L/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/lib64 -Wl,-rpath-link -Wl,/usr/local/lib64 -Wl,-rpath -Wl,/home/asheiman/AAL_5.0.3_release/AAL_5.0.3_release_destdir/usr/local/lib64 -lOSAL -lAAS -laalrt
