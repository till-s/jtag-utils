--LB-MIT
--
-- MIT License
--
-- Copyright (c) 2026 Till Straumann
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--LE-MIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.BasicPkg.all;
use work.CommandMuxPkg.all;

entity CommandJtagBBTb is
end entity CommandJtagBBTb;

architecture sim of CommandJtagBBTb is

   subtype Slv9Type is std_logic_vector(8 downto 0);

   type Slv9Array is array (natural range <>) of Slv9Type;

   constant CMD_TDI_C : std_logic_vector:= x"00";
   constant CMD_TMS_C : std_logic_vector:= x"10";
   constant CMD_BB_C  : std_logic_vector:= x"20";
   constant CMD_WO_C  : std_logic_vector:= x"30";
   constant CMD_RO_C  : std_logic_vector:= x"40";

   signal clk         : std_logic := '0';

   -- little endian; i.e., rhs first
   constant TMS_EXP_C : std_logic_vector := (
      "0"
      & "000"
      & x"00000000"
      & "0" & x"00" 
      & "01010"
      & "001110100101"
      & "10"
   );

   constant TDI_EXP_C : std_logic_vector := (
      "0"
      & "010"
      & x"00000000"
      & "0" & x"55" 
      & "11111"
      & "000000000000"
      & "01"
   );

   constant CMD_C     : Slv9Array := (
      "0" & CMD_BB_C,
      "1" & "00000010",
      "0" & CMD_BB_C,
      "1" & "00000011",
      "0" & CMD_BB_C,
      "1" & "00001000",
      "0" & CMD_BB_C,
      "1" & "00001001",
      "0" & CMD_BB_C,
      "1" & "00001000",
      "0" & CMD_TMS_C,
      "0" & "00000011",
      "0" & "10100101",
      "1" & "11110011",
      "0" & CMD_TMS_C,
      "0" & "10000100",
      "1" & "00001010",
      "0" & CMD_WO_C,
      "0" & x"00",
      "0" & x"55",
      "1" & x"fe",
      "0" & CMD_RO_C,
      "0" & x"03",
      "1" & x"00",
      "0" & CMD_TDI_C,
      "0" & x"02",
      "1" & x"02"
   );

   constant CMD_EXP_C : Slv9Array := (
      "0" & CMD_BB_C,
      "1" & "00001000", -- TMS initialized to 1
      "0" & CMD_BB_C,
      "1" & "00000110",
      "0" & CMD_BB_C,
      "1" & "00000111",
      "0" & CMD_BB_C,
      "1" & "00001000",
      "0" & CMD_BB_C,
      "1" & "00001001",
      "0" & CMD_TMS_C,
      "0" & x"00",
      "1" & "0000----",
      "0" & CMD_TMS_C,
      "1" & "11111---",
      "0" & CMD_WO_C,
      "1" & "--------",
      "0" & CMD_RO_C,
      "0" & x"ef",
      "0" & x"be",
      "0" & x"ad",
      "1" & x"de",
      "0" & CMD_TDI_C,
      "1" & "010-----"
   );

   constant TDO_RO_C  : std_logic_vector := (
      "0" -- sentinel
      & x"de"
      & x"ad"
      & x"be"
      & x"ef"
   );

   signal mbus        : SimpleBusMstType := SIMPLE_BUS_MST_INIT_C;
   signal mrdy        : std_logic;
   signal sbus        : SimpleBusMstType;
   signal srdy        : std_logic        := '0';

   signal jidx        : integer := TMS_EXP_C'high;
   signal cidx        : integer := 0;
   signal sidx        : integer := 0;
   signal tidx        : integer := TDO_RO_C'high;
   signal run         : boolean := true;
   signal tdoRO       : boolean := false;

   signal tck         : std_logic;
   signal tms         : std_logic;
   signal tdi         : std_logic;
   signal tdo         : std_logic;

begin

   tdo <= TDO_RO_C(tidx) when tdoRO else tdi;

   P_CLK : process is
   begin
      wait for 10 us;
      clk <= not clk;
      if ( not run ) then
         wait;
      end if;
   end process P_CLK;

   mbus.dat <= CMD_C(cidx)(7 downto 0);
   mbus.lst <= CMD_C(cidx)(8);

   P_FEED : process ( clk ) is
      variable isCmd : boolean := true;
   begin
      if ( rising_edge( clk ) ) then
         if ( cidx = 0 ) then
            mbus.vld <= '1';
         end if;
         if ( (mbus.vld and mrdy) = '1' ) then
            if ( isCmd ) then
               tdoRO <= (mbus.dat = CMD_RO_C);
            end if;
            isCmd := mbus.lst = '1';
            if ( cidx = CMD_C'high ) then
               mbus.vld <= '0';
            else
               cidx <= cidx + 1;
            end if;
         end if;
      end if;
   end process P_FEED;

   P_SINK : process ( clk ) is
      variable cmp : Slv9Type;
   begin
      if ( rising_edge( clk ) ) then
         if ( sidx = 0 ) then
            srdy <= '1';
         end if;
         if ( (sbus.vld and srdy) = '1' ) then
            cmp := sbus.lst & sbus.dat;
            for i in cmp'range loop
               if ( CMD_EXP_C(sidx)(i) /= '-' ) then
                  assert cmp(i) = CMD_EXP_C(sidx)(i) report "stream RX mismatch" severity failure;
               end if;
            end loop;
            if ( sidx = CMD_EXP_C'high ) then
               assert cidx = CMD_C'high report "not all commands sent" severity failure;
               assert jidx = TMS_EXP_C'low report "not all jtag checked" severity failure;
               assert tidx = TDO_RO_C'low report "not all tdo sent" severity failure;
               run  <= false;
               srdy <= '0';
               report "Test PASSED";
            else
               sidx <= sidx + 1;
            end if;
         end if;
      end if;
   end process P_SINK;

   U_DUT : entity work.CommandJtagBB
      generic map (
         HPER_DELAY_G => 2
      )
      port map (
         clk      => clk,
         rst      => '0',
         mIb      => mbus,
         rIb      => mrdy,
         mOb      => sbus,
         rOb      => srdy,
         tck      => tck,
         tms      => tms,
         tdi      => tdi,
         tdo      => tdo
      );

   P_JCHECK : process ( tck ) is
   begin
      if ( rising_edge( tck ) ) then
         assert tms = TMS_EXP_C(jidx) report "TMS mismatch" severity failure;
         assert tdi = TDI_EXP_C(jidx) report "TDI mismatch" severity failure;
         jidx <= jidx - 1;
         assert jidx > 0 report "check vector overflow (internal error)" severity failure;
      end if;
      if ( falling_edge(tck) ) then
         if ( tdoRO ) then
            assert tidx > 0 report "TDO_C vector exhausted" severity failure;
            tidx <= tidx - 1;
         end if;
      end if;
   end process P_JCHECK;

end architecture sim;
