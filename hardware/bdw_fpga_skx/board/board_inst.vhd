	component board is
		port (
			avmm_r_slave_waitrequest   : out std_logic;                                         -- waitrequest
			avmm_r_slave_readdata      : out std_logic_vector(511 downto 0);                    -- readdata
			avmm_r_slave_readdatavalid : out std_logic;                                         -- readdatavalid
			avmm_r_slave_burstcount    : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- burstcount
			avmm_r_slave_writedata     : in  std_logic_vector(511 downto 0) := (others => 'X'); -- writedata
			avmm_r_slave_address       : in  std_logic_vector(63 downto 0)  := (others => 'X'); -- address
			avmm_r_slave_write         : in  std_logic                      := 'X';             -- write
			avmm_r_slave_read          : in  std_logic                      := 'X';             -- read
			avmm_r_slave_byteenable    : in  std_logic_vector(63 downto 0)  := (others => 'X'); -- byteenable
			avmm_r_slave_debugaccess   : in  std_logic                      := 'X';             -- debugaccess
			avmm_w_slave_waitrequest   : out std_logic;                                         -- waitrequest
			avmm_w_slave_readdata      : out std_logic_vector(511 downto 0);                    -- readdata
			avmm_w_slave_readdatavalid : out std_logic;                                         -- readdatavalid
			avmm_w_slave_burstcount    : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- burstcount
			avmm_w_slave_writedata     : in  std_logic_vector(511 downto 0) := (others => 'X'); -- writedata
			avmm_w_slave_address       : in  std_logic_vector(63 downto 0)  := (others => 'X'); -- address
			avmm_w_slave_write         : in  std_logic                      := 'X';             -- write
			avmm_w_slave_read          : in  std_logic                      := 'X';             -- read
			avmm_w_slave_byteenable    : in  std_logic_vector(63 downto 0)  := (others => 'X'); -- byteenable
			avmm_w_slave_debugaccess   : in  std_logic                      := 'X';             -- debugaccess
			bridge_reset_reset         : in  std_logic                      := 'X';             -- reset
			ci0_InitDone               : in  std_logic                      := 'X';             -- InitDone
			ci0_virtual_access         : in  std_logic                      := 'X';             -- virtual_access
			ci0_tx_c0_almostfull       : in  std_logic                      := 'X';             -- tx_c0_almostfull
			ci0_rx_c0_header           : in  std_logic_vector(27 downto 0)  := (others => 'X'); -- rx_c0_header
			ci0_rx_c0_data             : in  std_logic_vector(511 downto 0) := (others => 'X'); -- rx_c0_data
			ci0_rx_c0_wrvalid          : in  std_logic                      := 'X';             -- rx_c0_wrvalid
			ci0_rx_c0_rdvalid          : in  std_logic                      := 'X';             -- rx_c0_rdvalid
			ci0_rx_c0_ugvalid          : in  std_logic                      := 'X';             -- rx_c0_ugvalid
			ci0_rx_c0_mmiordvalid      : in  std_logic                      := 'X';             -- rx_c0_mmiordvalid
			ci0_rx_c0_mmiowrvalid      : in  std_logic                      := 'X';             -- rx_c0_mmiowrvalid
			ci0_tx_c1_almostfull       : in  std_logic                      := 'X';             -- tx_c1_almostfull
			ci0_rx_c1_header           : in  std_logic_vector(27 downto 0)  := (others => 'X'); -- rx_c1_header
			ci0_rx_c1_wrvalid          : in  std_logic                      := 'X';             -- rx_c1_wrvalid
			ci0_rx_c1_irvalid          : in  std_logic                      := 'X';             -- rx_c1_irvalid
			ci0_tx_c0_header           : out std_logic_vector(98 downto 0);                     -- tx_c0_header
			ci0_tx_c0_rdvalid          : out std_logic;                                         -- tx_c0_rdvalid
			ci0_tx_c1_header           : out std_logic_vector(98 downto 0);                     -- tx_c1_header
			ci0_tx_c1_data             : out std_logic_vector(511 downto 0);                    -- tx_c1_data
			ci0_tx_c1_wrvalid          : out std_logic;                                         -- tx_c1_wrvalid
			ci0_tx_c1_irvalid          : out std_logic;                                         -- tx_c1_irvalid
			ci0_tx_c1_byteen           : out std_logic_vector(63 downto 0);                     -- tx_c1_byteen
			ci0_tx_c2_header           : out std_logic_vector(8 downto 0);                      -- tx_c2_header
			ci0_tx_c2_rdvalid          : out std_logic;                                         -- tx_c2_rdvalid
			ci0_tx_c2_data             : out std_logic_vector(63 downto 0);                     -- tx_c2_data
			ci0_nohazards_rd           : out std_logic;                                         -- nohazards_rd
			ci0_nohazards_wr_full      : out std_logic;                                         -- nohazards_wr_full
			ci0_nohazards_wr_all       : out std_logic;                                         -- nohazards_wr_all
			clk_400_clk                : in  std_logic                      := 'X';             -- clk
			global_reset_reset_n       : in  std_logic                      := 'X';             -- reset_n
			kernel_clk_clk             : out std_logic;                                         -- clk
			kernel_cra_waitrequest     : in  std_logic                      := 'X';             -- waitrequest
			kernel_cra_readdata        : in  std_logic_vector(63 downto 0)  := (others => 'X'); -- readdata
			kernel_cra_readdatavalid   : in  std_logic                      := 'X';             -- readdatavalid
			kernel_cra_burstcount      : out std_logic_vector(0 downto 0);                      -- burstcount
			kernel_cra_writedata       : out std_logic_vector(63 downto 0);                     -- writedata
			kernel_cra_address         : out std_logic_vector(29 downto 0);                     -- address
			kernel_cra_write           : out std_logic;                                         -- write
			kernel_cra_read            : out std_logic;                                         -- read
			kernel_cra_byteenable      : out std_logic_vector(7 downto 0);                      -- byteenable
			kernel_cra_debugaccess     : out std_logic;                                         -- debugaccess
			kernel_irq_irq             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- irq
			kernel_reset_reset_n       : out std_logic;                                         -- reset_n
			psl_clk_clk                : in  std_logic                      := 'X';             -- clk
			kernel_clk_in_clk          : in  std_logic                      := 'X'              -- clk
		);
	end component board;

	u0 : component board
		port map (
			avmm_r_slave_waitrequest   => CONNECTED_TO_avmm_r_slave_waitrequest,   --  avmm_r_slave.waitrequest
			avmm_r_slave_readdata      => CONNECTED_TO_avmm_r_slave_readdata,      --              .readdata
			avmm_r_slave_readdatavalid => CONNECTED_TO_avmm_r_slave_readdatavalid, --              .readdatavalid
			avmm_r_slave_burstcount    => CONNECTED_TO_avmm_r_slave_burstcount,    --              .burstcount
			avmm_r_slave_writedata     => CONNECTED_TO_avmm_r_slave_writedata,     --              .writedata
			avmm_r_slave_address       => CONNECTED_TO_avmm_r_slave_address,       --              .address
			avmm_r_slave_write         => CONNECTED_TO_avmm_r_slave_write,         --              .write
			avmm_r_slave_read          => CONNECTED_TO_avmm_r_slave_read,          --              .read
			avmm_r_slave_byteenable    => CONNECTED_TO_avmm_r_slave_byteenable,    --              .byteenable
			avmm_r_slave_debugaccess   => CONNECTED_TO_avmm_r_slave_debugaccess,   --              .debugaccess
			avmm_w_slave_waitrequest   => CONNECTED_TO_avmm_w_slave_waitrequest,   --  avmm_w_slave.waitrequest
			avmm_w_slave_readdata      => CONNECTED_TO_avmm_w_slave_readdata,      --              .readdata
			avmm_w_slave_readdatavalid => CONNECTED_TO_avmm_w_slave_readdatavalid, --              .readdatavalid
			avmm_w_slave_burstcount    => CONNECTED_TO_avmm_w_slave_burstcount,    --              .burstcount
			avmm_w_slave_writedata     => CONNECTED_TO_avmm_w_slave_writedata,     --              .writedata
			avmm_w_slave_address       => CONNECTED_TO_avmm_w_slave_address,       --              .address
			avmm_w_slave_write         => CONNECTED_TO_avmm_w_slave_write,         --              .write
			avmm_w_slave_read          => CONNECTED_TO_avmm_w_slave_read,          --              .read
			avmm_w_slave_byteenable    => CONNECTED_TO_avmm_w_slave_byteenable,    --              .byteenable
			avmm_w_slave_debugaccess   => CONNECTED_TO_avmm_w_slave_debugaccess,   --              .debugaccess
			bridge_reset_reset         => CONNECTED_TO_bridge_reset_reset,         --  bridge_reset.reset
			ci0_InitDone               => CONNECTED_TO_ci0_InitDone,               --           ci0.InitDone
			ci0_virtual_access         => CONNECTED_TO_ci0_virtual_access,         --              .virtual_access
			ci0_tx_c0_almostfull       => CONNECTED_TO_ci0_tx_c0_almostfull,       --              .tx_c0_almostfull
			ci0_rx_c0_header           => CONNECTED_TO_ci0_rx_c0_header,           --              .rx_c0_header
			ci0_rx_c0_data             => CONNECTED_TO_ci0_rx_c0_data,             --              .rx_c0_data
			ci0_rx_c0_wrvalid          => CONNECTED_TO_ci0_rx_c0_wrvalid,          --              .rx_c0_wrvalid
			ci0_rx_c0_rdvalid          => CONNECTED_TO_ci0_rx_c0_rdvalid,          --              .rx_c0_rdvalid
			ci0_rx_c0_ugvalid          => CONNECTED_TO_ci0_rx_c0_ugvalid,          --              .rx_c0_ugvalid
			ci0_rx_c0_mmiordvalid      => CONNECTED_TO_ci0_rx_c0_mmiordvalid,      --              .rx_c0_mmiordvalid
			ci0_rx_c0_mmiowrvalid      => CONNECTED_TO_ci0_rx_c0_mmiowrvalid,      --              .rx_c0_mmiowrvalid
			ci0_tx_c1_almostfull       => CONNECTED_TO_ci0_tx_c1_almostfull,       --              .tx_c1_almostfull
			ci0_rx_c1_header           => CONNECTED_TO_ci0_rx_c1_header,           --              .rx_c1_header
			ci0_rx_c1_wrvalid          => CONNECTED_TO_ci0_rx_c1_wrvalid,          --              .rx_c1_wrvalid
			ci0_rx_c1_irvalid          => CONNECTED_TO_ci0_rx_c1_irvalid,          --              .rx_c1_irvalid
			ci0_tx_c0_header           => CONNECTED_TO_ci0_tx_c0_header,           --              .tx_c0_header
			ci0_tx_c0_rdvalid          => CONNECTED_TO_ci0_tx_c0_rdvalid,          --              .tx_c0_rdvalid
			ci0_tx_c1_header           => CONNECTED_TO_ci0_tx_c1_header,           --              .tx_c1_header
			ci0_tx_c1_data             => CONNECTED_TO_ci0_tx_c1_data,             --              .tx_c1_data
			ci0_tx_c1_wrvalid          => CONNECTED_TO_ci0_tx_c1_wrvalid,          --              .tx_c1_wrvalid
			ci0_tx_c1_irvalid          => CONNECTED_TO_ci0_tx_c1_irvalid,          --              .tx_c1_irvalid
			ci0_tx_c1_byteen           => CONNECTED_TO_ci0_tx_c1_byteen,           --              .tx_c1_byteen
			ci0_tx_c2_header           => CONNECTED_TO_ci0_tx_c2_header,           --              .tx_c2_header
			ci0_tx_c2_rdvalid          => CONNECTED_TO_ci0_tx_c2_rdvalid,          --              .tx_c2_rdvalid
			ci0_tx_c2_data             => CONNECTED_TO_ci0_tx_c2_data,             --              .tx_c2_data
			ci0_nohazards_rd           => CONNECTED_TO_ci0_nohazards_rd,           --              .nohazards_rd
			ci0_nohazards_wr_full      => CONNECTED_TO_ci0_nohazards_wr_full,      --              .nohazards_wr_full
			ci0_nohazards_wr_all       => CONNECTED_TO_ci0_nohazards_wr_all,       --              .nohazards_wr_all
			clk_400_clk                => CONNECTED_TO_clk_400_clk,                --       clk_400.clk
			global_reset_reset_n       => CONNECTED_TO_global_reset_reset_n,       --  global_reset.reset_n
			kernel_clk_clk             => CONNECTED_TO_kernel_clk_clk,             --    kernel_clk.clk
			kernel_cra_waitrequest     => CONNECTED_TO_kernel_cra_waitrequest,     --    kernel_cra.waitrequest
			kernel_cra_readdata        => CONNECTED_TO_kernel_cra_readdata,        --              .readdata
			kernel_cra_readdatavalid   => CONNECTED_TO_kernel_cra_readdatavalid,   --              .readdatavalid
			kernel_cra_burstcount      => CONNECTED_TO_kernel_cra_burstcount,      --              .burstcount
			kernel_cra_writedata       => CONNECTED_TO_kernel_cra_writedata,       --              .writedata
			kernel_cra_address         => CONNECTED_TO_kernel_cra_address,         --              .address
			kernel_cra_write           => CONNECTED_TO_kernel_cra_write,           --              .write
			kernel_cra_read            => CONNECTED_TO_kernel_cra_read,            --              .read
			kernel_cra_byteenable      => CONNECTED_TO_kernel_cra_byteenable,      --              .byteenable
			kernel_cra_debugaccess     => CONNECTED_TO_kernel_cra_debugaccess,     --              .debugaccess
			kernel_irq_irq             => CONNECTED_TO_kernel_irq_irq,             --    kernel_irq.irq
			kernel_reset_reset_n       => CONNECTED_TO_kernel_reset_reset_n,       --  kernel_reset.reset_n
			psl_clk_clk                => CONNECTED_TO_psl_clk_clk,                --       psl_clk.clk
			kernel_clk_in_clk          => CONNECTED_TO_kernel_clk_in_clk           -- kernel_clk_in.clk
		);

