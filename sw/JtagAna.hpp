#pragma once

#include <JtagTap.hpp>

class JtagAna : public JtagTap {
    unsigned idleClock { 0 };
    int      verb {0};
  public:
    using JtagTap::nextState;

    virtual State nextState(bool tms, bool tdi, bool tdo) override;

    virtual State nextState(uint8_t dat) {
        return JtagAna::nextState(!!(dat&1), !!(dat&2), !!(dat&4));
    }

    virtual void setVerb(int v) {
	    verb = v;
    }

    virtual void
    updateDR(const std::vector<uint8_t> &dri, const std::vector<uint8_t> &dro, uint8_t lastBits) override;

    virtual void
    updateIR(uint64_t ir, unsigned irLen) override;
};
