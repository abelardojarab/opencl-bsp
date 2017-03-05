// qph_user_clk_pgm_Uclock_eror_messages.inc: bdx-p & skx-p user clock error messages
// Copyright Intel 2016
// Arthur.Sheiman@Intel.com   Created: 09-08-16
// Revision: 10-18-16  18:06


// Errors, decimal code
#define QUCPU_INT_UCLOCK_NO_ERROR                                ((int)   0)                       // No error
#define QUCPU_INT_UCLOCK_RUNINITZ_ERR_VER                        ((int)   1)                       // Wrong Uclock version error
#define QUCPU_INT_UCLOCK_RUNINITZ_ERR_FPLL_ID_ILLEGAL            ((int)   2)                       // Check PLL:   identifier  illegal
#define QUCPU_INT_UCLOCK_WAITCALDONE_ERR_BSY_TO                  ((int)   3)                       // WaitCalDone: timeout
#define QUCPU_INT_UCLOCK_AVMMRMWV_ERR_VERIFY                     ((int)   4)                       // AvmmRMW:     verify failure
#define QUCPU_INT_UCLOCK_AVMMRWCOM_ERR_TIMEOUT                   ((int)   5)                       // AvmmRWcom:   timeout
#define QUCPU_INT_UCLOCK_GETFREQS_ERR_INITZSTATE                 ((int)   6)                       // GetFreqs:    missing initialization
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_INITZSTATE                 ((int)   7)                       // SetFreqs:    missing initialization
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_ILLEGAL             ((int)   8)                       // SetFreqs:    illegal refclk index
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_100M_MISSING        ((int)   9)                       // SetFreqs:    100 MHz refclk missing from RTL
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_322M_MISSING        ((int)  10)                       // SetFreqs:    322 MHz refclk missing from RTL
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_OVERRANGE           ((int)  11)                       // SetFreqs:    f-index > END
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_INTG_RANGE_BAD      ((int)  12)                       // SetFreqs:    integer-PLL mode f-index invalid
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_INTG_NEEDS_322M     ((int)  13)                       // SetFreqs:    integer-PLL mode needs 322 MHz ref
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_PLL_NO_UNLOCK              ((int)  14)                       // SetFreqs:    PLL would not unlock
#define QUCPU_INT_UCLOCK_SETFREQS_ERR_PLL_LOCK_TO                ((int)  15)                       // SetFreqs:    timed out waiting for lock
#define QUCPU_INT_UCLOCK_NUM_ERROR_MESSAGES                      ((int)  16)                       // Number of error messages
