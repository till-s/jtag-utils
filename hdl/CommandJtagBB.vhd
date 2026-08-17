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

-- inbound stream: (SUBCMD_TDI_C, SUBCMD_TMS_C, SUBCMD_TDI_WO_C)
--
--   cmd, len, data, data, data, ...
--
--   len[3:0]: # bits to shift (zero-based!) of *last* 'data' byte.
--   len[7]    TDI level to be shifted (SUBCMD_TMS_C)
--
-- outbound stream (TDI_C, TMS_C, TDI_RO_C):
--   cmd, data, data, data, ...
--   'len+1' most-significant bits of last data byte are valid
--
-- inbound stream: (TDI_RO_C)
--   cmd, lenlo, lenhi
--
-- lenhi:lenlo: byte count (zero-based) to read back (TDI driven to '0')
--
-- outbound stream (TDI_WO_C)
--  cmd, dummy  (dummy returned when all data have been written)
--
-- inbound stream (SUBCMD_BB_C)
--  cmd, val
--
--  val(0) driven on TCK
--  val(1) driven on TDI
--  val(3) driven on TMS
--
-- outbound stream (SUBCMD_BB_C)
--  cmd, readback (val[0]: TCK, val[1]: TDI, val[2]: TDO, val[3]: TMS)


entity CommandJtagBB is
   generic (
      -- zero-based half-period TCK
      HPER_DELAY_G : natural
   );
   port (
      clk          : in  std_logic;
      rst          : in  std_logic;

      mIb          : in  SimpleBusMstType;
      rIb          : out std_logic;

      mOb          : out SimpleBusMstType;
      rOb          : in  std_logic;

      tck          : out std_logic;
      tms          : out std_logic;
      tdi          : out std_logic;
      tdo          : in  std_logic
   );
end entity CommandJtagBB;

