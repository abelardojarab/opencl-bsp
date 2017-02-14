set_time_format -unit ns -decimal_places 3

## DCFIFO specific settings
set_max_delay -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|*rdptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}] 100.000
set_max_delay -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|delayed_wrptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}] 100.000
set_min_delay -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|*rdptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}] -100.000
set_min_delay -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|delayed_wrptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}] -100.000
set_net_delay -max -value_multiplier 0.800 -get_value_from_clock_period dst_clock_period -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|delayed_wrptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}]
set_net_delay -max -value_multiplier 0.800 -get_value_from_clock_period dst_clock_period -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}]
set_net_delay -max -value_multiplier 0.800 -get_value_from_clock_period dst_clock_period -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|*rdptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}]
set_net_delay -max -value_multiplier 0.800 -get_value_from_clock_period dst_clock_period -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}]
set_max_skew -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|delayed_wrptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|rs_dgwp|dffpipe*|dffe*}] -get_skew_value_from_clock_period src_clock_period -skew_value_multiplier 0.800 
set_max_skew -from [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|*rdptr_g*}] -to [get_keepers {*ccip_async_shim*fifo_0|dcfifo_component|auto_generated|ws_dgrp|dffpipe*|dffe*}] -get_skew_value_from_clock_period src_clock_period -skew_value_multiplier 0.800 

## Reset paths
set_false_path -from inst_ccip_interface_reg|pck_cp2af_softReset_T1 -to [get_keepers *ccip_async_shim*softreset*]
set_false_path -from inst_ccip_interface_reg|pck_cp2af_softReset_T1 -to [get_keepers *ccip_async_shim*dcfifo_component*dffe*]

