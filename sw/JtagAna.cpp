#include <JtagAna.hpp>
#include <cinttypes>
#include <cstdio>

void
JtagAna::updateDR(const std::vector<uint8_t> &dri, const std::vector<uint8_t> &dro, uint8_t lastBits)
{
    printf("DR Update; IR %" PRIx64 ", DR-len %zu%s", getIR(), getDRLen(), !(verb & 0xc) ? "\n" : ", ");
    if ( !!(verb & 4) ) {
	    printDRi(stdout);
    }
    if ( !!(verb & 8) ) {
	    printDRo(stdout);
    }
}

void
JtagAna::updateIR(uint64_t ir, unsigned irLen)
{
    printf("IR Update; IR %" PRIx64 ", IR-len %u\n", ir, irLen);
}


JtagTap::State
JtagAna::nextState(bool tms, bool tdi, bool tdo)
{
        State prev = getState();
	idleClock++;
        State next = JtagTap::nextState(tms, tdi, tdo);
	if ( next != prev ) {
		const char *sn;
		switch ( prev ) {
			case State::PauseIR:
			case State::PauseDR:
			case State::RunTestIdle:
				sn = toString(prev).c_str();
				break;
			default:
				sn = nullptr;
				break;
		}
		if ( sn && idleClock > 1 ) {
			printf("%d idle clocks in %s\n", idleClock - 1, sn);
		}
		idleClock = 0;
		if ( !!(verb & 3) ) {
			printf("State changed to %s\n", toString(next).c_str());
		}
	} else {
		if ( !!(verb & 2 ) ) {
			printf("State remained in %s\n", toString(next).c_str());
		}
	}
	return next;
}