architecture rtl of CommandJtagBB is

   type StateType is (ECHO, BB, LEN, LEN1, READ, WRITE, DON, WAI);

   subtype CountType is integer range  -1 to HPER_DELAY_G - 1;

   subtype SubCommandType is std_logic_vector(7-NUM_CMD_BITS_C downto 0);

   constant SUBCMD_TDI_C    : SubCommandType := SubCommandType( to_unsigned( 0, SubCommandType'length ) );
   constant SUBCMD_TMS_C    : SubCommandType := SubCommandType( to_unsigned( 1, SubCommandType'length ) );
   constant SUBCMD_BB_C     : SubCommandType := SubCommandType( to_unsigned( 2, SubCommandType'length ) );
   constant SUBCMD_TDI_WO_C : SubCommandType := SubCommandType( to_unsigned( 3, SubCommandType'length ) );
   constant SUBCMD_TDI_RO_C : SubCommandType := SubCommandType( to_unsigned( 4, SubCommandType'length ) );

   type RegType is record
      state         : StateType;
      nextState     : StateType;
      cmd           : SubCommandType;
      presc         : CountType;
      len           : signed(16 downto 0);
      lstSeen       : std_logic;
      tck           : std_logic;
      tms           : std_logic;
      tdi           : std_logic;
      sr            : std_logic_vector(7 downto 0);
      tdoSR         : std_logic_vector(7 downto 0);
      bitCnt        : signed(3 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state         => ECHO,
      nextState     => ECHO,
      cmd           => (others => '0'),
      presc         => -1,
      len           => (others => '0'),
      lstSeen       => '0',
      tck           => '0',
      tms           => '1',
      tdi           => '0',
      sr            => (others => '0'),
      tdoSR         => (others => '0'),
      bitCnt        => (others => '0')
   );

   signal r               : RegType := REG_INIT_C;
   signal rin             : RegType;

   signal rIbLoc          : std_logic;


begin

   P_COMB : process ( r, mIb, rOb, rIbLoc, tdo ) is
      variable v       : RegType;
      variable isTMS   : boolean;
   begin
      v := r;

      isTMS   := (r.cmd = SUBCMD_TMS_C);

      mOb.dat <= r.tdoSR;
      mOb.vld <= '0';
      mOb.lst <= '0';

      rIbLoc  <= '1';

      if ( isTMS ) then
         tms <= r.sr(0);
         tdi <= r.tdi;
      else
         tdi <= r.sr(0);
         tms <= r.tms;
      end if;
      tck <= r.tck;

      if ( ( mIb.vld and mIb.lst and rIbLoc ) = '1' ) then
         v.lstSeen := '1';
      end if;

      case ( r.state ) is
         when ECHO =>
            mOb       <= mIb;
            rIbLoc    <= rOb;
            v.tdoSR   := x"FF"; -- error status
            v.lstSeen := '0';
            v.presc   := HPER_DELAY_G - 1;
            if ( (rOb and mIb.vld) = '1' ) then
               v.cmd := mIb.dat(7 downto NUM_CMD_BITS_C);
               if ( v.cmd = SUBCMD_BB_C ) then
                  v.state := BB;
               else
                  v.state := LEN;
               end if;
               if ( mIb.lst = '1' ) then
                  v.state := r.state;
               end if;
            end if;

	 when BB  =>
	    mOb        <= mIb;
	    mOb.dat(0) <= r.tck;
	    mOb.dat(1) <= r.sr(0);
	    mOb.dat(2) <= tdo;
	    mOb.dat(3) <= r.tms;
            if ( mIb.vld = '1' ) then
               v.tck   := mIb.dat(0);
               v.tdi   := mIb.dat(1);
               v.sr(0) := mIb.dat(1);
               v.tms   := mIb.dat(3);
               if ( (rOb and mIb.lst) = '1' ) then
                  v.state := ECHO;
               else
                  v.state := DON;
               end if;
            end if;

         when LEN =>
            if ( mIb.vld = '1' ) then
               -- full length is only relevant for TDI_RO
               -- in TMS mode the msbit is set but does not
               -- propagate into bitCnt!
               v.len(7 downto 0) := signed(mIb.dat);
               -- sign of 'len' determines when we are done
               -- in read-only mode; keep asserted in all
               -- other modes (overwritten in LEN1)
               v.len(v.len'left) := '1';
               -- [r.tdi] is irrelevant in non-TMS mode
               v.tdi   := mIb.dat(7);
               if ( r.cmd = SUBCMD_TDI_RO_C ) then
                  v.state := LEN1;
               else
                  v.state := READ;
               end if;
               if ( mIb.lst = '1' ) then
                  v.state := DON;
               end if;
            end if;

         when LEN1 =>
            v.sr      := (others => '0');
            if ( mIb.vld = '1' ) then
               v.len(15 downto 8) := signed(mIb.dat);
               v.len(v.len'left)  := '0';
               v.len              := v.len - 1;
               v.bitCnt           := to_signed(7, v.bitCnt'length);
               v.state            := WAI;
               if ( mIb.lst = '0' ) then
                  -- illegal; no more input!
                  v.state := DON;
               end if;
            end if;

         when READ =>
            if ( mIb.vld = '1' ) then
               v.sr := mIb.dat;
               if ( mIb.lst = '1' ) then
                  v.bitCnt := r.len(v.bitCnt'range);
               else
                  v.bitCnt := to_signed(7, v.bitCnt'length);
               end if;
               v.state     := WAI;
            end if;

         when DON =>
            rIbLoc  <= not r.lstSeen;
            mOb.lst <= '1';
            mOb.vld <= r.lstSeen;
            if ( (rOb and r.lstSeen) = '1' ) then
               v.state := ECHO;
            end if;

         when WRITE =>
            mOb.vld <= '1';
            rIbLoc  <= '0';
            if ( rOb = '1' ) then
               v.state := READ;
               if ( r.cmd = SUBCMD_TDI_RO_C ) then
                  v.state := WAI;
               end if;
            end if;

         when WAI =>
            rIbLoc <= '0';
            if ( r.presc < 0 ) then
               v.tck    := not r.tck;
               v.presc  := HPER_DELAY_G - 1;
               if ( r.tck = '0' ) then
                  -- rising edge
                  v.tdoSR  := tdo & r.tdoSR(7 downto 1);
                  v.bitCnt := r.bitCnt - 1;
               else
                  v.sr     := '0' & r.sr(7 downto 1);
                  if ( r.bitCnt < 0 ) then
                    v.bitCnt := to_signed(7, v.bitCnt'length);
                    if ( (r.lstSeen = '1') and (r.len < 0) ) then
                       v.state := DON;
                       if ( isTMS ) then
                          v.tms := r.sr(0);
                       else
                          v.tdi := r.sr(0);
                       end if;
                    else
                       v.state := WRITE;
                       if ( r.cmd = SUBCMD_TDI_WO_C ) then
                          v.state := READ;
                       end if;
                       if ( r.cmd = SUBCMD_TDI_RO_C ) then
                          v.len  := r.len - 1;
                       end if;
                    end if;
                  end if;
               end if;
            else
               v.presc := r.presc - 1;
            end if;

      end case;

      rin     <= v;
   end process P_COMB;

   P_SEQ : process ( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin;
         end if;
      end if;
   end process P_SEQ;

   rIb <= rIbLoc;

end architecture rtl;
