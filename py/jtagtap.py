from enum import Enum
class JtagTap:
  class State(Enum):
    TEST_LOGIC_RESET = 0
    RUN_TEST_IDLE    = 1
    SELECT_DR_SCAN   = 2
    CAPTURE_DR       = 3
    SHIFT_DR         = 4
    EXIT1_DR         = 5
    PAUSE_DR         = 6
    EXIT2_DR         = 7
    UPDATE_DR        = 8
    SELECT_IR_SCAN   = 9
    CAPTURE_IR       = 10
    SHIFT_IR         = 11
    EXIT1_IR         = 12
    PAUSE_IR         = 13
    EXIT2_IR         = 14
    UPDATE_IR        = 15

  def __init__(self, ir_len):
    self.state  = JtagTap.State.TEST_LOGIC_RESET
    self.ir_len = ir_len
    self.byp    = ((1<<self.ir_len) - 1)
    self.ir     = self.byp
    self.sr     = 0
  

  def state(self):
    return self.state

  def tmsSeq(self, seq):
    for i in seq:
      self.nextState(i)

  def nextState(self, tms, tdi=False):
    if   ( self.state == self.State.TEST_LOGIC_RESET):
      if ( not  tms ):
        self.state = self.State.RUN_TEST_IDLE
      self.ir  = self.byp
    elif ( self.state == self.State.RUN_TEST_IDLE   ):
      if ( tms ):
        self.state = self.State.SELECT_DR_SCAN
    elif ( self.state == self.State.SELECT_DR_SCAN  ):
      if ( tms ):
        self.state = self.State.SELECT_IR_SCAN
      else:
        self.state = self.State.CAPTURE_DR
    elif ( self.state == self.State.CAPTURE_DR      ):
      if ( tms ):
        self.state = self.State.EXIT1_DR
      else:
        self.state = self.State.SHIFT_DR
    elif ( self.state == self.State.SHIFT_DR        ):
      if ( tms ):
        self.state = self.State.EXIT1_DR
    elif ( self.state == self.State.EXIT1_DR        ):
      if ( tms ):
        self.state = self.State.UPDATE_DR
      else:
        self.state = self.State.PAUSE_DR
    elif ( self.state == self.State.PAUSE_DR        ):
      if ( tms ):
        self.state = self.State.EXIT2_DR
    elif ( self.state == self.State.EXIT2_DR        ):
      if ( tms ):
        self.state = self.State.UPDATE_DR
      else:
        self.state = self.State.SHIFT_DR
    elif ( self.state == self.State.UPDATE_DR       ):
      if ( tms ):
        self.state = self.State.SELECT_DR_SCAN
      else:
        self.state = self.State.RUN_TEST_IDLE
    elif ( self.state == self.State.SELECT_IR_SCAN  ):
      if ( tms ):
        self.state = self.State.TEST_LOGIC_RESET
      else:
        self.state = self.State.CAPTURE_IR
    elif ( self.state == self.State.CAPTURE_IR      ):
      if ( tms ):
        self.state = self.State.EXIT1_IR
      else:
        self.state = self.State.SHIFT_IR
      self.sr = 1;
    elif ( self.state == self.State.SHIFT_IR        ):
      if ( tms ):
        self.state = self.State.EXIT1_IR
      if ( tdi ):
         self.sr |= (1<<self.ir_len)
      self.sr >>=1
    elif ( self.state == self.State.EXIT1_IR        ):
      if ( tms ):
        self.state = self.State.UPDATE_IR
      else:
        self.state = self.State.PAUSE_IR
    elif ( self.state == self.State.PAUSE_IR        ):
      if ( tms ):
        self.state = self.State.EXIT2_IR
    elif ( self.state == self.State.EXIT2_IR        ):
      if ( tms ):
        self.state = self.State.UPDATE_IR
      else:
        self.state = self.State.SHIFT_IR
    elif ( self.state == self.State.UPDATE_IR       ):
      if ( tms ):
        self.state = self.State.SELECT_DR_SCAN
      else:
        self.state = self.State.RUN_TEST_IDLE
      self.ir = (self.sr & self.byp)
    else:
      raise RuntimeError("Invalid State")

  def tdo(self):
    if ( self.state != self.State.SHIFT_DR and self.state != self.State.SHIFT_IR ):
      return None
    return self.sr & 1
