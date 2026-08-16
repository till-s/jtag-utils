library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.JtagTapPkg.all;

entity JTAGH19EMULTb is
end entity JTAGH19EMULTb;

architecture sim of JTAGH19EMULTb is
   signal clk : std_logic := '0';

   subtype Slv4 is std_logic_vector(3 downto 0);

   type Slv4Array is array (natural range <>) of Slv4;

   constant TMS_C : std_logic_vector := (
      "111110" & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
               & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
               & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
               & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
               & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
                                            & "100" & "00000000" & "00000000" & "00000001" & "10" --           shift DR -> RTI
               & "1100" & "00000001" & "10" & "100" & "00000000" & "00000000" & "00000001" & "10" -- shift IR, shift DR -> RTI
               & "1100" & "00000001" & "10" & "100"                           & "00000001" & "10" -- shift IR, shift DR -> RTI
      & "0" -- END/dummy
   );
   constant TDI_C : std_logic_vector := (
      "000000" & "0000" & "01001100" & "00" & "000" & "01100000" & "00000000" & "00000001" & "00" -- IR: 0x32, DR 0x800006
               & "0000" & "00011100" & "00" & "000" & "11111111" & "11111111" & "11111111" & "00" -- IR: 0x38, DR 0xffffff
               & "0000" & "11111111" & "00" & "000" & "11111111" & "00000000" & "11111111" & "00" -- IR: 0xff, DR 0xff00ff
               & "0000" & "01001100" & "00" & "000" & "01100000" & "00000000" & "00000000" & "00" -- IR: 0x32, DR 0x000006
               & "0000" & "00011100" & "00" & "000" & "11111111" & "11111111" & "11111111" & "00" -- IR: 0x38, DR 0xffffff
                                            & "000" & "00000000" & "00000000" & "00000000" & "00" --           DR 0xffffff
               & "0000" & "01001100" & "00" & "000" & "01101000" & "00000000" & "00000000" & "00" -- IR: 0x32, DR 0x000016
               & "0000" & "00011100" & "00" & "000"                           & "11111111" & "00" -- IR: 0x38, DR     0xff
      & "0" -- END/dummy
   );

   signal presc     : integer   := 0;
   signal tck       : std_logic := '0';
   signal tms       : std_logic := '0';
   signal tdi       : std_logic := '0';
   signal tdo       : std_logic := '0';
   signal idx       : integer   := 0;
   signal jupdate   : std_logic;
   signal jshift    : std_logic;
   signal jce2      : std_logic;

   signal sr_out    : std_logic_vector(63 downto 0);
   signal dr_out    : std_logic_vector(63 downto 0);

   signal drCnt     : integer := 0;
   signal er2_tdo   : std_logic_vector(18 downto 0);

begin

   P_CLK : process is
   begin
      wait for 10 us;
      clk <= not clk;
      if ( idx >= TDI_C'length - 1 ) then
         wait;
      end if;
   end process P_CLK;

   P_DRV : process ( clk ) is
      constant HP_C : integer := 4;
      variable cnt  : integer := 0;
   begin
      if ( rising_edge( clk ) ) then
         presc <= presc - 1;
	 if ( cnt = 2 ) then
            er2_tdo(0) <= '1';
         end if;
	 if ( cnt = 6 ) then
            er2_tdo(0) <= '0';
         end if;
         cnt := cnt + 1;
	 if ( jshift = '0' ) then
            cnt := 0;
	 end if;
         if ( presc < 0 ) then
            if ( tck = '1' ) then
               idx <= idx + 1;
            end if;
            presc <= HP_C-1;
            tck   <= not tck;
            if ( tck = '0' ) then
               -- rising edge
               if ( jshift = '1' ) then
                  sr_out <= tdo & sr_out(sr_out'left downto 1);
                  drCnt  <= drCnt + 1;
               end if;
               if ( jupdate = '1' ) then
                  sr_out <= std_logic_vector(shift_right(unsigned(sr_out), 64 - drCnt));
                  drCnt  <= 0;
               end if;
            end if;
         end if;
      end if;
   end process P_DRV;

   er2_tdo(18 downto 1) <= (others => '0');

   tms <= TMS_C(idx);
   tdi <= TDI_C(idx);

   U_DUT : entity work.JTAGH19EMUL
      port map (
         clk     => clk,
         rst     => '0',
         tck     => tck,
         tms     => tms,
         tdi     => tdi,
         tdo     => tdo,
         jshift  => jshift,
         jupdate => jupdate,
         jce2    => jce2,

         er2_tdo => er2_tdo
      );

end architecture sim;
