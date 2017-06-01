#ip-make-ipx --source-directory="iface,iface/ip" --output=ccip.ipx
ip-make-ipx --source-directory="ccip_iface,ccip_iface/avst_to_avmm_master,ccip_iface/avst_to_avmm_slave,ccip_iface/afu_id_avmm_slave,msgdma_bbb,$ALTERAOCLSDKROOT/ip/board" --output=iface.ipx  --relative-vars=ALTERAOCLSDKROOT
