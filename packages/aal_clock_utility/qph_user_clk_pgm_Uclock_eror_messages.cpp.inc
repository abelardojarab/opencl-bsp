// qph_user_clk_pgm_Uclock_eror_messages.inc: bdx-p & skx-p user clock error messages
// Copyright Intel 2016
// Arthur.Sheiman@Intel.com   Created: 09-08-16
// Revision: 10-18-16  18:06


const char * const QUCPU_Uclock::pac_UclockErrorMsg[] = {
  "QUCPU_Uclock: No error.\0",
  "RunInitz: RTL versions number incompatible.\0",
  "RunInitz: PLL RTL has illegal ID.\0",
  "Timeout waiting for calibration.\0",
  "AvmmRMW: Verify error.\0",
  "AvmmRWcom: Timeout with AVMM transaction.\0",
  "GetFreqs: Not initialized.\0",
  "SetFreqs: Not initialized.\0",
  "SetFreqs: Illegal reference clock index.\0",
  "SetFreqs: RTL not configured for 100 MHz SYSCLK reflk.\0",
  "SetFreqs: RTL not configured for 322.265625 MHz reflk.\0",
  "SetFreqs: Requested frequency too high.\0",
  "SetFreqs: Illegal ExactFreq mode requested.\0",
  "SetFreqs: Use 322.265625 MHz refclk for ExactFreq mode.\0",
  "SetFreqs: PLL did unlock during power down.\0",
  "SetFreqs: Timeout waiting for PLL to lock.\0",
  "ERROR: MSG INDEX OUT OF RANGE\0"  // "+1" message
};
